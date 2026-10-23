[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PolicyId
)

$policyCheck = Get-MgDeviceManagementDeviceConfiguration -DeviceConfigurationId $PolicyId
$assignments = @(Get-MgDeviceManagementDeviceConfigurationAssignment -DeviceConfigurationId $PolicyId)
$firstAssignment = $assignments | Select-Object -First 1

[PSCustomObject]@{
    PolicyId = $policyCheck.Id
    DisplayName = $policyCheck.DisplayName
    QualityDeferralDays = $policyCheck.AdditionalProperties["qualityUpdatesDeferralPeriodInDays"]
    DriversExcluded = $policyCheck.AdditionalProperties["driversExcluded"]
    AssignedGroupId = if ($firstAssignment) { $firstAssignment.Target.AdditionalProperties["groupId"] } else { $null }
    AssignmentCount = @($assignments).Count
}
