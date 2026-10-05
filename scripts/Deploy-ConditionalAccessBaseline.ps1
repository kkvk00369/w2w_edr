[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TenantId,

    [Parameter()]
    [string]$PolicyFolder = "../config/conditional-access",

    [Parameter()]
    [switch]$UseManagedIdentity,

    [Parameter()]
    [switch]$ReplaceExisting,

    [Parameter()]
    [switch]$ForceEnable,

    [Parameter()]
    [switch]$AllowPlaceholders
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

function Resolve-InputFolder {
    param([string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    $scriptRoot = Split-Path -Parent $PSCommandPath
    return (Resolve-Path (Join-Path $scriptRoot $Path)).Path
}

function Remove-ReadOnlyFields {
    param([object]$Node)

    $blockedKeys = @(
        "id",
        "createdDateTime",
        "modifiedDateTime",
        "templateId"
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

function Find-PlaceholderValues {
    param([object]$Node)

    $matches = New-Object System.Collections.Generic.List[string]

    function Visit {
        param([object]$Current)

        if ($null -eq $Current) {
            return
        }

        if ($Current -is [System.Collections.IDictionary]) {
            foreach ($key in $Current.Keys) {
                Visit -Current $Current[$key]
            }
            return
        }

        if (($Current -is [System.Collections.IEnumerable]) -and -not ($Current -is [string])) {
            foreach ($item in $Current) {
                Visit -Current $item
            }
            return
        }

        if ($Current -is [string] -and $Current.StartsWith("REPLACE_WITH_")) {
            [void]$matches.Add($Current)
        }
    }

    Visit -Current $Node
    return $matches | Sort-Object -Unique
}

function Get-PolicyDefinitions {
    param([string]$Folder)

    $files = Get-ChildItem -Path $Folder -Filter "*.json" -File
    if (-not $files) {
        throw "No Conditional Access JSON files were found in: $Folder"
    }

    foreach ($file in $files) {
        $raw = Get-Content -Path $file.FullName -Raw
        $obj = ConvertFrom-Json -InputObject $raw -AsHashtable

        if (-not $obj.ContainsKey("displayName")) {
            throw "File '$($file.FullName)' missing required property: displayName"
        }
        if (-not $obj.ContainsKey("state")) {
            throw "File '$($file.FullName)' missing required property: state"
        }
        if (-not $obj.ContainsKey("conditions")) {
            throw "File '$($file.FullName)' missing required property: conditions"
        }
        if (-not $obj.ContainsKey("grantControls")) {
            throw "File '$($file.FullName)' missing required property: grantControls"
        }

        [PSCustomObject]@{
            Path = $file.FullName
            Payload = $obj
        }
    }
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

function New-OrUpdatePolicy {
    param(
        [hashtable]$Policy,
        [switch]$Replace,
        [switch]$ForceEnabled
    )

    if ($ForceEnabled -and ($Policy.state -ne "enabled")) {
        $Policy.state = "enabled"
    }

    $existing = Get-ExistingPolicyByName -DisplayName $Policy.displayName
    $body = $Policy | ConvertTo-Json -Depth 50

    if ($null -eq $existing) {
        $created = Invoke-MgGraphRequest -Method POST -Uri "/beta/identity/conditionalAccess/policies" -Body $body -ContentType "application/json" -OutputType PSObject
        Write-Host "Created CA policy: $($created.displayName)" -ForegroundColor Green
        return $created
    }

    if (-not $Replace) {
        Write-Host "Skipping existing CA policy: $($Policy.displayName)" -ForegroundColor Yellow
        return $existing
    }

    Invoke-MgGraphRequest -Method PATCH -Uri "/beta/identity/conditionalAccess/policies/$($existing.id)" -Body $body -ContentType "application/json" | Out-Null
    $updated = Invoke-MgGraphRequest -Method GET -Uri "/beta/identity/conditionalAccess/policies/$($existing.id)" -OutputType PSObject
    Write-Host "Updated CA policy: $($updated.displayName)" -ForegroundColor Green
    return $updated
}

Write-Section "Authenticating to Microsoft Graph"
Connect-Graph

Write-Section "Loading Conditional Access policy definitions"
$resolvedFolder = Resolve-InputFolder -Path $PolicyFolder
$policies = Get-PolicyDefinitions -Folder $resolvedFolder
Write-Host "Loaded $($policies.Count) Conditional Access policy definition file(s)." -ForegroundColor Green

Write-Section "Deploying Conditional Access policies"
foreach ($entry in $policies) {
    $policy = $entry.Payload

    if (-not $AllowPlaceholders) {
        $placeholders = Find-PlaceholderValues -Node $policy
        if ($placeholders.Count -gt 0) {
            $joined = [string]::Join(", ", $placeholders)
            throw "Policy '$($policy.displayName)' contains unresolved placeholders: $joined"
        }
    }

    Remove-ReadOnlyFields -Node $policy
    [void](New-OrUpdatePolicy -Policy $policy -Replace:$ReplaceExisting -ForceEnabled:$ForceEnable)
}

Write-Section "Completed"
Write-Host "Conditional Access baseline deployment completed successfully." -ForegroundColor Green
