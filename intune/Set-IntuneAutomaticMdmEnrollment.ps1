[CmdletBinding()]
param(
    [ValidateSet("all", "selected", "none")]
    [string]$AppliesTo = "selected",

    [string]$PilotGroupName = "SG-Intune-Pilot-Users",

    [string]$DiscoveryUrl = "https://enrollment.manage.microsoft.com/enrollmentserver/discovery.svc",
    [string]$ComplianceUrl = "https://portal.manage.microsoft.com/?portalAction=Compliance",
    [string]$TermsOfUseUrl = "https://portal.manage.microsoft.com/?portalAction=TermsOfUse"
)

$intuneAppId = "0000000a-0000-0000-c000-000000000000"
$policy = Get-MgPolicyMobilityManagementPolicy | Where-Object { $_.AppId -eq $intuneAppId }

if (-not $policy) {
    throw "Microsoft Intune mobility management policy not found."
}

$mdmBody = @{
    appliesTo     = $AppliesTo
    discoveryUrl  = $DiscoveryUrl
    complianceUrl = $ComplianceUrl
    termsOfUseUrl = $TermsOfUseUrl
}

Update-MgPolicyMobilityManagementPolicy -MobilityManagementPolicyId $policy.Id -BodyParameter $mdmBody
Write-Host "Updated MDM policy appliesTo='$AppliesTo'."

if ($AppliesTo -eq "selected") {
    $safeName = $PilotGroupName.Replace("'", "''")
    $pilotGroup = Get-MgGroup -Filter "displayName eq '$safeName'" -ConsistencyLevel eventual

    if (-not $pilotGroup) {
        throw "Pilot group '$PilotGroupName' was not found. Run New-IntuneEnrollmentGroups.ps1 first."
    }

    $existingIncludedGroups = Get-MgPolicyMobilityManagementPolicyIncludedGroup -MobilityManagementPolicyId $policy.Id
    $alreadyAssigned = $existingIncludedGroups | Where-Object { $_.Id -eq $pilotGroup.Id }

    if (-not $alreadyAssigned) {
        New-MgPolicyMobilityManagementPolicyIncludedGroup -MobilityManagementPolicyId $policy.Id -DirectoryObjectId $pilotGroup.Id | Out-Null
        Write-Host "Assigned pilot group to MDM scope: $($pilotGroup.DisplayName) [$($pilotGroup.Id)]"
    }
    else {
        Write-Host "Pilot group already assigned to MDM scope: $($pilotGroup.DisplayName) [$($pilotGroup.Id)]"
    }
}
