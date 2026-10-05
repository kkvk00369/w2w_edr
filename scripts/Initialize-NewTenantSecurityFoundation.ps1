[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TenantId,

    [Parameter()]
    [string]$DomainName,

    [Parameter()]
    [string]$BreakGlassPrefix = "breakglass",

    [Parameter()]
    [int]$BreakGlassAccountCount = 2,

    [Parameter()]
    [string[]]$BreakGlassRoleTemplateIds = @(
        "62e90394-69f5-4237-9190-012177145e10"
    ),

    [Parameter()]
    [string]$PilotGroupName = "Intune-Windows-Pilot",

    [Parameter()]
    [string]$ProductionGroupName = "Intune-Windows-Production",

    [Parameter()]
    [string]$ExclusionGroupName = "Intune-Windows-Exclusions",

    [Parameter()]
    [string]$BreakGlassGroupName = "Security-BreakGlass-Accounts",

    [Parameter()]
    [switch]$CreateTrustedNamedLocation,

    [Parameter()]
    [switch]$SkipTrustedNamedLocation,

    [Parameter()]
    [string]$TrustedNamedLocationName = "Trusted Corporate IPs",

    [Parameter()]
    [string[]]$TrustedIpCidrs,

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
        "User.ReadWrite.All",
        "Group.ReadWrite.All",
        "Directory.ReadWrite.All",
        "RoleManagement.ReadWrite.Directory",
        "Policy.ReadWrite.ConditionalAccess",
        "Policy.Read.All"
    )

    if ($UseManagedIdentity) {
        Connect-MgGraph -Identity -TenantId $TenantId -NoWelcome
    }
    else {
        Connect-MgGraph -TenantId $TenantId -Scopes $scopes -NoWelcome
    }

    Select-MgProfile -Name "beta"
}

