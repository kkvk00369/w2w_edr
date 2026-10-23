# Intune Expedited Quality Updates Automation (Microsoft Graph)

This folder contains PowerShell scripts to create and assign a Windows expedited quality update profile using Microsoft Graph beta endpoints.

## Scripts

- Install-ExpediteGraphPrereqs.ps1
- Connect-ExpediteGraph.ps1
- New-ExpeditedQualityUpdateProfile.ps1
- Verify-ExpeditedQualityUpdateProfile.ps1
- Invoke-ExpeditedQualityUpdateBootstrap.ps1
- Invoke-EndpointImmediateUpdateScan.ps1

## Required Graph Scopes

- DeviceManagementConfiguration.ReadWrite.All
- Group.Read.All

## Quick Start

```powershell
cd intune/expedit
./Invoke-ExpeditedQualityUpdateBootstrap.ps1
```

## Step-by-Step

```powershell
./Install-ExpediteGraphPrereqs.ps1
./Connect-ExpediteGraph.ps1
$profile = ./New-ExpeditedQualityUpdateProfile.ps1
./Verify-ExpeditedQualityUpdateProfile.ps1 -ProfileId $profile.ProfileId
```

## Defaults

- Target Group Name: SG-Devices-Win11-Corporate
- Profile Name: Emergency Zero-Day Expedited Patch
- Release String: 2024.10 B
- Days Until Forced Reboot: 1

## Device-Side Trigger

Expedited update deployment is cloud-push driven, but you can trigger a manual scan on an endpoint with:

```powershell
./Invoke-EndpointImmediateUpdateScan.ps1
```

This runs:

- UsoClient.exe StartInteractiveScan

Run endpoint-trigger scripts on Windows devices with appropriate local privileges.
