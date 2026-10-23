[CmdletBinding()]
param(
    [ValidateSet("all", "selected", "none")]
    [string]$AppliesTo = "selected",

    [string]$PilotGroupName = "SG-Intune-Pilot-Users",
    [string]$DynamicWin11GroupName = "SG-Devices-Win11-Corporate",
    [switch]$ExportEvidence,
    [string]$EvidenceOutputPath,

    [switch]$SkipModuleInstall,
    [switch]$SkipConnect,
    [string]$TenantId
)

$root = $PSScriptRoot

if (-not $SkipModuleInstall) {
    & "$root/Install-IntuneGraphPrereqs.ps1"
}

if (-not $SkipConnect) {
    if ($TenantId) {
        & "$root/Connect-IntuneGraph.ps1" -TenantId $TenantId
    }
    else {
        & "$root/Connect-IntuneGraph.ps1"
    }
}

$groups = & "$root/New-IntuneEnrollmentGroups.ps1" -PilotGroupName $PilotGroupName -DynamicWin11GroupName $DynamicWin11GroupName
$groups | Out-Null

& "$root/Set-IntuneAutomaticMdmEnrollment.ps1" -AppliesTo $AppliesTo -PilotGroupName $PilotGroupName

Write-Host "Verification output:"
& "$root/Verify-IntuneMdmEnrollmentConfig.ps1"

if ($ExportEvidence) {
    $exportParams = @{
        PilotGroupName = $PilotGroupName
        DynamicWin11GroupName = $DynamicWin11GroupName
    }

    if ($EvidenceOutputPath) {
        $exportParams.OutputPath = $EvidenceOutputPath
    }

    Write-Host "Exporting evidence..."
    & "$root/Export-IntuneBootstrapEvidence.ps1" @exportParams
}
