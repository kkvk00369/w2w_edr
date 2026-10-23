[CmdletBinding()]
param(
    [string]$TargetGroupName = "SG-Devices-Win11-Corporate",
    [string]$PolicyDisplayName = "Windows 11 - General Fleet Update Ring",
    [string]$PolicyDescription = "Automated quality/driver patching ring with 3-day quality deferral and active hours.",
    [int]$QualityUpdatesDeferralPeriodInDays = 3,
    [int]$FeatureUpdatesDeferralPeriodInDays = 0,
    [string]$ActiveHoursStart = "08:00:00",
    [string]$ActiveHoursEnd = "17:00:00"
)

$safeGroupName = $TargetGroupName.Replace("'", "''")
$targetGroup = Get-MgGroup -Filter "displayName eq '$safeGroupName'" -ConsistencyLevel eventual
if (-not $targetGroup) {
    throw "Target Entra ID group '$TargetGroupName' was not found."
}

$updateRingParams = @{
    "@odata.type" = "#microsoft.graph.windowsUpdateForBusinessConfiguration"
    displayName = $PolicyDisplayName
    description = $PolicyDescription
    businessReadyUpdatesOnly = "businessReadyOnly"
    qualityUpdatesDeferralPeriodInDays = $QualityUpdatesDeferralPeriodInDays
    featureUpdatesDeferralPeriodInDays = $FeatureUpdatesDeferralPeriodInDays
    microsoftUpdateServiceAllowed = $true
    driversExcluded = $false
    activeHoursStart = $ActiveHoursStart
    activeHoursEnd = $ActiveHoursEnd
    automaticUpdateMode = "autoInstallAndRebootAtMaintenanceTime"
    userWindowsUpdateScanAccess = "disabled"
    allowWindows11Upgrade = $true
    engagedRestartDeadlineInDays = 3
    engagedRestartSnoozeScheduleInDays = 1
    engagedRestartTransitionCompleteInDays = 2
}

$createdRing = New-MgDeviceManagementDeviceConfiguration -BodyParameter $updateRingParams
Write-Host "Update Ring created successfully with ID: $($createdRing.Id)"

$assignmentBody = @{
    assignments = @(
        @{
            target = @{
                "@odata.type" = "#microsoft.graph.groupAssignmentTarget"
                groupId = $targetGroup.Id
            }
        }
    )
}

$assignmentUri = "https://graph.microsoft.com/v1.0/deviceManagement/deviceConfigurations/$($createdRing.Id)/assign"
Invoke-MgGraphRequest -Method POST -Uri $assignmentUri -Body ($assignmentBody | ConvertTo-Json -Depth 5)

Write-Host "Assigned policy '$($createdRing.DisplayName)' to group '$($targetGroup.DisplayName)' ($($targetGroup.Id))."

[PSCustomObject]@{
    PolicyId = $createdRing.Id
    PolicyDisplayName = $createdRing.DisplayName
    TargetGroupId = $targetGroup.Id
    TargetGroupDisplayName = $targetGroup.DisplayName
}
