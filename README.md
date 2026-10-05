# Windows Intune + Defender Essential Eight Automation

This repository contains starter automation for:

- Deploying Intune policies as code for Essential Eight controls.
- Onboarding current and future Entra ID joined Windows devices.
- Deploying Conditional Access baseline policies as code.
- Exporting compliance and audit evidence.
- Bootstrapping new tenants with break-glass accounts and identity foundations.
- Applying post-bootstrap break-glass hardening and sign-in monitoring.

## Start here

- docs/Implementation-Guide.md

## Folder structure

- scripts
  - Create-TenantSecurityGroups.ps1
  - Deploy-IntuneEssential8Policies.ps1
  - Invoke-DeviceOnboarding.ps1
  - Deploy-ConditionalAccessBaseline.ps1
  - Export-Essential8Evidence.ps1
  - Get-ConditionalAccessReferenceData.ps1
  - Test-ConditionalAccessPolicyPack.ps1
  - New-ConditionalAccessTenantChecklist.ps1
  - Initialize-NewTenantSecurityFoundation.ps1
  - Set-ConditionalAccessTenantValues.ps1
  - Invoke-BreakGlassPostBootstrapHardening.ps1
  - Invoke-NewTenantEssential8Bootstrap.ps1
  - Collect-LocalDeviceOnboardingDetails.ps1
  - Deploy-LocalDeviceOnboardingCollectorToIntune.ps1
- config/policies
  - README.md
- config/conditional-access
  - README.md
  - hardened/
- docs
  - Implementation-Guide.md
  - Essential8-Policy-Mapping.md
  - ConditionalAccess-Baseline-Setup.md
  - New-Tenant-Bootstrap.md
  - Runbook.md

## Step-by-step usage

This repo is designed to be used in order, from tenant preparation through policy rollout and endpoint onboarding.

### 1) Create the tenant foundation, groups, and break-glass accounts

Run once for a new tenant to create the required groups and emergency access accounts:

```pwsh
pwsh ./scripts/Initialize-NewTenantSecurityFoundation.ps1 \
  -TenantId "TENANT_ID" \
  -CreateTrustedNamedLocation \
  -TrustedNamedLocationName "Trusted Corporate IPs" \
  -TrustedIpCidrs "203.0.113.0/24","198.51.100.0/24" \
  -OutputFolder "../out"
```

If the tenant has no trusted IP or named location, use:

```pwsh
pwsh ./scripts/Initialize-NewTenantSecurityFoundation.ps1 \
  -TenantId "TENANT_ID" \
  -SkipTrustedNamedLocation \
  -OutputFolder "../out"
```

If you only want the baseline groups and optional break-glass accounts without the full new-tenant orchestration, use:

```pwsh
pwsh ./scripts/Create-TenantSecurityGroups.ps1 \
  -TenantId "TENANT_ID" \
  -CreateBreakGlassAccounts
```

This covers:

- break-glass accounts and role assignments
- production, pilot, and exclusion groups
- tenant foundation output file for downstream automation

### 2) Generate and deploy the baseline Entra ID / Conditional Access policies

Generate the tenant-ready files from placeholders:

```pwsh
pwsh ./scripts/Get-ConditionalAccessReferenceData.ps1 \
  -TenantId "TENANT_ID" \
  -OutputFolder "../out"

pwsh ./scripts/Set-ConditionalAccessTenantValues.ps1 \
  -TenantFoundationFile "../out/tenant-foundation-YYYYMMDD-HHMMSS.json" \
  -ReferenceDataFile "../out/ca-reference-data-YYYYMMDD-HHMMSS.json" \
  -PolicyFolder "../config/conditional-access" \
  -OutputFolder "../generated/conditional-access"
```

Validate before deployment:

```pwsh
pwsh ./scripts/Test-ConditionalAccessPolicyPack.ps1 \
  -PolicyFolder "../generated/conditional-access" \
  -IncludeHardened
```

Deploy the baseline CA pack:

```pwsh
pwsh ./scripts/Deploy-ConditionalAccessBaseline.ps1 \
  -TenantId "TENANT_ID" \
  -PolicyFolder "../generated/conditional-access/hardened" \
  -ReplaceExisting
```

