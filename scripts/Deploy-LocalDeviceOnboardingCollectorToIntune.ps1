[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TenantId,

    [Parameter(Mandatory = $true)]
    [string]$TargetGroupId,

    [Parameter()]
    [string]$ScriptDisplayName = "Collect-LocalDeviceOnboardingDetails",

    [Parameter()]
    [string]$ScriptDescription = "Collects local Windows onboarding details and Autopilot metadata for centralized onboarding.",

    [Parameter()]
    [string]$CollectorScriptPath = "./Collect-LocalDeviceOnboardingDetails.ps1",

    [Parameter()]
    [string]$OutputFolder = "C:\\ProgramData\\IntuneOnboarding",

    [Parameter()]
    [string]$GroupTag,

    [Parameter()]
    [string]$AssignedUserPrincipalName,

    [Parameter()]
    [string]$ResultWebhookUrl,

    [Parameter()]
    [switch]$SkipHardwareHash,

    [Parameter()]
    [ValidateSet("system", "user")]
    [string]$RunAsAccount = "system",

    [Parameter()]
    [switch]$RunAs32Bit,

    [Parameter()]
    [switch]$ReplaceExisting,

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
        "DeviceManagementConfiguration.ReadWrite.All",
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

function Resolve-PathFromScriptRoot {
    param([string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    $scriptRoot = Split-Path -Parent $PSCommandPath
    return (Resolve-Path (Join-Path $scriptRoot $Path)).Path
}

function Get-GroupById {
    param([string]$GroupId)

    try {
        return (Invoke-MgGraphRequest -Method GET -Uri "/v1.0/groups/$GroupId" -OutputType PSObject)
    }
    catch {
        throw "Could not resolve target group id '$GroupId'."
    }
}

function Get-DeviceManagementScriptByName {
    param([string]$DisplayName)

    $escaped = $DisplayName.Replace("'", "''")
    $uri = "/beta/deviceManagement/deviceManagementScripts?`$filter=displayName eq '$escaped'"
    $result = Invoke-MgGraphRequest -Method GET -Uri $uri -OutputType PSObject
    if ($result.value.Count -gt 0) {
        return $result.value[0]
    }

    return $null
}

function Render-CollectorScript {
    param(
        [string]$SourcePath,
        [string]$DefaultOutputFolder,
        [string]$DefaultGroupTag,
        [string]$DefaultAssignedUpn,
        [string]$WebhookUrl,
        [switch]$NoHardwareHash
    )

    $source = Get-Content -Path $SourcePath -Raw

    $headerLines = @(
        "$env:LOCAL_ONBOARD_OUTPUT_FOLDER = '$($DefaultOutputFolder -replace "'", "''")'",
        "$env:LOCAL_ONBOARD_GROUPTAG = '$($DefaultGroupTag -replace "'", "''")'",
        "$env:LOCAL_ONBOARD_ASSIGNED_UPN = '$($DefaultAssignedUpn -replace "'", "''")'",
        "$env:LOCAL_ONBOARD_WEBHOOK_URL = '$($WebhookUrl -replace "'", "''")'"
    )

    if ($NoHardwareHash) {
        $headerLines += "$env:LOCAL_ONBOARD_SKIP_HASH = '1'"
    }

    return ($headerLines -join "`r`n") + "`r`n`r`n" + $source
}

function Convert-ToGraphScriptContent {
    param([string]$Text)

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    return [Convert]::ToBase64String($bytes)
}

function New-OrReplaceDeviceManagementScript {
    param(
        [string]$DisplayName,
        [string]$Description,
        [string]$ScriptContentBase64,
        [string]$FileName,
        [string]$RunAs,
        [bool]$Run32Bit,
        [switch]$Replace
    )

    $existing = Get-DeviceManagementScriptByName -DisplayName $DisplayName
    if ($null -ne $existing) {
        if (-not $Replace) {
            Write-Host "Using existing Intune script: $DisplayName" -ForegroundColor Green
            return $existing
        }

        Write-Host "Replacing existing Intune script: $DisplayName" -ForegroundColor Yellow
        Invoke-MgGraphRequest -Method DELETE -Uri "/beta/deviceManagement/deviceManagementScripts/$($existing.id)"
    }

    $body = @{
        displayName = $DisplayName
        description = $Description
        scriptContent = $ScriptContentBase64
        fileName = $FileName
        runAsAccount = $RunAs
        enforceSignatureCheck = $false
        runAs32Bit = $Run32Bit
        roleScopeTagIds = @("0")
    } | ConvertTo-Json -Depth 8

    return (Invoke-MgGraphRequest -Method POST -Uri "/beta/deviceManagement/deviceManagementScripts" -Body $body -ContentType "application/json" -OutputType PSObject)
}

function Set-DeviceManagementScriptAssignment {
    param(
        [string]$ScriptId,
        [string]$GroupId
    )

    $body = @{
        deviceManagementScriptAssignments = @(
            @{
                target = @{
                    "@odata.type" = "#microsoft.graph.groupAssignmentTarget"
                    groupId = $GroupId
                }
            }
        )
    } | ConvertTo-Json -Depth 10

    Invoke-MgGraphRequest -Method POST -Uri "/beta/deviceManagement/deviceManagementScripts/$ScriptId/assign" -Body $body -ContentType "application/json" | Out-Null
}

Write-Section "Authenticating to Microsoft Graph"
Connect-Graph

Write-Section "Validating target group"
$group = Get-GroupById -GroupId $TargetGroupId
Write-Host "Target group: $($group.displayName) ($TargetGroupId)" -ForegroundColor Green

Write-Section "Building script payload"
$collectorPath = Resolve-PathFromScriptRoot -Path $CollectorScriptPath
$rendered = Render-CollectorScript -SourcePath $collectorPath -DefaultOutputFolder $OutputFolder -DefaultGroupTag $GroupTag -DefaultAssignedUpn $AssignedUserPrincipalName -WebhookUrl $ResultWebhookUrl -NoHardwareHash:$SkipHardwareHash
$scriptContentBase64 = Convert-ToGraphScriptContent -Text $rendered

Write-Section "Creating or updating Intune script"
$script = New-OrReplaceDeviceManagementScript -DisplayName $ScriptDisplayName -Description $ScriptDescription -ScriptContentBase64 $scriptContentBase64 -FileName "Collect-LocalDeviceOnboardingDetails.ps1" -RunAs $RunAsAccount -Run32Bit:$RunAs32Bit -Replace:$ReplaceExisting
Write-Host "Intune script id: $($script.id)" -ForegroundColor Green

Write-Section "Assigning Intune script to target group"
Set-DeviceManagementScriptAssignment -ScriptId $script.id -GroupId $TargetGroupId
Write-Host "Assigned script to group: $($group.displayName)" -ForegroundColor Green

Write-Section "Completed"
Write-Host "Collector deployment completed successfully." -ForegroundColor Green
