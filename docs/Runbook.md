# Essential Eight Automation Runbook

This runbook gives the operational sequence for baseline deployment and recurring evidence collection.

## Phase 0: Bootstrap new tenant foundation

Optional fast path (single orchestrator):

pwsh ./scripts/Invoke-NewTenantEssential8Bootstrap.ps1 \
  -TenantId "TENANT_ID" \
  -TrustedIpCidrs "203.0.113.0/24","198.51.100.0/24" \
  -DeployConditionalAccessPolicies \
  -ExportEvidence

Run once per tenant:

pwsh ./scripts/Initialize-NewTenantSecurityFoundation.ps1 \
  -TenantId "TENANT_ID" \
  -CreateTrustedNamedLocation \
  -TrustedNamedLocationName "Trusted Corporate IPs" \
  -TrustedIpCidrs "203.0.113.0/24","198.51.100.0/24" \
  -OutputFolder "../out"

Then use the generated foundation file together with CA reference data to build tenant-ready policy files:

pwsh ./scripts/Set-ConditionalAccessTenantValues.ps1 \
  -TenantFoundationFile "../out/tenant-foundation-YYYYMMDD-HHMMSS.json" \
  -ReferenceDataFile "../out/ca-reference-data-YYYYMMDD-HHMMSS.json" \
  -PolicyFolder "../config/conditional-access" \
  -OutputFolder "../generated/conditional-access"

## Phase 1: Prepare tenant inputs

1. Create pilot, production, and exclusion Entra groups.
2. Export and curate Intune policy JSON files into config/policies.
3. Export and curate Conditional Access JSON files into config/conditional-access.
4. Keep all JSON under change control.
5. Follow docs/ConditionalAccess-Baseline-Setup.md to replace required CA placeholders.
6. Before a pull request is merged, run the repository validation workflow or the equivalent local commands below to confirm the source policy pack is still structurally valid.

### Repository validation workflow

The repo includes a GitHub Actions workflow at .github/workflows/validate-security-automation.yml.

- It runs automatically for pull requests that touch scripts, policy definitions, docs, or README.
- It checks PowerShell syntax and CA policy integrity.
- It allows placeholders for source templates, but still rejects malformed JSON and invalid required values.

Local validation equivalent:

```pwsh
pwsh ./scripts/Test-ConditionalAccessPolicyPack.ps1 \
  -PolicyFolder "./config/conditional-access" \
  -IncludeHardened \
  -AllowPlaceholders
```

PowerShell syntax validation:

```pwsh
pwsh -NoLogo -NoProfile -Command '$hadErr=$false; Get-ChildItem ./scripts/*.ps1 | ForEach-Object { $tokens=$null; $errs=$null; [void][System.Management.Automation.Language.Parser]::ParseFile($_.FullName,[ref]$tokens,[ref]$errs); if($errs.Count -gt 0){ $hadErr=$true; Write-Host "Syntax errors in $($_.Name):"; $errs | ForEach-Object { Write-Host " - $($_.Message)" } } else { Write-Host "OK: $($_.Name)" } }; if($hadErr){ exit 1 }'
```

Collect tenant CA reference IDs:

pwsh ./scripts/Get-ConditionalAccessReferenceData.ps1 \
  -TenantId "TENANT_ID" \
  -OutputFolder "../out"

Generate tenant checklist:

pwsh ./scripts/New-ConditionalAccessTenantChecklist.ps1 \
  -ReferenceDataPath "../out/ca-reference-data-YYYYMMDD-HHMMSS.json" \
  -OutputFolder "../out"

Validate CA files before deployment:

pwsh ./scripts/Test-ConditionalAccessPolicyPack.ps1 \
  -PolicyFolder "../generated/conditional-access" \
  -IncludeHardened

## Phase 2: Onboard devices

Run:

pwsh ./scripts/Invoke-DeviceOnboarding.ps1 \
  -TenantId "TENANT_ID" \
  -DynamicGroupName "Intune-Windows-EntraJoined-All" \
  -AutopilotCsvPath "./autopilot-import.csv"

Optional current-fleet sync:

pwsh ./scripts/Invoke-DeviceOnboarding.ps1 \
  -TenantId "TENANT_ID" \
  -TriggerSyncForCurrentWindowsDevices \
  -SyncBatchSize 200

## Phase 3: Deploy Intune Essential Eight policies

Run:

pwsh ./scripts/Deploy-IntuneEssential8Policies.ps1 \
  -TenantId "TENANT_ID" \
  -PilotGroupId "PILOT_GROUP_ID" \
  -ProductionGroupId "PRODUCTION_GROUP_ID" \
  -ExcludeGroupId "EXCLUDE_GROUP_ID" \
  -ReplaceExisting

## Phase 4: Deploy Conditional Access baseline

Start in report-only, then enforce.

Report-only or mixed-state rollout:

pwsh ./scripts/Deploy-ConditionalAccessBaseline.ps1 \
  -TenantId "TENANT_ID" \
  -PolicyFolder "../generated/conditional-access" \
  -ReplaceExisting

Hardened policy rollout:

pwsh ./scripts/Deploy-ConditionalAccessBaseline.ps1 \
  -TenantId "TENANT_ID" \
  -PolicyFolder "../generated/conditional-access/hardened" \
  -ReplaceExisting

Force enforcement after validation:

pwsh ./scripts/Deploy-ConditionalAccessBaseline.ps1 \
  -TenantId "TENANT_ID" \
  -PolicyFolder "../generated/conditional-access" \
  -ReplaceExisting \
  -ForceEnable

## Phase 5: Export compliance evidence

Run:

pwsh ./scripts/Export-Essential8Evidence.ps1 \
  -TenantId "TENANT_ID" \
  -OutputFolder "../out"

Artifacts are written to timestamped subfolders under out.

## Phase 6: Break-glass hardening and monitoring

Run:

pwsh ./scripts/Invoke-BreakGlassPostBootstrapHardening.ps1 \
  -TenantId "TENANT_ID" \
  -BreakGlassGroupName "Security-BreakGlass-Accounts" \
  -TrustedLocationName "Trusted Corporate IPs" \
  -ReplaceExisting \
  -SignInLookbackDays 30 \
  -OutputFolder "../out"

Use report-only mode before enforcing:

pwsh ./scripts/Invoke-BreakGlassPostBootstrapHardening.ps1 \
  -TenantId "TENANT_ID" \
  -BreakGlassGroupName "Security-BreakGlass-Accounts" \
  -TrustedLocationName "Trusted Corporate IPs" \
  -ReportOnly \
  -ReplaceExisting \
  -OutputFolder "../out"

## Recurring operations

- Weekly: run evidence export and review non-compliant devices.
- Monthly: review policy drift and update baselines.
- Quarterly: run restore and incident simulation exercises.

## Guardrails

- Keep break-glass accounts excluded from broad CA policies.
- Deploy new controls to pilot group first.
- Document each policy exception with owner and expiry.
