[CmdletBinding()]
param(
    [string]$TargetGroupName = "SG-Devices-Win11-Corporate",
    [string]$ProfileDisplayName = "Emergency Zero-Day Expedited Patch",
    [string]$ProfileDescription = "Overrides standard ring deferral to install critical security patch immediately.",
    [string]$DeployableContentDisplayName = "Expedited Security Update",
    [string]$QualityUpdateRelease = "2024.10 B",
    [ValidateRange(0, 14)]
    [int]$DaysUntilForcedReboot = 1
)

$safeGroupName = $TargetGroupName.Replace("'", "''")
$group = Get-MgGroup -Filter "displayName eq '$safeGroupName'" -ConsistencyLevel eventual
if (-not $group) {
    throw "Target group '$TargetGroupName' could not be resolved."
}

$profileBody = @{
    "@odata.type" = "#microsoft.graph.windowsQualityUpdateProfile"
    displayName = $ProfileDisplayName
    description = $ProfileDescription
    deployableContentDisplayName = $DeployableContentDisplayName
    expeditedUpdateSettings = @{
        "@odata.type" = "#microsoft.graph.expeditedWindowsQualityUpdateSettings"
        qualityUpdateRelease = $QualityUpdateRelease
        daysUntilForcedReboot = $DaysUntilForcedReboot
    }
}

$createUri = "https://graph.microsoft.com/beta/deviceManagement/windowsQualityUpdateProfiles"
$createdProfile = Invoke-MgGraphRequest -Method POST -Uri $createUri -Body ($profileBody | ConvertTo-Json -Depth 8)

Write-Host "Created Expedited Profile ID: $($createdProfile.id)"

$assignmentBody = @{
    assignments = @(
        @{
            target = @{
                "@odata.type" = "#microsoft.graph.groupAssignmentTarget"
                groupId = $group.Id
            }
        }
    )
}

$assignUri = "https://graph.microsoft.com/beta/deviceManagement/windowsQualityUpdateProfiles/$($createdProfile.id)/assign"
Invoke-MgGraphRequest -Method POST -Uri $assignUri -Body ($assignmentBody | ConvertTo-Json -Depth 5)

Write-Host "Successfully assigned Expedited Patch Profile to $($group.DisplayName) ($($group.Id))."

[PSCustomObject]@{
    ProfileId = $createdProfile.id
    ProfileDisplayName = $createdProfile.displayName
    TargetGroupId = $group.Id
    TargetGroupDisplayName = $group.DisplayName
    QualityUpdateRelease = $QualityUpdateRelease
    DaysUntilForcedReboot = $DaysUntilForcedReboot
}
