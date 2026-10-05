# Essential Eight Automation Guide

This guide describes how to automate policy deployment and onboarding for current and future Entra ID joined Windows devices using Intune and Microsoft Defender.

## What this implementation does

- Deploys Intune Settings Catalog policies from JSON files.
- Assigns each policy to pilot and production groups from script parameters.
- Creates or reuses a dynamic device group for all Entra ID joined Windows devices.
- Optionally imports Autopilot device hashes from CSV.
- Optionally triggers an Intune sync for existing managed Windows devices.

## Scripts included

- scripts/Create-TenantSecurityGroups.ps1
- scripts/Deploy-IntuneEssential8Policies.ps1
- scripts/Invoke-DeviceOnboarding.ps1
- scripts/Deploy-ConditionalAccessBaseline.ps1
- scripts/Export-Essential8Evidence.ps1
- scripts/Get-ConditionalAccessReferenceData.ps1
- scripts/Test-ConditionalAccessPolicyPack.ps1
- scripts/New-ConditionalAccessTenantChecklist.ps1
- scripts/Initialize-NewTenantSecurityFoundation.ps1
- scripts/Set-ConditionalAccessTenantValues.ps1
- scripts/Invoke-BreakGlassPostBootstrapHardening.ps1
- scripts/Invoke-NewTenantEssential8Bootstrap.ps1
- scripts/Collect-LocalDeviceOnboardingDetails.ps1
- scripts/Deploy-LocalDeviceOnboardingCollectorToIntune.ps1

## Conditional Access baseline pack

- docs/ConditionalAccess-Baseline-Setup.md
- config/conditional-access/01-ca-require-mfa-all-users.json
- config/conditional-access/02-ca-require-compliant-device-m365.json
- config/conditional-access/03-ca-block-legacy-auth.json
- config/conditional-access/04-ca-phishing-resistant-mfa-admins.json

## Step-by-step use of this repo

Follow this sequence in order for a fresh tenant or for an existing tenant that needs hardening.

### 1) Create the tenant groups and break-glass accounts

Run the foundation bootstrap to create the required groups and break-glass accounts:

```pwsh
pwsh ./scripts/Initialize-NewTenantSecurityFoundation.ps1 \
  -TenantId "TENANT_ID" \
  -CreateTrustedNamedLocation \
  -TrustedNamedLocationName "Trusted Corporate IPs" \
  -TrustedIpCidrs "203.0.113.0/24","198.51.100.0/24" \
  -OutputFolder "../out"
```

If there is no trusted IP or named location, use the fallback pattern:

```pwsh
pwsh ./scripts/Initialize-NewTenantSecurityFoundation.ps1 \
  -TenantId "TENANT_ID" \
  -SkipTrustedNamedLocation \
  -OutputFolder "../out"
```

If you only need the baseline groups and optional emergency accounts without the full bootstrap, use:

```pwsh
pwsh ./scripts/Create-TenantSecurityGroups.ps1 \
  -TenantId "TENANT_ID" \
  -CreateBreakGlassAccounts
```

This step covers:

- break-glass account creation
- emergency account role assignment
- pilot, production, and exclusion group creation
- tenant artifact export for downstream automation

### 2) Create the baseline Azure AD / Entra ID and Intune policies

Generate and validate the CA policy pack:

```pwsh
pwsh ./scripts/Get-ConditionalAccessReferenceData.ps1 \
  -TenantId "TENANT_ID" \
  -OutputFolder "../out"

pwsh ./scripts/Set-ConditionalAccessTenantValues.ps1 \
  -TenantFoundationFile "../out/tenant-foundation-YYYYMMDD-HHMMSS.json" \
  -ReferenceDataFile "../out/ca-reference-data-YYYYMMDD-HHMMSS.json" \
  -PolicyFolder "../config/conditional-access" \
  -OutputFolder "../generated/conditional-access"

pwsh ./scripts/Test-ConditionalAccessPolicyPack.ps1 \
  -PolicyFolder "../generated/conditional-access" \
  -IncludeHardened
```

Then deploy the baseline CA pack:

```pwsh
pwsh ./scripts/Deploy-ConditionalAccessBaseline.ps1 \
  -TenantId "TENANT_ID" \
  -PolicyFolder "../generated/conditional-access/hardened" \
  -ReplaceExisting
```

This step covers:

- MFA requirements
- compliant-device enforcement
- legacy auth blocking
- phishing-resistant MFA for admins
- conditional access hardening

### 3) Deploy the Intune Essential Eight policy set

The repo uses policy JSON files in config/policies and applies them to pilot and production groups.

