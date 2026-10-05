[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TenantId,

    [Parameter()]
    [string]$DynamicGroupName = "Intune-Windows-EntraJoined-All",

    [Parameter()]
    [string]$AutopilotCsvPath,

    [Parameter()]
    [switch]$TriggerSyncForCurrentWindowsDevices,

    [Parameter()]
    [int]$SyncBatchSize = 200,

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
        "Group.ReadWrite.All",
        "DeviceManagementServiceConfig.ReadWrite.All",
        "DeviceManagementManagedDevices.ReadWrite.All"
    )

    if ($UseManagedIdentity) {
        Connect-MgGraph -Identity -TenantId $TenantId -NoWelcome
    }
    else {
        Connect-MgGraph -TenantId $TenantId -Scopes $scopes -NoWelcome
    }

    Select-MgProfile -Name "beta"
}

function Get-OrCreateDynamicDeviceGroup {
    param([string]$GroupName)

    $escaped = $GroupName.Replace("'", "''")
    $uri = "/v1.0/groups?`$filter=displayName eq '$escaped'"
    $existing = Invoke-MgGraphRequest -Method GET -Uri $uri -OutputType PSObject

    if ($existing.value.Count -gt 0) {
        Write-Host "Using existing dynamic group: $GroupName" -ForegroundColor Green
        return $existing.value[0]
    }

    $mailNick = ($GroupName -replace "[^a-zA-Z0-9]", "").ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($mailNick)) {
        $mailNick = "intunewindowsdevices"
    }

    $body = @{
        displayName = $GroupName
        description = "Dynamic group for Entra ID joined Windows devices."
        mailEnabled = $false
        securityEnabled = $true
        mailNickname = $mailNick
        groupTypes = @("DynamicMembership")
        membershipRule = '(device.deviceOSType -eq "Windows") and (device.trustType -eq "AzureAD")'
        membershipRuleProcessingState = "On"
    } | ConvertTo-Json -Depth 10

    $created = Invoke-MgGraphRequest -Method POST -Uri "/v1.0/groups" -Body $body -ContentType "application/json" -OutputType PSObject
    Write-Host "Created dynamic group: $GroupName" -ForegroundColor Green
    return $created
}

function Import-AutopilotDevicesFromCsv {
    param([string]$CsvPath)

    if (-not (Test-Path -Path $CsvPath)) {
        throw "Autopilot CSV path not found: $CsvPath"
    }

    $rows = Import-Csv -Path $CsvPath
    if (-not $rows -or $rows.Count -eq 0) {
        throw "Autopilot CSV is empty: $CsvPath"
    }

    $payloadRows = @()

    foreach ($row in $rows) {
        if (-not $row.'Device Serial Number' -or -not $row.'Hardware Hash') {
            throw "CSV row missing required columns: Device Serial Number, Hardware Hash"
        }

        $payloadRows += @{
            "@odata.type" = "#microsoft.graph.importedWindowsAutopilotDeviceIdentity"
            serialNumber = [string]$row.'Device Serial Number'
            hardwareIdentifier = [string]$row.'Hardware Hash'
            groupTag = [string]$row.'Group Tag'
            productKey = [string]$row.'Windows Product ID'
            assignedUserPrincipalName = [string]$row.'Assigned User Principal Name'
        }
    }

    $body = @{ importedWindowsAutopilotDeviceIdentities = $payloadRows } | ConvertTo-Json -Depth 15
    $result = Invoke-MgGraphRequest -Method POST -Uri "/beta/deviceManagement/importedWindowsAutopilotDeviceIdentities/import" -Body $body -ContentType "application/json" -OutputType PSObject

    Write-Host "Imported $($payloadRows.Count) Autopilot device(s). Import Id: $($result.id)" -ForegroundColor Green
}

function Invoke-WindowsDeviceSync {
    param([int]$MaxDevices)

    $uri = "/beta/deviceManagement/managedDevices?`$filter=operatingSystem eq 'Windows'&`$top=$MaxDevices"
    $devices = Invoke-MgGraphRequest -Method GET -Uri $uri -OutputType PSObject

    if (-not $devices.value -or $devices.value.Count -eq 0) {
        Write-Host "No Windows managed devices found for sync." -ForegroundColor Yellow
        return
    }

    foreach ($device in $devices.value) {
        Invoke-MgGraphRequest -Method POST -Uri "/beta/deviceManagement/managedDevices/$($device.id)/syncDevice" | Out-Null
        Write-Host "Triggered sync: $($device.deviceName)" -ForegroundColor Gray
    }

    Write-Host "Triggered sync for $($devices.value.Count) Windows managed device(s)." -ForegroundColor Green
}

Write-Section "Authenticating to Microsoft Graph"
Connect-Graph

Write-Section "Ensuring dynamic device group for current and future devices"
$group = Get-OrCreateDynamicDeviceGroup -GroupName $DynamicGroupName
Write-Host "Dynamic group id: $($group.id)" -ForegroundColor Green

if ($AutopilotCsvPath) {
    Write-Section "Importing Windows Autopilot devices"
    Import-AutopilotDevicesFromCsv -CsvPath $AutopilotCsvPath
}

if ($TriggerSyncForCurrentWindowsDevices) {
    Write-Section "Triggering Intune sync for existing Windows devices"
    Invoke-WindowsDeviceSync -MaxDevices $SyncBatchSize
}

Write-Section "Completed"
Write-Host "Device onboarding automation completed successfully." -ForegroundColor Green
