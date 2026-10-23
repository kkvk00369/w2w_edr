# Intune Windows Update Ring Automation (Microsoft Graph)

This folder contains PowerShell scripts to create and assign a production-ready Windows Update for Business ring policy using Microsoft Graph.

## Scripts

- `Install-UpdateRingGraphPrereqs.ps1`
- `Connect-UpdateRingGraph.ps1`
- `New-Windows11GeneralFleetUpdateRing.ps1`
- `Verify-WindowsUpdateRingPolicy.ps1`
- `Export-WindowsUpdateRingEvidence.ps1`
- `Invoke-WindowsUpdateRingBootstrap.ps1`

## Required Graph Scopes

- `DeviceManagementConfiguration.ReadWrite.All`
- `Group.Read.All`

## Quick Start

```powershell
cd intune/updates
./Invoke-WindowsUpdateRingBootstrap.ps1

# Run end-to-end and export timestamped evidence JSON
./Invoke-WindowsUpdateRingBootstrap.ps1 -ExportEvidence
```

## Step-by-Step

```powershell
./Install-UpdateRingGraphPrereqs.ps1
./Connect-UpdateRingGraph.ps1
$ring = ./New-Windows11GeneralFleetUpdateRing.ps1
./Verify-WindowsUpdateRingPolicy.ps1 -PolicyId $ring.PolicyId
./Export-WindowsUpdateRingEvidence.ps1 -PolicyId $ring.PolicyId
```

## Defaults

- Target Group Name: `SG-Devices-Win11-Corporate`
- Policy Name: `Windows 11 - General Fleet Update Ring`
- Quality Deferral: `3` days
- Feature Deferral: `0` days
- Active Hours: `08:00:00` to `17:00:00`
- Restart deadline and snooze settings aligned to your provided baseline
- Evidence files are written to `intune/updates/evidence` by default
- Use `-EvidenceOutputPath` with `Invoke-WindowsUpdateRingBootstrap.ps1` to override the output folder
