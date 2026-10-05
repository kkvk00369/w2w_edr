[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TenantId,

    [Parameter()]
    [string]$BreakGlassGroupId,

    [Parameter()]
    [string]$BreakGlassGroupName = "Security-BreakGlass-Accounts",

    [Parameter()]
    [string]$TrustedLocationId,

    [Parameter()]
    [string]$TrustedLocationName = "Trusted Corporate IPs",

    [Parameter()]
    [string]$PolicyDisplayName = "E8 - CA - Break Glass - Block Outside Trusted Location",

    [Parameter()]
    [string]$FallbackPolicyDisplayName = "E8 - CA - Break Glass - Require Compliant Device and Phishing-Resistant MFA",

    [Parameter()]
    [switch]$SkipTrustedLocation,

    [Parameter()]
    [switch]$ReportOnly,

    [Parameter()]
    [switch]$ReplaceExisting,

    [Parameter()]
    [int]$SignInLookbackDays = 30,

    [Parameter()]
    [string]$OutputFolder = "../out",

    [Parameter()]
    [switch]$UseManagedIdentity
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Section {
    param([string]$Message)
    Write-Host "`n==== $Message ====" -ForegroundColor Cyan
}

function Ensure-Module {
    param([string]$Name)
    if (-not (Get-Module -ListAvailable -Name $Name)) {
        Write-Host "Installing module: $Name" -ForegroundColor Yellow
        Install-Module -Name $Name -Scope CurrentUser -Force -AllowClobber
    }
    Import-Module $Name -ErrorAction Stop
}

function Connect-Graph {
    Ensure-Module -Name "Microsoft.Graph.Authentication"

    $scopes = @(
        "Policy.ReadWrite.ConditionalAccess",
        "Policy.Read.All",
        "Group.Read.All",
        "AuditLog.Read.All"
    )

    if ($UseManagedIdentity) {
        Connect-MgGraph -Identity -TenantId $TenantId -NoWelcome
    }
    else {
        Connect-MgGraph -TenantId $TenantId -Scopes $scopes -NoWelcome
    }

    Select-MgProfile -Name "beta"
}

function Resolve-PathFromScriptRoot {
    param([string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    $scriptRoot = Split-Path -Parent $PSCommandPath
    return (Join-Path $scriptRoot $Path)
}

function Get-AllPages {
    param([string]$Uri)

    $results = @()
    $next = $Uri

    while ($next) {
        $response = Invoke-MgGraphRequest -Method GET -Uri $next -OutputType PSObject
        if ($response.value) {
            $results += $response.value
        }

        $next = $null
        if ($response.'@odata.nextLink') {
            $next = $response.'@odata.nextLink'
        }
    }

    return $results
}

function Resolve-BreakGlassGroupId {
    param(
        [string]$Id,
        [string]$Name
    )

    if ($Id) {
        $g = Invoke-MgGraphRequest -Method GET -Uri "/v1.0/groups/$Id" -OutputType PSObject
        if ($null -eq $g) {
            throw "Break-glass group id not found: $Id"
        }
        return $Id
    }

    $escaped = $Name.Replace("'", "''")
    $result = Invoke-MgGraphRequest -Method GET -Uri "/v1.0/groups?`$filter=displayName eq '$escaped'" -OutputType PSObject
    if ($result.value.Count -eq 0) {
        throw "Break-glass group name not found: $Name"
    }

    return $result.value[0].id
}

function Resolve-TrustedLocationId {
    param(
        [string]$Id,
        [string]$Name
    )

    if ($Id) {
        $loc = Invoke-MgGraphRequest -Method GET -Uri "/beta/identity/conditionalAccess/namedLocations/$Id" -OutputType PSObject
        if ($null -eq $loc) {
            throw "Trusted named location id not found: $Id"
        }
        return $Id
    }

    $escaped = $Name.Replace("'", "''")
    $result = Invoke-MgGraphRequest -Method GET -Uri "/beta/identity/conditionalAccess/namedLocations?`$filter=displayName eq '$escaped'" -OutputType PSObject
    if ($result.value.Count -eq 0) {
        throw "Trusted named location name not found: $Name"
    }

    return $result.value[0].id
}

function Get-ExistingPolicyByName {
    param([string]$DisplayName)

    $escaped = $DisplayName.Replace("'", "''")
    $uri = "/beta/identity/conditionalAccess/policies?`$filter=displayName eq '$escaped'"
    $result = Invoke-MgGraphRequest -Method GET -Uri $uri -OutputType PSObject
    if ($result.value.Count -gt 0) {
        return $result.value[0]
    }

    return $null
}

function Ensure-BreakGlassLocationBlockPolicy {
    param(
        [string]$DisplayName,
        [string]$BreakGlassId,
        [string]$LocationId,
        [bool]$IsReportOnly,
        [bool]$AllowReplace
    )

    $state = "enabled"
    if ($IsReportOnly) {
        $state = "enabledForReportingButNotEnforced"
    }

    $policy = @{
        displayName = $DisplayName
        state = $state
        conditions = @{
            users = @{
                includeGroups = @($BreakGlassId)
            }
            applications = @{
                includeApplications = @("All")
            }
            clientAppTypes = @("all")
            locations = @{
                includeLocations = @("All")
                excludeLocations = @($LocationId)
            }
        }
        grantControls = @{
            operator = "OR"
            builtInControls = @("block")
        }
    }

    $body = $policy | ConvertTo-Json -Depth 20
    $existing = Get-ExistingPolicyByName -DisplayName $DisplayName

    if ($null -eq $existing) {
        return (Invoke-MgGraphRequest -Method POST -Uri "/beta/identity/conditionalAccess/policies" -Body $body -ContentType "application/json" -OutputType PSObject)
    }

    if (-not $AllowReplace) {
        Write-Host "Policy already exists and ReplaceExisting is not set: $DisplayName" -ForegroundColor Yellow
        return $existing
    }

    [void](Invoke-MgGraphRequest -Method PATCH -Uri "/beta/identity/conditionalAccess/policies/$($existing.id)" -Body $body -ContentType "application/json")
    return (Invoke-MgGraphRequest -Method GET -Uri "/beta/identity/conditionalAccess/policies/$($existing.id)" -OutputType PSObject)
}

function Ensure-BreakGlassFallbackPolicy {
    param(
        [string]$DisplayName,
        [string]$BreakGlassId,
        [bool]$IsReportOnly,
        [bool]$AllowReplace
    )

    $state = "enabled"
    if ($IsReportOnly) {
        $state = "enabledForReportingButNotEnforced"
    }

    $policy = @{
        displayName = $DisplayName
        state = $state
        conditions = @{
            users = @{
                includeGroups = @($BreakGlassId)
            }
            applications = @{
                includeApplications = @("All")
            }
            clientAppTypes = @("all")
        }
        grantControls = @{
            operator = "AND"
            builtInControls = @("mfa", "compliantDevice", "phishingResistance")
        }
    }

    $body = $policy | ConvertTo-Json -Depth 20
    $existing = Get-ExistingPolicyByName -DisplayName $DisplayName

    if ($null -eq $existing) {
        return (Invoke-MgGraphRequest -Method POST -Uri "/beta/identity/conditionalAccess/policies" -Body $body -ContentType "application/json" -OutputType PSObject)
    }

    if (-not $AllowReplace) {
        Write-Host "Policy already exists and ReplaceExisting is not set: $DisplayName" -ForegroundColor Yellow
        return $existing
    }

    [void](Invoke-MgGraphRequest -Method PATCH -Uri "/beta/identity/conditionalAccess/policies/$($existing.id)" -Body $body -ContentType "application/json")
    return (Invoke-MgGraphRequest -Method GET -Uri "/beta/identity/conditionalAccess/policies/$($existing.id)" -OutputType PSObject)
}

function Get-BreakGlassUsers {
    param([string]$GroupId)

    return Get-AllPages -Uri "/v1.0/groups/$GroupId/members?`$select=id,displayName,userPrincipalName"
}

function Get-SignInsForUsers {
    param(
        [object[]]$Users,
        [int]$LookbackDays
    )

    $since = (Get-Date).AddDays(-$LookbackDays).ToString("o")
    $all = @()

    foreach ($user in $Users) {
        if (-not $user.id) {
            continue
        }

        $uri = "/beta/auditLogs/signIns?`$filter=createdDateTime ge $since and userId eq '$($user.id)'"
        $rows = Get-AllPages -Uri $uri
        $all += $rows
    }

    return $all
}

function Write-JsonFile {
    param(
        [string]$Path,
        [object]$Data
    )

    $json = $Data | ConvertTo-Json -Depth 40
    Set-Content -Path $Path -Value $json -Encoding utf8
}

Write-Section "Authenticating to Microsoft Graph"
Connect-Graph

Write-Section "Resolving break-glass group and trusted location"
$resolvedBreakGlassGroupId = Resolve-BreakGlassGroupId -Id $BreakGlassGroupId -Name $BreakGlassGroupName
$resolvedTrustedLocationId = $null

if (-not $SkipTrustedLocation) {
    try {
        $resolvedTrustedLocationId = Resolve-TrustedLocationId -Id $TrustedLocationId -Name $TrustedLocationName
    }
    catch {
        Write-Warning "No named location was found for '$TrustedLocationName'. Falling back to compliant-device and phishing-resistant MFA controls instead of location blocking."
        $resolvedTrustedLocationId = $null
    }
}

Write-Host "Break-glass group id: $resolvedBreakGlassGroupId" -ForegroundColor Green
if ($resolvedTrustedLocationId) {
    Write-Host "Trusted location id: $resolvedTrustedLocationId" -ForegroundColor Green
}
else {
    Write-Host "Trusted location is disabled or unavailable; using a fallback break-glass policy." -ForegroundColor Yellow
}

Write-Section "Creating or updating break-glass hardening policy"
if ($resolvedTrustedLocationId) {
    $policy = Ensure-BreakGlassLocationBlockPolicy `
        -DisplayName $PolicyDisplayName `
        -BreakGlassId $resolvedBreakGlassGroupId `
        -LocationId $resolvedTrustedLocationId `
        -IsReportOnly:$ReportOnly `
        -AllowReplace:$ReplaceExisting
}
else {
    $policy = Ensure-BreakGlassFallbackPolicy `
        -DisplayName $FallbackPolicyDisplayName `
        -BreakGlassId $resolvedBreakGlassGroupId `
        -IsReportOnly:$ReportOnly `
        -AllowReplace:$ReplaceExisting
}

Write-Host "Policy ensured: $($policy.displayName) (state: $($policy.state))" -ForegroundColor Green

Write-Section "Collecting break-glass sign-in activity"
$users = Get-BreakGlassUsers -GroupId $resolvedBreakGlassGroupId
$signIns = Get-SignInsForUsers -Users $users -LookbackDays $SignInLookbackDays

$resolvedOutputFolder = Resolve-PathFromScriptRoot -Path $OutputFolder
if (-not (Test-Path -Path $resolvedOutputFolder)) {
    New-Item -ItemType Directory -Path $resolvedOutputFolder -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outFile = Join-Path $resolvedOutputFolder "breakglass-signins-$timestamp.json"

$failed = @($signIns | Where-Object { $_.status.errorCode -ne 0 })
$successful = @($signIns | Where-Object { $_.status.errorCode -eq 0 })

$payload = [PSCustomObject]@{
    generatedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
    tenantId = $TenantId
    policyDisplayName = $policy.displayName
    policyId = $policy.id
    breakGlassGroupId = $resolvedBreakGlassGroupId
    trustedLocationId = $resolvedTrustedLocationId
    trustedLocationMode = if ($resolvedTrustedLocationId) { "named-location" } else { "fallback-compliant-device" }
    lookbackDays = $SignInLookbackDays
    breakGlassUserCount = $users.Count
    signInCount = $signIns.Count
    successfulSignInCount = $successful.Count
    failedSignInCount = $failed.Count
    signIns = $signIns
}

Write-JsonFile -Path $outFile -Data $payload

Write-Section "Completed"
Write-Host "Break-glass sign-in report written to: $outFile" -ForegroundColor Green
Write-Host "Schedule this script to run daily for continuous monitoring." -ForegroundColor Yellow
