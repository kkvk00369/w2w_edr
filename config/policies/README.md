# Intune Policy Input Format

This folder stores Intune policy JSON files used by automation in scripts/Deploy-IntuneEssential8Policies.ps1.

## Recommended source

1. Build and validate each policy in a pilot tenant using Intune admin center.
2. Export policies from Microsoft Graph endpoint:
   - GET /beta/deviceManagement/configurationPolicies/{policyId}?$expand=settings
3. Save each policy export as one JSON file in this folder.

## Required properties in each file

- name
- platforms
- technologies
- settings

Optional properties:

- description
- deployment
  - pilot
  - production
  - both

## Notes

- The deployment script removes read-only fields before POST.
- Keep one policy per file for safer change control.
- Use naming convention like:
  - E8 - Application Control - WDAC
  - E8 - Macro Controls - Office
  - E8 - User Hardening - ASR
  - E8 - Update Rings - Pilot