This covers:

- MFA requirements
- compliant-device enforcement
- legacy auth blocking
- phishing-resistant MFA for admin access
- conditional access baseline hardening

### 3) Deploy the baseline Intune policy set

The repo expects policy JSON files under config/policies and deploys them to pilot and production groups from naming and metadata.

```pwsh
pwsh ./scripts/Deploy-IntuneEssential8Policies.ps1 \
  -TenantId "TENANT_ID" \
  -PilotGroupId "PILOT_GROUP_ID" \
  -ProductionGroupId "PRODUCTION_GROUP_ID" \
  -ExcludeGroupId "EXCLUDE_GROUP_ID" \
  -PolicyFolder "../config/policies" \
  -ReplaceExisting
```

This covers the policy classes for:

- application control
- user hardening
- macro restrictions
- OS patching / Windows Update rings
- endpoint protection and security baselines

### 4) Onboard Entra ID joined Windows devices to Intune

Ensure the dynamic onboarding group exists and optionally import Autopilot hashes:

```pwsh
pwsh ./scripts/Invoke-DeviceOnboarding.ps1 \
  -TenantId "TENANT_ID" \
  -DynamicGroupName "Intune-Windows-EntraJoined-All" \
  -AutopilotCsvPath "./samples/autopilot-import-sample.csv"
```

Trigger a sync for existing devices if already enrolled:

```pwsh
pwsh ./scripts/Invoke-DeviceOnboarding.ps1 \
  -TenantId "TENANT_ID" \
  -TriggerSyncForCurrentWindowsDevices \
  -SyncBatchSize 200
```

This covers:

- current device onboarding
- future device onboarding
- Autopilot import flow
- Intune membership targeting for policy assignment

If you need to collect required onboarding details directly from each Windows endpoint (serial number, hardware hash, join state), run locally on each device:

```pwsh
pwsh ./scripts/Collect-LocalDeviceOnboardingDetails.ps1 \
  -OutputFolder "./out" \
  -AppendAutopilotCsvPath "./out/autopilot-import.csv" \
  -GroupTag "Production" \
  -AssignedUserPrincipalName "user@contoso.com"
```

The generated CSV can be used with Invoke-DeviceOnboarding.ps1 and the Autopilot import flow.

For scale, deploy the local collection script through Intune to a target device group:

```pwsh
pwsh ./scripts/Deploy-LocalDeviceOnboardingCollectorToIntune.ps1 \
  -TenantId "TENANT_ID" \
  -TargetGroupId "DEVICE_GROUP_ID" \
  -ResultWebhookUrl "https://YOUR_LOGICAPP_OR_FUNCTION_ENDPOINT" \
  -ReplaceExisting
```

### 5) Enable Essential Eight security features

Use the repo in combination with the policy pack and conditional access templates to enable:

- Microsoft Defender for Endpoint and device compliance baselines
- phishing-resistant MFA and admin protection
- application and browser hardening
- macro restrictions and ASR controls
- patch enforcement for Windows and Microsoft 365 apps

The repo provides the automation scaffolding and the policy templates; final hardening should be validated in report-only mode before enforcement.

### 6) Auto-apply Windows Updates

Use the Intune update ring policy files and the pilot/production deployment model to automatically apply updates while controlling deferral:

- apply a pilot update ring to the pilot group first
- validate compliance and patch reports
- promote the production ring to the production group
- use feature update and quality update deferral settings to enforce consistent patching

Example flow:

```pwsh
pwsh ./scripts/Deploy-IntuneEssential8Policies.ps1 \
  -TenantId "TENANT_ID" \
  -PilotGroupId "PILOT_GROUP_ID" \
  -ProductionGroupId "PRODUCTION_GROUP_ID" \
  -ExcludeGroupId "EXCLUDE_GROUP_ID" \
  -PolicyFolder "../config/policies" \
  -ReplaceExisting
```

This is how the repo enforces a repeatable Windows Update auto-apply model for managed devices.

### 7) Run the full bootstrap workflow

Run end-to-end workflow for a new tenant:

