[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TenantId,

    [Parameter(Mandatory = $true)]
    [string]$PilotGroupId,

    [Parameter(Mandatory = $true)]
    [string]$ProductionGroupId,

    [Parameter()]
    [string]$ExcludeGroupId,

    [Parameter()]
    [string]$PolicyFolder = "../config/policies",

    [Parameter()]
    [switch]$UseManagedIdentity,

    [Parameter()]
    [switch]$ReplaceExisting
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
        "DeviceManagementConfiguration.ReadWrite.All",
        "DeviceManagementManagedDevices.Read.All",
        "Group.Read.All"
    )

    if ($UseManagedIdentity) {
        Connect-MgGraph -Identity -TenantId $TenantId -NoWelcome
    }
    else {
        Connect-MgGraph -TenantId $TenantId -Scopes $scopes -NoWelcome
    }

    Select-MgProfile -Name "beta"
}

function Remove-ReadOnlyFields {
    param([object]$Node)

    $blockedKeys = @(
        "id",
        "createdDateTime",
        "lastModifiedDateTime",
        "settingCount",
        "isAssigned",
        "version",
        "creationSource",
        "roleScopeTagIds@odata.type"
    )

    if ($Node -is [System.Collections.IDictionary]) {
        foreach ($key in @($Node.Keys)) {
            if ($blockedKeys -contains $key) {
                $Node.Remove($key)
                continue
            }

            $value = $Node[$key]
            if ($null -ne $value) {
                Remove-ReadOnlyFields -Node $value
            }
        }
    }
    elseif (($Node -is [System.Collections.IEnumerable]) -and -not ($Node -is [string])) {
        foreach ($item in $Node) {
            if ($null -ne $item) {
                Remove-ReadOnlyFields -Node $item
            }
        }
    }
}

function Resolve-PolicyFolder {
    param([string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    $scriptRoot = Split-Path -Parent $PSCommandPath
    return (Resolve-Path (Join-Path $scriptRoot $Path)).Path
}

function Get-PoliciesFromFolder {
    param([string]$Folder)

    $files = Get-ChildItem -Path $Folder -Filter "*.json" -File
    if (-not $files) {
        throw "No policy JSON files were found in: $Folder"
    }

    foreach ($file in $files) {
        $raw = Get-Content -Path $file.FullName -Raw
        $obj = ConvertFrom-Json -InputObject $raw -AsHashtable
        if (-not $obj.ContainsKey("name")) {
            throw "Policy file '$($file.FullName)' is missing required property: name"
        }
        if (-not $obj.ContainsKey("platforms")) {
            throw "Policy file '$($file.FullName)' is missing required property: platforms"
        }
        if (-not $obj.ContainsKey("technologies")) {
            throw "Policy file '$($file.FullName)' is missing required property: technologies"
        }
        if (-not $obj.ContainsKey("settings")) {
            throw "Policy file '$($file.FullName)' is missing required property: settings"
        }

        [PSCustomObject]@{
            Path = $file.FullName
            Payload = $obj
        }
    }
}

function Get-ExistingPolicyByName {
    param([string]$Name)

    $escaped = $Name.Replace("'", "''")
    $uri = "/beta/deviceManagement/configurationPolicies?`$filter=name eq '$escaped'"
    $result = Invoke-MgGraphRequest -Method GET -Uri $uri -OutputType PSObject
    if ($result.value.Count -gt 0) {
        return $result.value[0]
    }

    return $null
}

function New-OrReplacePolicy {
    param(
        [hashtable]$Policy,
        [switch]$ReplaceIfExists
    )

    $existing = Get-ExistingPolicyByName -Name $Policy.name
    if ($null -ne $existing) {
        if (-not $ReplaceIfExists) {
            Write-Host "Skipping existing policy: $($Policy.name)" -ForegroundColor Yellow
            return $existing
        }

        Write-Host "Deleting existing policy before recreate: $($Policy.name)" -ForegroundColor Yellow
        Invoke-MgGraphRequest -Method DELETE -Uri "/beta/deviceManagement/configurationPolicies/$($existing.id)"
    }

    $body = $Policy | ConvertTo-Json -Depth 40
    $created = Invoke-MgGraphRequest -Method POST -Uri "/beta/deviceManagement/configurationPolicies" -Body $body -ContentType "application/json" -OutputType PSObject
    Write-Host "Created policy: $($created.name)" -ForegroundColor Green
    return $created
}

function New-AssignmentTarget {
    param(
        [string]$GroupId,
        [bool]$Exclude
    )

    if ($Exclude) {
        return @{
            "@odata.type" = "#microsoft.graph.exclusionGroupAssignmentTarget"
            groupId = $GroupId
        }
    }

    return @{
        "@odata.type" = "#microsoft.graph.groupAssignmentTarget"
        groupId = $GroupId
    }
}

function Set-PolicyAssignments {
    param(
        [string]$PolicyId,
        [string]$Deployment,
        [string]$PilotId,
        [string]$ProdId,
        [string]$ExcludeId
    )

    $assignments = @()

    switch ($Deployment.ToLowerInvariant()) {
        "pilot" {
            $assignments += @{ target = (New-AssignmentTarget -GroupId $PilotId -Exclude:$false) }
        }
        "production" {
            $assignments += @{ target = (New-AssignmentTarget -GroupId $ProdId -Exclude:$false) }
        }
        "both" {
            $assignments += @{ target = (New-AssignmentTarget -GroupId $PilotId -Exclude:$false) }
            $assignments += @{ target = (New-AssignmentTarget -GroupId $ProdId -Exclude:$false) }
        }
        default {
            throw "Unsupported deployment value '$Deployment'. Use pilot, production, or both."
        }
    }

    if ($ExcludeId) {
        $assignments += @{ target = (New-AssignmentTarget -GroupId $ExcludeId -Exclude:$true) }
    }

    $body = @{ assignments = $assignments } | ConvertTo-Json -Depth 10
    Invoke-MgGraphRequest -Method POST -Uri "/beta/deviceManagement/configurationPolicies/$PolicyId/assign" -Body $body -ContentType "application/json" | Out-Null
}

Write-Section "Authenticating to Microsoft Graph"
Connect-Graph

Write-Section "Loading policy definitions"
$resolvedPolicyFolder = Resolve-PolicyFolder -Path $PolicyFolder
$policies = Get-PoliciesFromFolder -Folder $resolvedPolicyFolder
Write-Host "Loaded $($policies.Count) policy definition file(s)." -ForegroundColor Green

Write-Section "Deploying Intune policies"
foreach ($entry in $policies) {
    $policy = $entry.Payload
    Remove-ReadOnlyFields -Node $policy

    if (-not $policy.ContainsKey("description")) {
        $policy.description = "Essential Eight policy deployed by automation."
    }

    $deployment = "production"
    if ($policy.ContainsKey("deployment")) {
        $deployment = [string]$policy.deployment
        $policy.Remove("deployment")
    }

    $created = New-OrReplacePolicy -Policy $policy -ReplaceIfExists:$ReplaceExisting

    if ($null -ne $created) {
        Set-PolicyAssignments `
            -PolicyId $created.id `
            -Deployment $deployment `
            -PilotId $PilotGroupId `
            -ProdId $ProductionGroupId `
            -ExcludeId $ExcludeGroupId

        Write-Host "Assigned policy '$($policy.name)' with deployment '$deployment'." -ForegroundColor Green
    }
}

Write-Section "Completed"
Write-Host "Intune Essential Eight policy deployment completed successfully." -ForegroundColor Green
