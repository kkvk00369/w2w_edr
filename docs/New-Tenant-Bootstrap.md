# New Tenant Bootstrap

Use this workflow to prepare a brand new tenant for Essential Eight endpoint and identity controls.

## Fast path (recommended)

Run full automation in one command:

pwsh ./scripts/Invoke-NewTenantEssential8Bootstrap.ps1 \
  -TenantId "TENANT_ID" \
  -TrustedIpCidrs "203.0.113.0/24","198.51.100.0/24" \
  -DeployConditionalAccessPolicies \
  -ExportEvidence

Notes:

- Add -EnforcePolicies only after report-only validation is complete.
- Add -DeployIntunePolicies to include Intune policy deployment.
- Add -RunDeviceOnboarding to ensure dynamic onboarding group is present.

## What this bootstrap sets up

- Break-glass accounts (default: 2 cloud-only emergency accounts).
- Baseline Entra security groups:
  - Intune-Windows-Pilot
  - Intune-Windows-Production
  - Intune-Windows-Exclusions
  - Security-BreakGlass-Accounts
- Break-glass group and exclusion group membership.
- Directory role assignment for emergency accounts (default: Global Administrator).
- Optional trusted named location for hardened Conditional Access policies.
- Output artifact with object IDs for downstream automation.

## 1) Initialize tenant foundation

If the tenant has a corporate trusted IP list:

pwsh ./scripts/Initialize-NewTenantSecurityFoundation.ps1 \
  -TenantId "TENANT_ID" \
  -CreateTrustedNamedLocation \
  -TrustedNamedLocationName "Trusted Corporate IPs" \
  -TrustedIpCidrs "203.0.113.0/24","198.51.100.0/24" \
  -OutputFolder "../out"

If there is no trusted IP range or named location available, skip the trusted location and rely on the fallback break-glass policy instead:

pwsh ./scripts/Initialize-NewTenantSecurityFoundation.ps1 \
  -TenantId "TENANT_ID" \
  -SkipTrustedNamedLocation \
  -OutputFolder "../out"

Output file example:

- out/tenant-foundation-YYYYMMDD-HHMMSS.json

## 2) Collect Conditional Access reference data

pwsh ./scripts/Get-ConditionalAccessReferenceData.ps1 \
  -TenantId "TENANT_ID" \
  -OutputFolder "../out"

Output file example:

- out/ca-reference-data-YYYYMMDD-HHMMSS.json

## 3) Generate tenant-ready policy files

pwsh ./scripts/Set-ConditionalAccessTenantValues.ps1 \
  -TenantFoundationFile "../out/tenant-foundation-YYYYMMDD-HHMMSS.json" \
  -ReferenceDataFile "../out/ca-reference-data-YYYYMMDD-HHMMSS.json" \
  -PolicyFolder "../config/conditional-access" \
  -OutputFolder "../generated/conditional-access"

This command writes updated policy JSON files with known placeholder values replaced.

## 4) Validate generated policy files

pwsh ./scripts/Test-ConditionalAccessPolicyPack.ps1 \
  -PolicyFolder "../generated/conditional-access" \
  -IncludeHardened

## 5) Deploy from generated folder

Baseline deployment:

pwsh ./scripts/Deploy-ConditionalAccessBaseline.ps1 \
  -TenantId "TENANT_ID" \
  -PolicyFolder "../generated/conditional-access" \
  -ReplaceExisting

Hardened deployment:

pwsh ./scripts/Deploy-ConditionalAccessBaseline.ps1 \
  -TenantId "TENANT_ID" \
  -PolicyFolder "../generated/conditional-access/hardened" \
  -ReplaceExisting

## 6) Apply break-glass post-bootstrap hardening

Create or update dedicated break-glass CA restriction policy and export sign-in report:

pwsh ./scripts/Invoke-BreakGlassPostBootstrapHardening.ps1 \
  -TenantId "TENANT_ID" \
  -BreakGlassGroupName "Security-BreakGlass-Accounts" \
  -TrustedLocationName "Trusted Corporate IPs" \
  -ReplaceExisting \
  -SignInLookbackDays 30 \
  -OutputFolder "../out"

For report-only validation mode before enforcement:

pwsh ./scripts/Invoke-BreakGlassPostBootstrapHardening.ps1 \
  -TenantId "TENANT_ID" \
  -BreakGlassGroupName "Security-BreakGlass-Accounts" \
  -TrustedLocationName "Trusted Corporate IPs" \
  -ReportOnly \
  -ReplaceExisting \
  -OutputFolder "../out"

## Security operations notes

- Store break-glass credentials in a secure privileged vault immediately.
- Test emergency access account sign-in after CA deployment.
- Restrict use of emergency accounts to incident response only.
- Rotate emergency credentials periodically and after every use.
- Run break-glass hardening script daily to capture sign-in activity snapshots.
