# Intune Automation via Microsoft Graph (PowerShell)

This folder contains PowerShell scripts to automate:

- Microsoft Graph module installation
- Graph authentication with required scopes
- Entra ID security group creation for Intune rollout
- Automatic MDM enrollment scope and endpoint configuration
- Post-change verification

## Scripts

- `Install-IntuneGraphPrereqs.ps1`
- `Connect-IntuneGraph.ps1`
- `New-IntuneEnrollmentGroups.ps1`
- `Set-IntuneAutomaticMdmEnrollment.ps1`
- `Verify-IntuneMdmEnrollmentConfig.ps1`
- `Export-IntuneBootstrapEvidence.ps1`
- `Invoke-IntuneBootstrap.ps1`

## Required Graph Permissions

- `Group.ReadWrite.All`
- `Policy.ReadWrite.MobilityManagement`
- `DeviceManagementConfiguration.ReadWrite.All`
- `DeviceManagementManagedDevices.ReadWrite.All`
- `Directory.ReadWrite.All`

## Quick Start

```powershell
cd intune

# One command bootstrap (installs modules, connects, creates groups, configures MDM scope, verifies)
./Invoke-IntuneBootstrap.ps1 -AppliesTo selected

# One command bootstrap plus JSON evidence export
./Invoke-IntuneBootstrap.ps1 -AppliesTo selected -ExportEvidence
```

## Step-by-Step

```powershell
./Install-IntuneGraphPrereqs.ps1
./Connect-IntuneGraph.ps1
./New-IntuneEnrollmentGroups.ps1
./Set-IntuneAutomaticMdmEnrollment.ps1 -AppliesTo selected
./Verify-IntuneMdmEnrollmentConfig.ps1
./Export-IntuneBootstrapEvidence.ps1
```

## Notes

- `AppliesTo` supports `all`, `selected`, and `none`.
- For pilot-only enrollment, use `selected` and keep the pilot group assignment.
- For tenant-wide enrollment, use `all`.
- Evidence JSON files are written to `intune/evidence` by default.
- To customize the evidence output folder, use `-EvidenceOutputPath` on `Invoke-IntuneBootstrap.ps1`.
- If using app-only auth, ensure the app registration has equivalent application permissions and admin consent.