function Resolve-OutputFolder {
    param([string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    $scriptRoot = Split-Path -Parent $PSCommandPath
    return (Join-Path $scriptRoot $Path)
}

function Get-DefaultDomainName {
    $org = Invoke-MgGraphRequest -Method GET -Uri "/v1.0/domains" -OutputType PSObject
    $default = @($org.value | Where-Object { $_.isDefault -eq $true } | Select-Object -First 1)
    if ($default.Count -eq 0) {
        throw "Unable to determine default domain. Provide -DomainName explicitly."
    }
    return $default[0].id
}

function New-StrongPassword {
    $chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@$%*+-_"
    $length = 32
    $rnd = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
    $bytes = New-Object byte[]($length)
    $rnd.GetBytes($bytes)
    $passwordChars = for ($i = 0; $i -lt $length; $i++) {
        $chars[$bytes[$i] % $chars.Length]
    }
    return (-join $passwordChars)
}

function Ensure-SecurityGroup {
    param([string]$DisplayName)

    $escaped = $DisplayName.Replace("'", "''")
    $existing = Invoke-MgGraphRequest -Method GET -Uri "/v1.0/groups?`$filter=displayName eq '$escaped'" -OutputType PSObject
    if ($existing.value.Count -gt 0) {
        return $existing.value[0]
    }

    $mailNick = ($DisplayName -replace "[^a-zA-Z0-9]", "").ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($mailNick)) {
        $mailNick = "secgroup"
    }

    $body = @{
        displayName = $DisplayName
        description = "Managed by tenant bootstrap automation"
        mailEnabled = $false
        securityEnabled = $true
        mailNickname = $mailNick
    } | ConvertTo-Json -Depth 8

    return (Invoke-MgGraphRequest -Method POST -Uri "/v1.0/groups" -Body $body -ContentType "application/json" -OutputType PSObject)
}

function Get-UserByUpn {
    param([string]$UserPrincipalName)

    $escaped = $UserPrincipalName.Replace("'", "''")
    $result = Invoke-MgGraphRequest -Method GET -Uri "/v1.0/users?`$filter=userPrincipalName eq '$escaped'" -OutputType PSObject
    if ($result.value.Count -gt 0) {
        return $result.value[0]
    }

    return $null
}

function Ensure-BreakGlassAccount {
    param(
        [string]$UserPrincipalName,
        [string]$DisplayName,
        [string]$GivenName,
        [string]$Surname
    )

    $existing = Get-UserByUpn -UserPrincipalName $UserPrincipalName
    if ($null -ne $existing) {
        return [PSCustomObject]@{
            User = $existing
            Created = $false
            Password = $null
        }
    }

    $password = New-StrongPassword
    $mailNick = ($UserPrincipalName.Split("@")[0])

    $body = @{
        accountEnabled = $true
        displayName = $DisplayName
        givenName = $GivenName
        surname = $Surname
        userPrincipalName = $UserPrincipalName
        mailNickname = $mailNick
        passwordPolicies = "DisablePasswordExpiration"
        passwordProfile = @{
            forceChangePasswordNextSignIn = $false
            password = $password
        }
    } | ConvertTo-Json -Depth 12

    $created = Invoke-MgGraphRequest -Method POST -Uri "/v1.0/users" -Body $body -ContentType "application/json" -OutputType PSObject
    return [PSCustomObject]@{
        User = $created
        Created = $true
        Password = $password
    }
}

function Ensure-DirectoryRole {
    param([string]$RoleTemplateId)

    $existing = Invoke-MgGraphRequest -Method GET -Uri "/v1.0/directoryRoles?`$filter=roleTemplateId eq '$RoleTemplateId'" -OutputType PSObject
    if ($existing.value.Count -gt 0) {
        return $existing.value[0]
    }

    $activateBody = @{ roleTemplateId = $RoleTemplateId } | ConvertTo-Json
    [void](Invoke-MgGraphRequest -Method POST -Uri "/v1.0/directoryRoles" -Body $activateBody -ContentType "application/json")

    $after = Invoke-MgGraphRequest -Method GET -Uri "/v1.0/directoryRoles?`$filter=roleTemplateId eq '$RoleTemplateId'" -OutputType PSObject
    if ($after.value.Count -eq 0) {
        throw "Failed to activate directory role template id: $RoleTemplateId"
    }

    return $after.value[0]
}

function Ensure-RoleMember {
    param(
        [string]$DirectoryRoleId,
        [string]$ObjectId
    )

    $members = Invoke-MgGraphRequest -Method GET -Uri "/v1.0/directoryRoles/$DirectoryRoleId/members?`$select=id" -OutputType PSObject
    $exists = @($members.value | Where-Object { $_.id -eq $ObjectId }).Count -gt 0
    if ($exists) {
        return
    }

    $body = @{
        "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$ObjectId"
    } | ConvertTo-Json

    [void](Invoke-MgGraphRequest -Method POST -Uri "/v1.0/directoryRoles/$DirectoryRoleId/members/`$ref" -Body $body -ContentType "application/json")
}

function Ensure-GroupMember {
    param(
        [string]$GroupId,
        [string]$ObjectId
    )

    $members = Invoke-MgGraphRequest -Method GET -Uri "/v1.0/groups/$GroupId/members?`$select=id" -OutputType PSObject
    $exists = @($members.value | Where-Object { $_.id -eq $ObjectId }).Count -gt 0
    if ($exists) {
        return
    }

    $body = @{ "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$ObjectId" } | ConvertTo-Json
    [void](Invoke-MgGraphRequest -Method POST -Uri "/v1.0/groups/$GroupId/members/`$ref" -Body $body -ContentType "application/json")
}

function Ensure-NamedLocation {
    param(
        [string]$DisplayName,
        [string[]]$Cidrs
    )

    $escaped = $DisplayName.Replace("'", "''")
    $existing = Invoke-MgGraphRequest -Method GET -Uri "/beta/identity/conditionalAccess/namedLocations?`$filter=displayName eq '$escaped'" -OutputType PSObject
    if ($existing.value.Count -gt 0) {
        return $existing.value[0]
    }

    if (-not $Cidrs -or $Cidrs.Count -eq 0) {
        throw "Trusted named location requested but -TrustedIpCidrs is empty."
    }

    $ranges = @()
    foreach ($cidr in $Cidrs) {
        $ranges += @{ "@odata.type" = "#microsoft.graph.iPv4CidrRange"; cidrAddress = $cidr }
    }

    $body = @{
        "@odata.type" = "#microsoft.graph.ipNamedLocation"
        displayName = $DisplayName
        isTrusted = $true
        ipRanges = $ranges
    } | ConvertTo-Json -Depth 12

    return (Invoke-MgGraphRequest -Method POST -Uri "/beta/identity/conditionalAccess/namedLocations" -Body $body -ContentType "application/json" -OutputType PSObject)
}

Write-Section "Authenticating to Microsoft Graph"
Connect-Graph

Write-Section "Preparing output"
$resolvedOutput = Resolve-OutputFolder -Path $OutputFolder
if (-not (Test-Path -Path $resolvedOutput)) {
    New-Item -ItemType Directory -Path $resolvedOutput -Force | Out-Null
}

if (-not $DomainName) {
    $DomainName = Get-DefaultDomainName
}

Write-Host "Using domain: $DomainName" -ForegroundColor Green

Write-Section "Ensuring baseline groups"
$pilotGroup = Ensure-SecurityGroup -DisplayName $PilotGroupName
$productionGroup = Ensure-SecurityGroup -DisplayName $ProductionGroupName
$exclusionGroup = Ensure-SecurityGroup -DisplayName $ExclusionGroupName
$breakGlassGroup = Ensure-SecurityGroup -DisplayName $BreakGlassGroupName

Write-Section "Ensuring break-glass accounts"
$breakGlassAccounts = @()
for ($i = 1; $i -le $BreakGlassAccountCount; $i++) {
    $upn = "{0}{1}@{2}" -f $BreakGlassPrefix, $i, $DomainName
    $displayName = "Break Glass {0}" -f $i
    $acct = Ensure-BreakGlassAccount -UserPrincipalName $upn -DisplayName $displayName -GivenName "Break" -Surname "Glass$i"
    $breakGlassAccounts += $acct

    Ensure-GroupMember -GroupId $breakGlassGroup.id -ObjectId $acct.User.id
    Ensure-GroupMember -GroupId $exclusionGroup.id -ObjectId $acct.User.id

    Write-Host "Ensured break-glass account: $upn" -ForegroundColor Green
}

Write-Section "Ensuring role assignments for break-glass accounts"
foreach ($roleTemplateId in $BreakGlassRoleTemplateIds) {
    $role = Ensure-DirectoryRole -RoleTemplateId $roleTemplateId
    foreach ($acct in $breakGlassAccounts) {
        Ensure-RoleMember -DirectoryRoleId $role.id -ObjectId $acct.User.id
    }
    Write-Host "Ensured role assignment for roleTemplateId: $roleTemplateId" -ForegroundColor Green
}

$trustedLocation = $null
if ($CreateTrustedNamedLocation) {
    Write-Section "Ensuring trusted named location"
    $trustedLocation = Ensure-NamedLocation -DisplayName $TrustedNamedLocationName -Cidrs $TrustedIpCidrs
    Write-Host "Ensured trusted named location: $($trustedLocation.displayName)" -ForegroundColor Green
}
elseif ($SkipTrustedNamedLocation) {
    Write-Host "Trusted named location was intentionally skipped for this tenant." -ForegroundColor Yellow
}
else {
    Write-Host "No trusted named location configured; downstream CA enforcement will use the fallback compliant-device MFA pattern." -ForegroundColor Yellow
}

Write-Section "Writing bootstrap outputs"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outputPath = Join-Path $resolvedOutput "tenant-foundation-$timestamp.json"

$payload = [PSCustomObject]@{
    generatedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
    tenantId = $TenantId
    domainName = $DomainName
    groups = [PSCustomObject]@{
        pilot = [PSCustomObject]@{ id = $pilotGroup.id; displayName = $pilotGroup.displayName }
        production = [PSCustomObject]@{ id = $productionGroup.id; displayName = $productionGroup.displayName }
        exclusion = [PSCustomObject]@{ id = $exclusionGroup.id; displayName = $exclusionGroup.displayName }
        breakGlass = [PSCustomObject]@{ id = $breakGlassGroup.id; displayName = $breakGlassGroup.displayName }
    }
    breakGlassAccounts = @(
        foreach ($acct in $breakGlassAccounts) {
            [PSCustomObject]@{
                id = $acct.User.id
                userPrincipalName = $acct.User.userPrincipalName
                displayName = $acct.User.displayName
                createdThisRun = $acct.Created
                initialPassword = $acct.Password
            }
        }
    )
    trustedNamedLocation = if ($null -ne $trustedLocation) {
        [PSCustomObject]@{
            id = $trustedLocation.id
            displayName = $trustedLocation.displayName
        }
    }
    else {
        $null
    }
}

$json = $payload | ConvertTo-Json -Depth 30
Set-Content -Path $outputPath -Value $json -Encoding utf8

Write-Host "Tenant foundation file written to: $outputPath" -ForegroundColor Green
Write-Host "IMPORTANT: Securely store initial break-glass passwords and rotate them per policy." -ForegroundColor Yellow
