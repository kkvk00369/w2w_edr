[CmdletBinding()]
param(
    [string]$OutputPath = "$PSScriptRoot/evidence",
    [string]$PilotGroupName = "SG-Intune-Pilot-Users",
    [string]$DynamicWin11GroupName = "SG-Devices-Win11-Corporate"
)

if (-not (Test-Path -Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

$intuneAppId = "0000000a-0000-0000-c000-000000000000"
$policy = Get-MgPolicyMobilityManagementPolicy | Where-Object { $_.AppId -eq $intuneAppId }

if (-not $policy) {
    throw "Microsoft Intune mobility management policy not found."
}

$updatedPolicy = Get-MgPolicyMobilityManagementPolicy -MobilityManagementPolicyId $policy.Id
$assignedGroups = @(Get-MgPolicyMobilityManagementPolicyIncludedGroup -MobilityManagementPolicyId $policy.Id)

$safePilotName = $PilotGroupName.Replace("'", "''")
$safeDynamicName = $DynamicWin11GroupName.Replace("'", "''")
$pilotGroup = Get-MgGroup -Filter "displayName eq '$safePilotName'" -ConsistencyLevel eventual
$dynamicGroup = Get-MgGroup -Filter "displayName eq '$safeDynamicName'" -ConsistencyLevel eventual

$tenantContext = Get-MgContext

$evidence = [PSCustomObject]@{
    generatedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
    tenantId       = $tenantContext.TenantId
    account        = $tenantContext.Account
    policy         = [PSCustomObject]@{
        id             = $updatedPolicy.Id
        displayName    = $updatedPolicy.DisplayName
        appId          = $updatedPolicy.AppId
        appliesTo      = $updatedPolicy.AppliesTo
        discoveryUrl   = $updatedPolicy.DiscoveryUrl
        complianceUrl  = $updatedPolicy.ComplianceUrl
        termsOfUseUrl  = $updatedPolicy.TermsOfUseUrl
    }
    includedGroups = @($assignedGroups | ForEach-Object {
        [PSCustomObject]@{
            id = $_.Id
        }
    })
    enrollmentGroups = [PSCustomObject]@{
        pilotGroup = if ($pilotGroup) {
            [PSCustomObject]@{
                id          = $pilotGroup.Id
                displayName = $pilotGroup.DisplayName
            }
        } else {
            $null
        }
        dynamicWin11Group = if ($dynamicGroup) {
            [PSCustomObject]@{
                id          = $dynamicGroup.Id
                displayName = $dynamicGroup.DisplayName
            }
        } else {
            $null
        }
    }
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$filePath = Join-Path $OutputPath "Intune-MdmBootstrapEvidence-$timestamp.json"
$evidence | ConvertTo-Json -Depth 8 | Out-File -FilePath $filePath -Encoding utf8

Write-Host "Evidence exported to: $filePath"

[PSCustomObject]@{
    FilePath = $filePath
    GeneratedAtUtc = $evidence.generatedAtUtc
    AppliesTo = $evidence.policy.appliesTo
    IncludedGroupCount = @($assignedGroups).Count
}
