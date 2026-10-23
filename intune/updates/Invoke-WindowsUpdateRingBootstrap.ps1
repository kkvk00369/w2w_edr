[CmdletBinding()]
param(
    [string]$TenantId,
    [string]$TargetGroupName = "SG-Devices-Win11-Corporate",
    [switch]$ExportEvidence,
    [string]$EvidenceOutputPath,
    [switch]$SkipModuleInstall,
    [switch]$SkipConnect
)

$root = $PSScriptRoot

if (-not $SkipModuleInstall) {
    & "$root/Install-UpdateRingGraphPrereqs.ps1"
}

if (-not $SkipConnect) {
    if ($TenantId) {
        & "$root/Connect-UpdateRingGraph.ps1" -TenantId $TenantId
    }
    else {
        & "$root/Connect-UpdateRingGraph.ps1"
    }
}

$ring = & "$root/New-Windows11GeneralFleetUpdateRing.ps1" -TargetGroupName $TargetGroupName

Write-Host "Verification output:"
& "$root/Verify-WindowsUpdateRingPolicy.ps1" -PolicyId $ring.PolicyId

if ($ExportEvidence) {
    $exportParams = @{
        PolicyId = $ring.PolicyId
    }

    if ($EvidenceOutputPath) {
        $exportParams.OutputPath = $EvidenceOutputPath
    }

    Write-Host "Exporting evidence..."
    & "$root/Export-WindowsUpdateRingEvidence.ps1" @exportParams
}