```pwsh
pwsh ./scripts/Invoke-NewTenantEssential8Bootstrap.ps1 \
  -TenantId "TENANT_ID" \
  -TrustedIpCidrs "203.0.113.0/24","198.51.100.0/24" \
  -DeployConditionalAccessPolicies \
  -ExportEvidence
```

## No trusted IP or named-location fallback

If the tenant does not have a corporate trusted IP range or named location, skip location-based CA blocking and use the fallback break-glass policy instead.

```pwsh
pwsh ./scripts/Invoke-NewTenantEssential8Bootstrap.ps1 \
  -TenantId "TENANT_ID" \
  -SkipTrustedLocation \
  -DeployConditionalAccessPolicies \
  -ExportEvidence
```

This leaves the trusted-location path available when it exists, but will fall back to a compliant-device and phishing-resistant MFA policy for the emergency access group when no named location is available.

## Device onboarding checklist

Use the onboarding script to ensure Entra ID joined Windows devices are placed in the correct Intune group and optionally imported via Autopilot:

1. Confirm the tenant is enabled for Intune and Entra ID joined Windows devices.
2. Run the onboarding script to create or reuse the dynamic device group.
3. Add an Autopilot CSV if you want to import devices in bulk.
4. Trigger a sync for already-enrolled Windows devices if needed.
5. Assign the required Intune policies to the dynamic group.

Sample Autopilot CSV:

- samples/autopilot-import-sample.csv

Example:

```pwsh
pwsh ./scripts/Invoke-DeviceOnboarding.ps1 \
  -TenantId "TENANT_ID" \
  -DynamicGroupName "Intune-Windows-EntraJoined-All" \
  -AutopilotCsvPath "./samples/autopilot-import-sample.csv" \
  -TriggerSyncForCurrentWindowsDevices \
  -SyncBatchSize 200
```

## GitHub Actions workflow setup and usage

CI validation is defined in:

- .github/workflows/validate-security-automation.yml

### What it does

The workflow runs on pull requests and manual dispatch. It is path-scoped to only trigger for changes in:

- .github/workflows/validate-security-automation.yml
- scripts/**
- config/conditional-access/**
- docs/**
- README.md

It validates:

- PowerShell syntax for every script under scripts/.
- Conditional Access template integrity for the source policy pack, including hardened templates.
- Placeholder-safe validation for template files while allowing intentional REPLACE_WITH_* entries in source-controlled policy definitions.

### How to set it up in GitHub

1. Push the repository to GitHub.
2. In the repository, open Settings > Actions > General.
3. Confirm Actions are enabled.
4. If required by your org, allow GitHub Actions to read repository contents and run workflows.
5. Ensure the default branch is protected if you want PRs to block on this validation job.

### How to use it

- Create a pull request that changes any of the tracked files above.
- The workflow runs automatically.
- If a script has PowerShell syntax errors, or a policy file is malformed, the workflow fails and blocks merge until fixed.
- For template repositories, use -AllowPlaceholders in the validator when you intentionally keep placeholder values in source templates.

### Local validation before pushing

Template policy validation with placeholders still allowed:

```pwsh
pwsh ./scripts/Test-ConditionalAccessPolicyPack.ps1 \
  -PolicyFolder "./config/conditional-access" \
  -IncludeHardened \
  -AllowPlaceholders
```

Strict validation for generated tenant-ready output without placeholders:

```pwsh
pwsh ./scripts/Test-ConditionalAccessPolicyPack.ps1 \
  -PolicyFolder "./generated/conditional-access" \
  -IncludeHardened
```

PowerShell syntax check across all scripts:

```pwsh
pwsh -NoLogo -NoProfile -Command '$hadErr = $false; Get-ChildItem ./scripts/*.ps1 | ForEach-Object { $tokens = $null; $errs = $null; [void][System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$errs); if ($errs.Count -gt 0) { $hadErr = $true; Write-Host "Syntax errors in $($_.Name):"; $errs | ForEach-Object { Write-Host " - $($_.Message)" } } else { Write-Host "OK: $($_.Name)" } }; if ($hadErr) { exit 1 }'
```