```pwsh
pwsh ./scripts/Deploy-IntuneEssential8Policies.ps1 \
  -TenantId "TENANT_ID" \
  -PilotGroupId "PILOT_GROUP_ID" \
  -ProductionGroupId "PRODUCTION_GROUP_ID" \
  -ExcludeGroupId "EXCLUDE_GROUP_ID" \
  -PolicyFolder "../config/policies" \
  -ReplaceExisting
```

This step covers:

- application control and security baselines
- user hardening and ASR restrictions
- macro control and browser hardening
- Windows Update ring configuration
- OS patching and security feature enforcement

### 4) Onboard Entra ID joined devices to Intune

```pwsh
pwsh ./scripts/Invoke-DeviceOnboarding.ps1 \
  -TenantId "TENANT_ID" \
  -DynamicGroupName "Intune-Windows-EntraJoined-All" \
  -AutopilotCsvPath "./samples/autopilot-import-sample.csv"
```

Optional existing device sync:

```pwsh
pwsh ./scripts/Invoke-DeviceOnboarding.ps1 \
  -TenantId "TENANT_ID" \
  -TriggerSyncForCurrentWindowsDevices \
  -SyncBatchSize 200
```

This step covers:

- current device onboarding
- future device onboarding
- Autopilot import flow
- policy assignment to the correct device group

### 5) Enable Essential Eight security controls

Use the CA pack and Intune policy deployment together to enable:

- Defender for Endpoint compliance and device protection
- phishing-resistant MFA for administrators
- block legacy authentication
- device compliance and conditional access enforcement
- application control and exploit protection features
- patching and update enforcement

This is the step where the repo turns the tenant from basic identity and device management into an Essential Eight-aligned baseline.

### 6) Set up automatic Windows Updates

The repo uses update ring policies in config/policies to enforce automatic patching. The recommended pattern is:

1. Deploy a pilot update ring to the pilot group.
2. Validate patch compliance and remediation timing.
3. Promote the same update ring to the production group.
4. Keep exclusions in the exclusion group for devices requiring special handling.

Example:

```pwsh
pwsh ./scripts/Deploy-IntuneEssential8Policies.ps1 \
  -TenantId "TENANT_ID" \
  -PilotGroupId "PILOT_GROUP_ID" \
  -ProductionGroupId "PRODUCTION_GROUP_ID" \
  -ExcludeGroupId "EXCLUDE_GROUP_ID" \
  -PolicyFolder "../config/policies" \
  -ReplaceExisting
```

This covers automatic Windows Update deployment from Intune for both quality and feature updates.

## New tenant bootstrap

For new tenants, run foundation bootstrap first. If the tenant has known corporate IP ranges:

pwsh ./scripts/Initialize-NewTenantSecurityFoundation.ps1 \
  -TenantId "TENANT_ID" \
  -CreateTrustedNamedLocation \
  -TrustedNamedLocationName "Trusted Corporate IPs" \
  -TrustedIpCidrs "203.0.113.0/24","198.51.100.0/24" \
  -OutputFolder "../out"

If there is no trusted IP or named location, skip the location and use the compliant-device MFA fallback pattern instead:

pwsh ./scripts/Initialize-NewTenantSecurityFoundation.ps1 \
  -TenantId "TENANT_ID" \
  -SkipTrustedNamedLocation \
  -OutputFolder "../out"

If you only need to create the baseline groups and optionally emergency accounts without running the full bootstrap flow, use:

pwsh ./scripts/Create-TenantSecurityGroups.ps1 \
  -TenantId "TENANT_ID" \
  -CreateBreakGlassAccounts

Generate tenant-ready CA policy files from placeholders:

pwsh ./scripts/Set-ConditionalAccessTenantValues.ps1 \
  -TenantFoundationFile "../out/tenant-foundation-YYYYMMDD-HHMMSS.json" \
  -ReferenceDataFile "../out/ca-reference-data-YYYYMMDD-HHMMSS.json" \
  -PolicyFolder "../config/conditional-access" \
  -OutputFolder "../generated/conditional-access"

## Prerequisites

1. PowerShell 7.x.
2. Microsoft Graph PowerShell module (script can auto-install).
3. Identity with required permissions:
   - DeviceManagementConfiguration.ReadWrite.All
   - DeviceManagementManagedDevices.Read.All
   - Group.Read.All
   - Group.ReadWrite.All
   - DeviceManagementServiceConfig.ReadWrite.All
   - DeviceManagementManagedDevices.ReadWrite.All
4. Intune licenses and Microsoft Defender for Endpoint integration already enabled.

## GitHub workflow setup and validation

This repository includes a pull request validation workflow at .github/workflows/validate-security-automation.yml. It is intended to catch script errors and malformed policy JSON before changes are merged.

### Setup

