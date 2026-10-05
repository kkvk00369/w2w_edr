# Conditional Access Baseline Setup

This guide explains how to use the four baseline Conditional Access JSON files in config/conditional-access.

## Baseline files

- config/conditional-access/01-ca-require-mfa-all-users.json
- config/conditional-access/02-ca-require-compliant-device-m365.json
- config/conditional-access/03-ca-block-legacy-auth.json
- config/conditional-access/04-ca-phishing-resistant-mfa-admins.json

## Hardened files

- config/conditional-access/hardened/01-ca-require-mfa-all-users-hardened.json
- config/conditional-access/hardened/02-ca-require-compliant-device-m365-hardened.json
- config/conditional-access/hardened/03-ca-block-legacy-auth-hardened.json
- config/conditional-access/hardened/04-ca-phishing-resistant-mfa-admins-hardened.json

## Required pre-deployment customization

1. Replace REPLACE_WITH_BREAK_GLASS_OBJECT_ID_1 with your emergency access account object id.
2. In the phishing-resistant policy, replace REPLACE_WITH_PHISHING_RESISTANT_AUTH_STRENGTH_ID with your tenant authentication strength id.
3. Validate privileged role template ids align to your admin model.

## Get tenant reference IDs

Run:

pwsh ./scripts/Get-ConditionalAccessReferenceData.ps1 \
  -TenantId "TENANT_ID" \
  -OutputFolder "../out"

Then open the generated JSON and copy:

- authenticationStrengthPolicies[].id and displayName
- namedLocations[].id and displayName
- activeDirectoryRoles[] entries

Generate a tenant checklist from the export:

pwsh ./scripts/New-ConditionalAccessTenantChecklist.ps1 \
  -ReferenceDataPath "../out/ca-reference-data-YYYYMMDD-HHMMSS.json" \
  -OutputFolder "../out"

The checklist output includes:

- placeholder to file mapping
- recommended phishing-resistant authentication strength id
- named location id options
- deployment command sequence

Generate tenant-ready CA files from placeholders:

pwsh ./scripts/Set-ConditionalAccessTenantValues.ps1 \
  -TenantFoundationFile "../out/tenant-foundation-YYYYMMDD-HHMMSS.json" \
  -ReferenceDataFile "../out/ca-reference-data-YYYYMMDD-HHMMSS.json" \
  -PolicyFolder "../config/conditional-access" \
  -OutputFolder "../generated/conditional-access"

## Validate policy pack before deployment

Baseline only:

pwsh ./scripts/Test-ConditionalAccessPolicyPack.ps1 \
  -PolicyFolder "../generated/conditional-access"

Include hardened pack:

pwsh ./scripts/Test-ConditionalAccessPolicyPack.ps1 \
  -PolicyFolder "../generated/conditional-access" \
  -IncludeHardened

Template-only validation (placeholders still present):

pwsh ./scripts/Test-ConditionalAccessPolicyPack.ps1 \
  -PolicyFolder "../config/conditional-access" \
  -IncludeHardened \
  -AllowPlaceholders

## Recommended rollout

1. Keep all policy files in enabledForReportingButNotEnforced state first.
2. Deploy with scripts/Deploy-ConditionalAccessBaseline.ps1 using -ReplaceExisting.
3. Review sign-in impact and exclusions.
4. Move to enforcement by changing file state to enabled or using -ForceEnable.

The deployment script blocks unresolved placeholders by default.

## Validation checks

- No lockout observed for break-glass account.
- Legacy authentication attempts are blocked.
- Admin sign-ins satisfy phishing-resistant requirements.
- Non-compliant devices blocked from Microsoft 365 resources as expected.
