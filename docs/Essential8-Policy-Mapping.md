# Essential Eight to Intune Policy Mapping

Use this mapping to create one or more JSON policy files per control in config/policies.

## 1) Application Control

Suggested Intune artifacts:
- App Control for Business (WDAC) policy.
- Defender SmartScreen policy.
- ASR rules blocking suspicious executable paths.

Policy name examples:
- E8 - Application Control - WDAC - Pilot
- E8 - Application Control - SmartScreen

## 2) Patch Applications

Suggested Intune artifacts:
- Microsoft 365 Apps update channel policy.
- Third-party app update ring strategy via packaging lifecycle.

Policy name examples:
- E8 - App Patching - M365 Apps
- E8 - App Patching - Third Party Baseline

## 3) Office Macro Settings

Suggested Intune artifacts:
- Block macros from internet.
- Only allow signed macros where justified.

Policy name examples:
- E8 - Office Macro - Block Internet Macros
- E8 - Office Macro - Signed Only Exception Baseline

## 4) User Application Hardening

Suggested Intune artifacts:
- Defender ASR block-mode baseline.
- Edge hardening profile.

Policy name examples:
- E8 - User Hardening - ASR
- E8 - User Hardening - Edge Security

## 5) Restrict Administrative Privileges

Suggested Intune artifacts:
- Endpoint Privilege Management policies.
- Windows LAPS settings profile.
- Local user group membership restrictions.

Policy name examples:
- E8 - Privilege Restriction - EPM
- E8 - Privilege Restriction - LAPS

## 6) Patch Operating Systems

Suggested Intune artifacts:
- Windows Update rings: Pilot and Production.
- Feature update profile.
- Expedited update process policy.

Policy name examples:
- E8 - OS Patching - Update Ring - Pilot
- E8 - OS Patching - Update Ring - Production

## 7) Multi-factor Authentication

Suggested Entra artifacts (outside this script):
- Conditional Access requiring MFA.
- Block legacy authentication.
- Authentication strengths for admins.

## 8) Regular Backups

Suggested Microsoft 365 artifacts:
- OneDrive Known Folder Move configuration profile.
- SharePoint/Exchange retention policies.

## Recommended deployment model

- Pilot assignment first using deployment=pilot.
- Promote validated controls to deployment=production or deployment=both.
- Keep break-glass or sensitive device exclusions in ExcludeGroupId.