1. Push the repo to GitHub.
2. In the repository, open Settings > Actions and confirm Actions are enabled.
3. If your organization enforces branch protection, require the workflow to pass before merge.
4. Keep the default branch protected for policy changes.

### Typical usage

- Make a change to scripts or config/conditional-access.
- Open or update a pull request.
- GitHub Actions runs the validation workflow automatically.
- If validation fails, review the job log and fix the script or JSON before merging.

### Local commands to mirror CI

Template validation with placeholders allowed:

```pwsh
pwsh ./scripts/Test-ConditionalAccessPolicyPack.ps1 \
  -PolicyFolder "../config/conditional-access" \
  -IncludeHardened \
  -AllowPlaceholders
```

Strict validation for generated output:

```pwsh
pwsh ./scripts/Test-ConditionalAccessPolicyPack.ps1 \
  -PolicyFolder "../generated/conditional-access" \
  -IncludeHardened
```

PowerShell syntax verification:

```pwsh
pwsh -NoLogo -NoProfile -Command '$hadErr=$false; Get-ChildItem ./scripts/*.ps1 | ForEach-Object { $tokens=$null; $errs=$null; [void][System.Management.Automation.Language.Parser]::ParseFile($_.FullName,[ref]$tokens,[ref]$errs); if($errs.Count -gt 0){ $hadErr=$true; Write-Host "Syntax errors in $($_.Name):"; $errs | ForEach-Object { Write-Host " - $($_.Message)" } } else { Write-Host "OK: $($_.Name)" } }; if($hadErr){ exit 1 }'
```

## Prepare policy files

1. Export baseline policies from Intune Graph as JSON with settings expanded.
2. Save files under config/policies.
3. Add deployment property per file:
   - pilot
   - production
   - both

## Deploy policies

Example:

pwsh ./scripts/Deploy-IntuneEssential8Policies.ps1 \
  -TenantId "TENANT_ID" \
  -PilotGroupId "PILOT_GROUP_ID" \
  -ProductionGroupId "PRODUCTION_GROUP_ID" \
  -ExcludeGroupId "EXCLUDE_GROUP_ID" \
  -PolicyFolder "../config/policies" \
  -ReplaceExisting

## Onboard current and future devices

### Collect local onboarding details on each Windows device

If you need serial number, hardware hash, and join-state data from each endpoint, run this script locally on each device:

```pwsh
pwsh ./scripts/Collect-LocalDeviceOnboardingDetails.ps1 \
  -OutputFolder "./out" \
  -AppendAutopilotCsvPath "./out/autopilot-import.csv" \
  -GroupTag "Production" \
  -AssignedUserPrincipalName "user@contoso.com"
```

What this local script collects:

- Device Serial Number
- Hardware Hash (for Autopilot import)
- Entra join state from dsregcmd
- Device and tenant identifiers
- MDM URL signal for enrollment state

Output:

- JSON detail file per device in the output folder.
- Optional append to an Autopilot CSV with columns required by Invoke-DeviceOnboarding.ps1.

Notes:

- Run in an elevated PowerShell session on Windows.
- Use -SkipHardwareHash only when you are validating join state and do not need Autopilot import data.

### Deploy local collection as an Intune campaign

To run the local collector across many endpoints, deploy it as an Intune PowerShell script assignment:

```pwsh
pwsh ./scripts/Deploy-LocalDeviceOnboardingCollectorToIntune.ps1 \
  -TenantId "TENANT_ID" \
  -TargetGroupId "PILOT_OR_PRODUCTION_DEVICE_GROUP_ID" \
  -ScriptDisplayName "Collect-LocalDeviceOnboardingDetails" \
  -OutputFolder "C:\ProgramData\IntuneOnboarding" \
  -GroupTag "Production" \
  -AssignedUserPrincipalName "user@contoso.com" \
  -ResultWebhookUrl "https://YOUR_LOGICAPP_OR_FUNCTION_ENDPOINT" \
  -ReplaceExisting
```

What this deployment wrapper does:

- Uploads the local collector script to Intune device scripts.
- Assigns it to the target Entra group.
- Injects environment-based defaults for group tag, assigned user, output folder, and optional webhook target.

Recommended centralization pattern:

1. Use ResultWebhookUrl to send JSON output from each endpoint to a Logic App, Function, or API endpoint.
2. Persist records in Log Analytics, Storage, or a database.
3. Build the final consolidated Autopilot CSV from collected records and import with Invoke-DeviceOnboarding.ps1.

### Quick onboarding checklist

1. Confirm the tenant is ready for Intune and Entra ID joined Windows devices.
2. Run the onboarding script to create or reuse the dynamic device group.
3. Import a CSV file for bulk Autopilot enrollment if required.
4. Trigger a sync for existing Windows devices if some are already in Intune.
5. Ensure Intune policies are assigned to the dynamic group.

