[CmdletBinding()]
param(
    [string]$TenantId,
    [string]$TargetGroupName = "SG-Devices-Win11-Corporate",
    [string]$QualityUpdateRelease = "2024.10 B",
    [ValidateRange(0, 14)]
    [int]$DaysUntilForcedReboot = 1,
    [switch]$SkipModuleInstall,
    [switch]$SkipConnect
)

$root = $PSScriptRoot

if (-not $SkipModuleInstall) {
    & "$root/Install-ExpediteGraphPrereqs.ps1"
}

if (-not $SkipConnect) {
    if ($TenantId) {
        & "$root/Connect-ExpediteGraph.ps1" -TenantId $TenantId
    }
    else {
        & "$root/Connect-ExpediteGraph.ps1"
    }
}

$profile = & "$root/New-ExpeditedQualityUpdateProfile.ps1" `
    -TargetGroupName $TargetGroupName `
    -QualityUpdateRelease $QualityUpdateRelease `
    -DaysUntilForcedReboot $DaysUntilForcedReboot

Write-Host "Verification output:"
& "$root/Verify-ExpeditedQualityUpdateProfile.ps1" -ProfileId $profile.ProfileId
