[CmdletBinding()]
param(
    [Parameter()]
    [string]$OutputFolder = "./out",

    [Parameter()]
    [string]$AppendAutopilotCsvPath,

    [Parameter()]
    [string]$AssignedUserPrincipalName,

    [Parameter()]
    [string]$GroupTag,

    [Parameter()]
    [string]$WindowsProductId,

    [Parameter()]
    [string]$ResultWebhookUrl,

    [Parameter()]
    [switch]$SkipHardwareHash
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Section {
    param([string]$Message)
    Write-Host "`n==== $Message ====" -ForegroundColor Cyan
}

function Get-DsRegStatusMap {
    $map = @{}
    $raw = dsregcmd /status

    foreach ($line in $raw) {
        if ($line -match "^\s*([^:]+)\s*:\s*(.*)$") {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            if (-not [string]::IsNullOrWhiteSpace($key)) {
                $map[$key] = $value
            }
        }
    }

    return $map
}

function Get-AutopilotHardwareHash {
    $instance = Get-CimInstance -Namespace "root/cimv2/mdm/dmmap" -ClassName "MDM_DevDetail_Ext01" -Filter "InstanceID='Ext' AND ParentID='./DevDetail'"

    if (-not $instance -or [string]::IsNullOrWhiteSpace($instance.DeviceHardwareData)) {
        throw "Could not read DeviceHardwareData from MDM bridge. Run as local admin on a supported Windows build."
    }

    return [string]$instance.DeviceHardwareData
}

if (-not $IsWindows) {
    throw "This script must be run on a Windows device."
}

if ([string]::IsNullOrWhiteSpace($OutputFolder) -and -not [string]::IsNullOrWhiteSpace($env:LOCAL_ONBOARD_OUTPUT_FOLDER)) {
    $OutputFolder = $env:LOCAL_ONBOARD_OUTPUT_FOLDER
}

$resolvedGroupTag = $GroupTag
if ([string]::IsNullOrWhiteSpace($resolvedGroupTag) -and -not [string]::IsNullOrWhiteSpace($env:LOCAL_ONBOARD_GROUPTAG)) {
    $resolvedGroupTag = $env:LOCAL_ONBOARD_GROUPTAG
}

$resolvedAssignedUserPrincipalName = $AssignedUserPrincipalName
if ([string]::IsNullOrWhiteSpace($resolvedAssignedUserPrincipalName) -and -not [string]::IsNullOrWhiteSpace($env:LOCAL_ONBOARD_ASSIGNED_UPN)) {
    $resolvedAssignedUserPrincipalName = $env:LOCAL_ONBOARD_ASSIGNED_UPN
}

$resolvedWebhookUrl = $ResultWebhookUrl
if ([string]::IsNullOrWhiteSpace($resolvedWebhookUrl) -and -not [string]::IsNullOrWhiteSpace($env:LOCAL_ONBOARD_WEBHOOK_URL)) {
    $resolvedWebhookUrl = $env:LOCAL_ONBOARD_WEBHOOK_URL
}

if (-not $PSBoundParameters.ContainsKey("SkipHardwareHash") -and ($env:LOCAL_ONBOARD_SKIP_HASH -eq "1")) {
    $SkipHardwareHash = $true
}

Write-Section "Collecting local device details"
$serial = (Get-CimInstance -ClassName Win32_BIOS).SerialNumber
$computerName = $env:COMPUTERNAME
$osCaption = (Get-CimInstance -ClassName Win32_OperatingSystem).Caption

$resolvedProductId = $WindowsProductId
if ([string]::IsNullOrWhiteSpace($resolvedProductId)) {
    $resolvedProductId = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").ProductId
}

Write-Section "Collecting Entra join state"
$dsreg = Get-DsRegStatusMap

$azureAdJoined = $dsreg["AzureAdJoined"]
$domainJoined = $dsreg["DomainJoined"]
$deviceId = $dsreg["DeviceId"]
$tenantId = $dsreg["TenantId"]
$tenantName = $dsreg["TenantName"]
$mdmUrl = $dsreg["MdmUrl"]

$hardwareHash = $null
if (-not $SkipHardwareHash) {
    Write-Section "Collecting Autopilot hardware hash"
    $hardwareHash = Get-AutopilotHardwareHash
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
if (-not (Test-Path -Path $OutputFolder)) {
    New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
}

$detail = [PSCustomObject]@{
    CollectionTimestampUtc = (Get-Date).ToUniversalTime().ToString("o")
    ComputerName = $computerName
    SerialNumber = $serial
    HardwareHashCollected = (-not [string]::IsNullOrWhiteSpace($hardwareHash))
    AzureAdJoined = $azureAdJoined
    DomainJoined = $domainJoined
    DeviceId = $deviceId
    TenantId = $tenantId
    TenantName = $tenantName
    MdmUrl = $mdmUrl
    OperatingSystem = $osCaption
    WindowsProductId = $resolvedProductId
    GroupTag = $resolvedGroupTag
    AssignedUserPrincipalName = $resolvedAssignedUserPrincipalName
}

$jsonPath = Join-Path $OutputFolder "device-onboarding-details-$($computerName)-$timestamp.json"
$detail | ConvertTo-Json -Depth 5 | Set-Content -Path $jsonPath -Encoding UTF8
Write-Host "Wrote local onboarding details: $jsonPath" -ForegroundColor Green

if ($AppendAutopilotCsvPath) {
    Write-Section "Appending row to Autopilot CSV"

    $csvRow = [PSCustomObject]@{
        'Device Serial Number' = $serial
        'Hardware Hash' = $hardwareHash
        'Group Tag' = $resolvedGroupTag
        'Windows Product ID' = $resolvedProductId
        'Assigned User Principal Name' = $resolvedAssignedUserPrincipalName
    }

    if (-not (Test-Path -Path $AppendAutopilotCsvPath)) {
        $csvRow | Export-Csv -Path $AppendAutopilotCsvPath -NoTypeInformation -Encoding UTF8
    }
    else {
        $csvRow | Export-Csv -Path $AppendAutopilotCsvPath -NoTypeInformation -Append -Encoding UTF8
    }

    Write-Host "Updated Autopilot CSV: $AppendAutopilotCsvPath" -ForegroundColor Green
}

if (-not [string]::IsNullOrWhiteSpace($resolvedWebhookUrl)) {
    Write-Section "Sending result to webhook"
    try {
        $payload = $detail | ConvertTo-Json -Depth 8
        Invoke-RestMethod -Method POST -Uri $resolvedWebhookUrl -Body $payload -ContentType "application/json" | Out-Null
        Write-Host "Posted onboarding details to webhook." -ForegroundColor Green
    }
    catch {
        Write-Warning "Webhook post failed: $($_.Exception.Message)"
    }
}

Write-Section "Summary"
Write-Host "Computer Name: $computerName"
Write-Host "Serial Number: $serial"
Write-Host "AzureAdJoined: $azureAdJoined"
Write-Host "TenantId: $tenantId"
Write-Host "MdmUrl: $mdmUrl"
Write-Host "Hardware Hash Collected: $(-not [string]::IsNullOrWhiteSpace($hardwareHash))"
Write-Host "Completed local device onboarding detail collection." -ForegroundColor Green