### 1) Ensure dynamic group and optionally import Autopilot hashes

```pwsh
pwsh ./scripts/Invoke-DeviceOnboarding.ps1 \
  -TenantId "TENANT_ID" \
  -DynamicGroupName "Intune-Windows-EntraJoined-All" \
  -AutopilotCsvPath "./samples/autopilot-import-sample.csv"
```

### 2) Trigger sync for current devices (optional)

```pwsh
pwsh ./scripts/Invoke-DeviceOnboarding.ps1 \
  -TenantId "TENANT_ID" \
  -TriggerSyncForCurrentWindowsDevices \
  -SyncBatchSize 200
```

### 3) Autopilot CSV template

Use the sample file at [samples/autopilot-import-sample.csv](../samples/autopilot-import-sample.csv) as the starting point. It contains the required columns:

- Device Serial Number
- Hardware Hash
- Group Tag (optional)
- Windows Product ID (optional)
- Assigned User Principal Name (optional)

## Deploy Conditional Access baseline

Use JSON files in config/conditional-access.

Before first deployment, export tenant reference IDs:

pwsh ./scripts/Get-ConditionalAccessReferenceData.ps1 \
  -TenantId "TENANT_ID" \
  -OutputFolder "../out"

Generate tenant replacement checklist from exported data:

pwsh ./scripts/New-ConditionalAccessTenantChecklist.ps1 \
  -ReferenceDataPath "../out/ca-reference-data-YYYYMMDD-HHMMSS.json" \
  -OutputFolder "../out"

Validate policy pack before deployment:

pwsh ./scripts/Test-ConditionalAccessPolicyPack.ps1 \
  -PolicyFolder "../generated/conditional-access"

Report-only rollout:

pwsh ./scripts/Deploy-ConditionalAccessBaseline.ps1 \
  -TenantId "TENANT_ID" \
  -PolicyFolder "../config/conditional-access" \
  -ReplaceExisting

Force all CA policy states to enabled after validation:

pwsh ./scripts/Deploy-ConditionalAccessBaseline.ps1 \
  -TenantId "TENANT_ID" \
  -PolicyFolder "../config/conditional-access" \
  -ReplaceExisting \
  -ForceEnable

## Export Essential Eight evidence

pwsh ./scripts/Export-Essential8Evidence.ps1 \
  -TenantId "TENANT_ID" \
  -OutputFolder "../out"

The script exports:

- Intune configuration policies.
- Conditional Access policies.
- Managed device compliance inventory.
- Last 7 days of sign-in logs.
- Summary metrics file.

## Break-glass hardening and monitoring

Use this script after tenant bootstrap to restrict break-glass sign-ins to a trusted location and capture sign-in activity:

pwsh ./scripts/Invoke-BreakGlassPostBootstrapHardening.ps1 \
  -TenantId "TENANT_ID" \
  -BreakGlassGroupName "Security-BreakGlass-Accounts" \
  -TrustedLocationName "Trusted Corporate IPs" \
  -ReplaceExisting \
  -SignInLookbackDays 30 \
  -OutputFolder "../out"

If there is no trusted IP or named location, use the fallback policy instead:

pwsh ./scripts/Invoke-BreakGlassPostBootstrapHardening.ps1 \
  -TenantId "TENANT_ID" \
  -BreakGlassGroupName "Security-BreakGlass-Accounts" \
  -SkipTrustedLocation \
  -ReplaceExisting \
  -OutputFolder "../out"

Use report-only for validation:

pwsh ./scripts/Invoke-BreakGlassPostBootstrapHardening.ps1 \
  -TenantId "TENANT_ID" \
  -BreakGlassGroupName "Security-BreakGlass-Accounts" \
  -SkipTrustedLocation \
  -ReportOnly \
  -ReplaceExisting \
  -OutputFolder "../out"

## Autopilot CSV columns expected

- Device Serial Number
- Hardware Hash
- Group Tag (optional)
- Windows Product ID (optional)
- Assigned User Principal Name (optional)

## Suggested rollout sequence

1. Deploy to pilot groups first.
2. Validate compliance and Defender telemetry.
3. Promote to production assignment.
4. Enforce block-mode controls after pilot validation.

## Operational checks

- Intune policy assignment status.
- Device compliance trends.
- Defender exposure score and incident trend.
- Conditional Access sign-in success and block events.

## Security notes

- Prefer managed identity for unattended execution contexts.
- Store automation credentials in Azure Key Vault if app-based auth is used.
- Keep scripts and policy JSON in source control with pull request review.
