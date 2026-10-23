[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProfileId
)

$verifyUri = "https://graph.microsoft.com/beta/deviceManagement/windowsQualityUpdateProfiles/$ProfileId?`$expand=assignments"
$response = Invoke-MgGraphRequest -Method GET -Uri $verifyUri

$assignmentGroupIds = @()
if ($response.assignments) {
    foreach ($assignment in $response.assignments) {
        if ($assignment.target -and $assignment.target.groupId) {
            $assignmentGroupIds += $assignment.target.groupId
        }
    }
}

[PSCustomObject]@{
    DisplayName = $response.displayName
    ProfileId = $response.id
    Release = $response.expeditedUpdateSettings.qualityUpdateRelease
    DaysToReboot = $response.expeditedUpdateSettings.daysUntilForcedReboot
    AssignmentCount = @($assignmentGroupIds).Count
    AssignedGroupIds = ($assignmentGroupIds -join ",")
}
