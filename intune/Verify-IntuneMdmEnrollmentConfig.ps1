[CmdletBinding()]
param()

$intuneAppId = "0000000a-0000-0000-c000-000000000000"
$policy = Get-MgPolicyMobilityManagementPolicy | Where-Object { $_.AppId -eq $intuneAppId }

if (-not $policy) {
    throw "Microsoft Intune mobility management policy not found."
}

$updatedPolicy = Get-MgPolicyMobilityManagementPolicy -MobilityManagementPolicyId $policy.Id
$assignedGroups = Get-MgPolicyMobilityManagementPolicyIncludedGroup -MobilityManagementPolicyId $policy.Id

$result = [PSCustomObject]@{
    DisplayName      = $updatedPolicy.DisplayName
    AppliesTo        = $updatedPolicy.AppliesTo
    DiscoveryUrl     = $updatedPolicy.DiscoveryUrl
    ComplianceUrl    = $updatedPolicy.ComplianceUrl
    TermsOfUseUrl    = $updatedPolicy.TermsOfUseUrl
    TargetGroupCount = @($assignedGroups).Count
    TargetGroupIds   = @($assignedGroups | ForEach-Object { $_.Id }) -join ","
}

$result
