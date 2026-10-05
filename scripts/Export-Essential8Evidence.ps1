[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TenantId,

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
        "DeviceManagementConfiguration.Read.All",
        "DeviceManagementManagedDevices.Read.All",
        "Policy.Read.All",
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

function Resolve-OutputFolder {
    param([string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    $scriptRoot = Split-Path -Parent $PSCommandPath
    return (Join-Path $scriptRoot $Path)
}

function Write-JsonFile {
    param(
        [string]$Path,
        [object]$Data
    )

    $json = $Data | ConvertTo-Json -Depth 50
    Set-Content -Path $Path -Value $json -Encoding utf8
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

Write-Section "Authenticating to Microsoft Graph"
Connect-Graph

Write-Section "Preparing output folder"
$resolvedOutput = Resolve-OutputFolder -Path $OutputFolder
if (-not (Test-Path -Path $resolvedOutput)) {
    New-Item -ItemType Directory -Path $resolvedOutput -Force | Out-Null
}
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$runFolder = Join-Path $resolvedOutput "e8-evidence-$timestamp"
New-Item -ItemType Directory -Path $runFolder -Force | Out-Null

Write-Section "Collecting Intune configuration policies"
$configPolicies = Get-AllPages -Uri "/beta/deviceManagement/configurationPolicies"
Write-JsonFile -Path (Join-Path $runFolder "intune-configuration-policies.json") -Data $configPolicies

Write-Section "Collecting Conditional Access policies"
$caPolicies = Get-AllPages -Uri "/beta/identity/conditionalAccess/policies"
Write-JsonFile -Path (Join-Path $runFolder "conditional-access-policies.json") -Data $caPolicies

Write-Section "Collecting managed device inventory"
$managedDevices = Get-AllPages -Uri "/beta/deviceManagement/managedDevices?`$select=id,deviceName,operatingSystem,osVersion,complianceState,managementState,lastSyncDateTime,azureADDeviceId"
Write-JsonFile -Path (Join-Path $runFolder "managed-devices.json") -Data $managedDevices

Write-Section "Collecting recent sign-in logs"
$since = (Get-Date).AddDays(-7).ToString("o")
$signInUri = "/beta/auditLogs/signIns?`$filter=createdDateTime ge $since"
$signIns = Get-AllPages -Uri $signInUri
Write-JsonFile -Path (Join-Path $runFolder "signin-logs-last-7-days.json") -Data $signIns

Write-Section "Building summary"
$windowsDevices = @($managedDevices | Where-Object { $_.operatingSystem -eq "Windows" })
$compliantWindows = @($windowsDevices | Where-Object { $_.complianceState -eq "compliant" })
$nonCompliantWindows = @($windowsDevices | Where-Object { $_.complianceState -ne "compliant" })
$enabledCa = @($caPolicies | Where-Object { $_.state -eq "enabled" })
$reportOnlyCa = @($caPolicies | Where-Object { $_.state -eq "enabledForReportingButNotEnforced" })

$summary = [PSCustomObject]@{
    generatedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
    tenantId = $TenantId
    intuneConfigurationPolicyCount = $configPolicies.Count
    conditionalAccessPolicyCount = $caPolicies.Count
    conditionalAccessEnabledCount = $enabledCa.Count
    conditionalAccessReportOnlyCount = $reportOnlyCa.Count
    windowsManagedDeviceCount = $windowsDevices.Count
    windowsCompliantDeviceCount = $compliantWindows.Count
    windowsNonCompliantDeviceCount = $nonCompliantWindows.Count
    signInRecordCountLast7Days = $signIns.Count
}

Write-JsonFile -Path (Join-Path $runFolder "summary.json") -Data $summary

Write-Host "Evidence export completed: $runFolder" -ForegroundColor Green
