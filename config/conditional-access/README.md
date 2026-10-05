# Conditional Access Policy Input Format

This folder stores Microsoft Entra Conditional Access policy definitions used by scripts/Deploy-ConditionalAccessBaseline.ps1.

## Required properties

- displayName
- state
  - enabled
  - disabled
  - enabledForReportingButNotEnforced
- conditions
- grantControls

## Optional properties

- sessionControls

## Workflow

1. Build policy in report-only mode first.
2. Export from Microsoft Graph /beta/identity/conditionalAccess/policies/{id}.
3. Remove read-only fields if present.
4. Save one policy per JSON file in this folder.
5. Run scripts/Test-ConditionalAccessPolicyPack.ps1 before deployment.

## Hardened policy set

- Place stricter variants under config/conditional-access/hardened.
- Deploy hardened set by running scripts/Deploy-ConditionalAccessBaseline.ps1 with -PolicyFolder "../config/conditional-access/hardened".

## Placeholder safety

- scripts/Deploy-ConditionalAccessBaseline.ps1 blocks unresolved REPLACE_WITH_ placeholders by default.
- Override only for controlled testing with -AllowPlaceholders.

## Naming suggestions

- E8 - CA - Require MFA - All Users
- E8 - CA - Require Compliant Device - M365
- E8 - CA - Block Legacy Auth
- E8 - CA - Require Phishing Resistant MFA - Admins
