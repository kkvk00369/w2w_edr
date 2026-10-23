[CmdletBinding()]
param(
    [string]$PolicyId,
    [string]$PolicyDisplayName = "Windows 11 - General Fleet Update Ring",
    [string]$OutputPath = "$PSScriptRoot/evidence"
)

if (-not (Test-Path -Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

if (-not $PolicyId) {
    $safeDisplayName = $PolicyDisplayName.Replace("'", "''")
    $matchingPolicies = @(Get-MgDeviceManagementDeviceConfiguration -Filter "displayName eq '$safeDisplayName'")

    if (-not $matchingPolicies) {
        throw "No device configuration policy found with display name '$PolicyDisplayName'. Provide -PolicyId explicitly."
    }

    # If multiple policies have the same name, pick the first one returned by Graph.
    $PolicyId = $matchingPolicies[0].Id
}

$policy = Get-MgDeviceManagementDeviceConfiguration -DeviceConfigurationId $PolicyId
$assignments = @(Get-MgDeviceManagementDeviceConfigurationAssignment -DeviceConfigurationId $PolicyId)

$assignmentDetails = @(
    $assignments | ForEach-Object {
        [PSCustomObject]@{
            id = $_.Id
            groupId = $_.Target.AdditionalProperties["groupId"]
            odataType = $_.Target.AdditionalProperties["@odata.type"]
        }
    }
)

$context = Get-MgContext
$evidence = [PSCustomObject]@{
    generatedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
    tenantId = $context.TenantId
    account = $context.Account
    policy = [PSCustomObject]@{
        id = $policy.Id
        displayName = $policy.DisplayName
        description = $policy.Description
        qualityUpdatesDeferralPeriodInDays = $policy.AdditionalProperties["qualityUpdatesDeferralPeriodInDays"]
        featureUpdatesDeferralPeriodInDays = $policy.AdditionalProperties["featureUpdatesDeferralPeriodInDays"]
        driversExcluded = $policy.AdditionalProperties["driversExcluded"]
        automaticUpdateMode = $policy.AdditionalProperties["automaticUpdateMode"]
        activeHoursStart = $policy.AdditionalProperties["activeHoursStart"]
        activeHoursEnd = $policy.AdditionalProperties["activeHoursEnd"]
    }
    assignments = $assignmentDetails
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$filePath = Join-Path $OutputPath "WindowsUpdateRingEvidence-$timestamp.json"
$evidence | ConvertTo-Json -Depth 10 | Out-File -FilePath $filePath -Encoding utf8

Write-Host "Evidence exported to: $filePath"

[PSCustomObject]@{
    FilePath = $filePath
    PolicyId = $policy.Id
    DisplayName = $policy.DisplayName
    AssignmentCount = @($assignments).Count
    GeneratedAtUtc = $evidence.generatedAtUtc
}
