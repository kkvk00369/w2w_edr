[CmdletBinding()]
param(
    [string]$PilotGroupName = "SG-Intune-Pilot-Users",
    [string]$DynamicWin11GroupName = "SG-Devices-Win11-Corporate"
)

function Get-GroupByDisplayName {
    param([Parameter(Mandatory = $true)][string]$DisplayName)

    $safeName = $DisplayName.Replace("'", "''")
    return Get-MgGroup -Filter "displayName eq '$safeName'" -ConsistencyLevel eventual
}

$pilotGroup = Get-GroupByDisplayName -DisplayName $PilotGroupName
if (-not $pilotGroup) {
    $pilotGroup = New-MgGroup -DisplayName $PilotGroupName `
        -MailEnabled:$false `
        -MailNickname ($PilotGroupName -replace "[^a-zA-Z0-9-]", "") `
        -SecurityEnabled:$true `
        -Description "Target group for initial Intune MDM onboarding pilot"
    Write-Host "Created Pilot Group: $($pilotGroup.DisplayName) [$($pilotGroup.Id)]"
}
else {
    Write-Host "Pilot Group already exists: $($pilotGroup.DisplayName) [$($pilotGroup.Id)]"
}

$dynamicWin11Group = Get-GroupByDisplayName -DisplayName $DynamicWin11GroupName
if (-not $dynamicWin11Group) {
    $dynamicWin11Group = New-MgGroup -DisplayName $DynamicWin11GroupName `
        -MailEnabled:$false `
        -MailNickname ($DynamicWin11GroupName -replace "[^a-zA-Z0-9-]", "") `
        -SecurityEnabled:$true `
        -GroupTypes @("DynamicMembership") `
        -MembershipRule '(device.deviceOSType -eq "Windows") and (device.deviceOSVersion -startsWith "10.0.22") and (device.deviceOwnership -eq "Company")' `
        -MembershipRuleProcessingState "On" `
        -Description "Dynamic group matching all corporate Windows 11 endpoints"
    Write-Host "Created Dynamic Device Group: $($dynamicWin11Group.DisplayName) [$($dynamicWin11Group.Id)]"
}
else {
    Write-Host "Dynamic Device Group already exists: $($dynamicWin11Group.DisplayName) [$($dynamicWin11Group.Id)]"
}

[PSCustomObject]@{
    PilotGroupId          = $pilotGroup.Id
    PilotGroupDisplayName = $pilotGroup.DisplayName
    DynamicGroupId        = $dynamicWin11Group.Id
    DynamicGroupDisplayName = $dynamicWin11Group.DisplayName
}
