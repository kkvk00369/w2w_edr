[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ReferenceDataPath,

    [Parameter()]
    [string]$OutputFolder = "../out",

    [Parameter()]
    [string]$PolicyFolder = "../config/conditional-access",

    [Parameter()]
    [string]$PhishingResistantAuthStrengthName = "Phishing-resistant MFA"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-PathFromScriptRoot {
    param([string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    $scriptRoot = Split-Path -Parent $PSCommandPath
    return (Join-Path $scriptRoot $Path)
}

function Get-PolicyFiles {
    param([string]$BaseFolder)

    $files = @()
    if (Test-Path -Path $BaseFolder) {
        $files += Get-ChildItem -Path $BaseFolder -Filter "*.json" -File
    }

    $hardened = Join-Path $BaseFolder "hardened"
    if (Test-Path -Path $hardened) {
        $files += Get-ChildItem -Path $hardened -Filter "*.json" -File
    }

    return $files | Sort-Object FullName
}

function Get-PlaceholderSummary {
    param([string[]]$FilePaths)

    $placeholderMap = [ordered]@{}

    foreach ($filePath in $FilePaths) {
        $raw = Get-Content -Path $filePath -Raw
        $matches = [regex]::Matches($raw, "REPLACE_WITH_[A-Z0-9_]+")
        foreach ($match in $matches) {
            $key = $match.Value
            if (-not $placeholderMap.Contains($key)) {
                $placeholderMap[$key] = New-Object System.Collections.Generic.List[string]
            }
            [void]$placeholderMap[$key].Add($filePath)
        }
    }

    return $placeholderMap
}

$resolvedReferenceDataPath = Resolve-PathFromScriptRoot -Path $ReferenceDataPath
if (-not (Test-Path -Path $resolvedReferenceDataPath)) {
    throw "Reference data file not found: $resolvedReferenceDataPath"
}

$resolvedOutputFolder = Resolve-PathFromScriptRoot -Path $OutputFolder
if (-not (Test-Path -Path $resolvedOutputFolder)) {
    New-Item -ItemType Directory -Path $resolvedOutputFolder -Force | Out-Null
}

$resolvedPolicyFolder = Resolve-PathFromScriptRoot -Path $PolicyFolder
if (-not (Test-Path -Path $resolvedPolicyFolder)) {
    throw "Policy folder not found: $resolvedPolicyFolder"
}

$referenceData = Get-Content -Path $resolvedReferenceDataPath -Raw | ConvertFrom-Json
$policyFiles = Get-PolicyFiles -BaseFolder $resolvedPolicyFolder
$placeholderSummary = Get-PlaceholderSummary -FilePaths $policyFiles.FullName

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$checklistPath = Join-Path $resolvedOutputFolder "ca-tenant-checklist-$timestamp.md"

$authStrengths = @($referenceData.authenticationStrengthPolicies)
$namedLocations = @($referenceData.namedLocations)
$roles = @($referenceData.activeDirectoryRoles)

$recommendedAuthStrength = $authStrengths |
    Where-Object { $_.displayName -like "*$PhishingResistantAuthStrengthName*" } |
    Select-Object -First 1

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# Conditional Access Tenant Checklist")
$lines.Add("")
$lines.Add("Generated: $((Get-Date).ToUniversalTime().ToString('u'))")
$lines.Add("Reference data source: $resolvedReferenceDataPath")
$lines.Add("")
$lines.Add("## 1. Placeholder Replacement Plan")
$lines.Add("")

if ($placeholderSummary.Count -eq 0) {
    $lines.Add("No placeholders were found in policy files.")
}
else {
    foreach ($placeholder in $placeholderSummary.Keys) {
        $lines.Add("- [ ] $placeholder")
        foreach ($path in ($placeholderSummary[$placeholder] | Sort-Object -Unique)) {
            $relative = $path
            if ($path.StartsWith($resolvedPolicyFolder)) {
                $relative = $path.Substring($resolvedPolicyFolder.Length).TrimStart('/', '\\')
                $relative = "config/conditional-access/$relative"
            }
            $lines.Add("  - used in: $relative")
        }
    }
}

$lines.Add("")
$lines.Add("## 2. Candidate Authentication Strength")
$lines.Add("")
if ($null -ne $recommendedAuthStrength) {
    $lines.Add("Recommended for REPLACE_WITH_PHISHING_RESISTANT_AUTH_STRENGTH_ID:")
    $lines.Add("- id: $($recommendedAuthStrength.id)")
    $lines.Add("- displayName: $($recommendedAuthStrength.displayName)")
}
else {
    $lines.Add("No authentication strength matched '$PhishingResistantAuthStrengthName'.")
    $lines.Add("Select from table below and copy id manually.")
}

$lines.Add("")
$lines.Add("Available authentication strengths:")
$lines.Add("")
$lines.Add("| displayName | id |")
$lines.Add("|---|---|")
foreach ($item in $authStrengths | Sort-Object displayName) {
    $lines.Add("| $($item.displayName) | $($item.id) |")
}

$lines.Add("")
$lines.Add("## 3. Candidate Trusted Named Locations")
$lines.Add("")
$lines.Add("Choose location id(s) for REPLACE_WITH_TRUSTED_LOCATION_ID_1:")
$lines.Add("")
$lines.Add("| displayName | id |")
$lines.Add("|---|---|")
foreach ($item in $namedLocations | Sort-Object displayName) {
    $lines.Add("| $($item.displayName) | $($item.id) |")
}

$lines.Add("")
$lines.Add("## 4. Break-Glass Account Input")
$lines.Add("")
$lines.Add("Set REPLACE_WITH_BREAK_GLASS_OBJECT_ID_1 to your emergency account object id.")
$lines.Add("Verify that account is excluded in all CA baseline and hardened policies.")

$lines.Add("")
$lines.Add("## 5. Role Visibility Check")
$lines.Add("")
$lines.Add("Active directory roles detected in tenant:")
$lines.Add("")
$lines.Add("| displayName | roleTemplateId |")
$lines.Add("|---|---|")
foreach ($role in $roles | Sort-Object displayName) {
    $lines.Add("| $($role.displayName) | $($role.roleTemplateId) |")
}

$lines.Add("")
$lines.Add("## 6. Validate and Deploy")
$lines.Add("")
$lines.Add("1. Update all placeholders in policy JSON files.")
$lines.Add("2. Validate:")
$lines.Add("   pwsh ./scripts/Test-ConditionalAccessPolicyPack.ps1 -PolicyFolder \"../config/conditional-access\" -IncludeHardened")
$lines.Add("3. Deploy baseline:")
$lines.Add("   pwsh ./scripts/Deploy-ConditionalAccessBaseline.ps1 -TenantId \"TENANT_ID\" -PolicyFolder \"../config/conditional-access\" -ReplaceExisting")
$lines.Add("4. Deploy hardened:")
$lines.Add("   pwsh ./scripts/Deploy-ConditionalAccessBaseline.ps1 -TenantId \"TENANT_ID\" -PolicyFolder \"../config/conditional-access/hardened\" -ReplaceExisting")
$lines.Add("5. Enforce after report-only validation:")
$lines.Add("   pwsh ./scripts/Deploy-ConditionalAccessBaseline.ps1 -TenantId \"TENANT_ID\" -PolicyFolder \"../config/conditional-access/hardened\" -ReplaceExisting -ForceEnable")

Set-Content -Path $checklistPath -Value ($lines -join [Environment]::NewLine) -Encoding utf8
Write-Host "Tenant checklist generated: $checklistPath" -ForegroundColor Green
