[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TenantId,

    [Parameter()]
    [string]$DomainName,

    [Parameter()]
    [string]$OutputFolder = "../out",

    [Parameter()]
    [string]$PolicyTemplateFolder = "../config/conditional-access",

    [Parameter()]
    [string]$GeneratedPolicyFolder = "../generated/conditional-access",

    [Parameter()]
    [string]$BreakGlassPrefix = "breakglass",

    [Parameter()]
    [int]$BreakGlassAccountCount = 2,

    [Parameter()]
    [string[]]$BreakGlassRoleTemplateIds = @(
        "62e90394-69f5-4237-9190-012177145e10"
    ),

    [Parameter()]
    [string]$PilotGroupName = "Intune-Windows-Pilot",

    [Parameter()]
    [string]$ProductionGroupName = "Intune-Windows-Production",

    [Parameter()]
    [string]$ExclusionGroupName = "Intune-Windows-Exclusions",

    [Parameter()]
    [string]$BreakGlassGroupName = "Security-BreakGlass-Accounts",

    [Parameter()]
    [string]$TrustedNamedLocationName = "Trusted Corporate IPs",

    [Parameter()]
    [switch]$SkipTrustedLocation,

    [Parameter()]
    [string[]]$TrustedIpCidrs,

    [Parameter()]
    [string]$PhishingResistantAuthStrengthName = "Phishing-resistant MFA",

    [Parameter()]
    [bool]$UseHardenedPolicies = $true,

    [Parameter()]
    [switch]$DeployConditionalAccessPolicies,

    [Parameter()]
    [switch]$DeployIntunePolicies,

    [Parameter()]
    [switch]$RunDeviceOnboarding,

    [Parameter()]
    [switch]$ExportEvidence,

    [Parameter()]
    [switch]$EnforcePolicies,

    [Parameter()]
    [switch]$UseManagedIdentity
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Section {
    param([string]$Message)
    Write-Host "`n==== $Message ====" -ForegroundColor Cyan
}

function Resolve-PathFromScriptRoot {
    param([string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    $scriptRoot = Split-Path -Parent $PSCommandPath
    return (Join-Path $scriptRoot $Path)
}

function Get-LatestFile {
    param(
        [string]$Folder,
        [string]$Pattern
    )

    $file = Get-ChildItem -Path $Folder -Filter $Pattern -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($null -eq $file) {
        throw "No file found in '$Folder' matching '$Pattern'"
    }

    return $file.FullName
}

function Add-OptionalSwitch {
    param(
        [hashtable]$Table,
        [string]$Name,
        [bool]$Value
    )

    if ($Value) {
        $Table[$Name] = $true
    }
}

$scriptRoot = Split-Path -Parent $PSCommandPath
$resolvedOutputFolder = Resolve-PathFromScriptRoot -Path $OutputFolder
$resolvedPolicyTemplateFolder = Resolve-PathFromScriptRoot -Path $PolicyTemplateFolder
$resolvedGeneratedPolicyFolder = Resolve-PathFromScriptRoot -Path $GeneratedPolicyFolder

if (-not (Test-Path -Path $resolvedOutputFolder)) {
    New-Item -ItemType Directory -Path $resolvedOutputFolder -Force | Out-Null
}

Write-Section "Step 1: Initialize tenant foundation"
$foundationScript = Join-Path $scriptRoot "Initialize-NewTenantSecurityFoundation.ps1"
$foundationParams = @{
    TenantId = $TenantId
    OutputFolder = $OutputFolder
    BreakGlassPrefix = $BreakGlassPrefix
    BreakGlassAccountCount = $BreakGlassAccountCount
    BreakGlassRoleTemplateIds = $BreakGlassRoleTemplateIds
    PilotGroupName = $PilotGroupName
    ProductionGroupName = $ProductionGroupName
    ExclusionGroupName = $ExclusionGroupName
    BreakGlassGroupName = $BreakGlassGroupName
    TrustedNamedLocationName = $TrustedNamedLocationName
}

if ($DomainName) {
    $foundationParams.DomainName = $DomainName
}
if ($TrustedIpCidrs -and $TrustedIpCidrs.Count -gt 0) {
    $foundationParams.CreateTrustedNamedLocation = $true
    $foundationParams.TrustedIpCidrs = $TrustedIpCidrs
}
elseif ($SkipTrustedLocation) {
    $foundationParams.SkipTrustedNamedLocation = $true
}
elseif (-not $TrustedIpCidrs -or $TrustedIpCidrs.Count -eq 0) {
    $foundationParams.SkipTrustedNamedLocation = $true
}
Add-OptionalSwitch -Table $foundationParams -Name "UseManagedIdentity" -Value $UseManagedIdentity

& $foundationScript @foundationParams

$foundationFile = Get-LatestFile -Folder $resolvedOutputFolder -Pattern "tenant-foundation-*.json"
Write-Host "Foundation file: $foundationFile" -ForegroundColor Green

Write-Section "Step 2: Export Conditional Access reference data"
$referenceScript = Join-Path $scriptRoot "Get-ConditionalAccessReferenceData.ps1"
$referenceParams = @{
    TenantId = $TenantId
    OutputFolder = $OutputFolder
}
Add-OptionalSwitch -Table $referenceParams -Name "UseManagedIdentity" -Value $UseManagedIdentity

& $referenceScript @referenceParams

$referenceFile = Get-LatestFile -Folder $resolvedOutputFolder -Pattern "ca-reference-data-*.json"
Write-Host "Reference data file: $referenceFile" -ForegroundColor Green

Write-Section "Step 3: Generate tenant checklist"
$checklistScript = Join-Path $scriptRoot "New-ConditionalAccessTenantChecklist.ps1"
& $checklistScript -ReferenceDataPath $referenceFile -OutputFolder $OutputFolder -PolicyFolder $PolicyTemplateFolder -PhishingResistantAuthStrengthName $PhishingResistantAuthStrengthName

$checklistFile = Get-LatestFile -Folder $resolvedOutputFolder -Pattern "ca-tenant-checklist-*.md"
Write-Host "Checklist file: $checklistFile" -ForegroundColor Green

Write-Section "Step 4: Materialize tenant-ready CA policy files"
$setValuesScript = Join-Path $scriptRoot "Set-ConditionalAccessTenantValues.ps1"
& $setValuesScript -TenantFoundationFile $foundationFile -ReferenceDataFile $referenceFile -PolicyFolder $PolicyTemplateFolder -OutputFolder $GeneratedPolicyFolder -PhishingResistantAuthStrengthName $PhishingResistantAuthStrengthName

Write-Section "Step 5: Validate generated CA policy pack"
$validateScript = Join-Path $scriptRoot "Test-ConditionalAccessPolicyPack.ps1"
& $validateScript -PolicyFolder $GeneratedPolicyFolder -IncludeHardened

$caDeployFolder = $resolvedGeneratedPolicyFolder
if ($UseHardenedPolicies) {
    $caDeployFolder = Join-Path $resolvedGeneratedPolicyFolder "hardened"
}

if ($DeployConditionalAccessPolicies) {
    Write-Section "Step 6: Deploy Conditional Access policies"
    $deployCaScript = Join-Path $scriptRoot "Deploy-ConditionalAccessBaseline.ps1"
    $deployCaParams = @{
        TenantId = $TenantId
        PolicyFolder = $caDeployFolder
        ReplaceExisting = $true
    }
    Add-OptionalSwitch -Table $deployCaParams -Name "UseManagedIdentity" -Value $UseManagedIdentity
    if ($EnforcePolicies) {
        $deployCaParams.ForceEnable = $true
    }

    & $deployCaScript @deployCaParams
}

if ($DeployIntunePolicies) {
    Write-Section "Step 7: Deploy Intune Essential Eight policies"
    $foundation = Get-Content -Path $foundationFile -Raw | ConvertFrom-Json
    $deployIntuneScript = Join-Path $scriptRoot "Deploy-IntuneEssential8Policies.ps1"

    $deployIntuneParams = @{
        TenantId = $TenantId
        PilotGroupId = $foundation.groups.pilot.id
        ProductionGroupId = $foundation.groups.production.id
        ExcludeGroupId = $foundation.groups.exclusion.id
        ReplaceExisting = $true
    }
    Add-OptionalSwitch -Table $deployIntuneParams -Name "UseManagedIdentity" -Value $UseManagedIdentity

    & $deployIntuneScript @deployIntuneParams
}

if ($RunDeviceOnboarding) {
    Write-Section "Step 8: Ensure device onboarding group"
    $onboardScript = Join-Path $scriptRoot "Invoke-DeviceOnboarding.ps1"

    $onboardParams = @{
        TenantId = $TenantId
        DynamicGroupName = "Intune-Windows-EntraJoined-All"
    }
    Add-OptionalSwitch -Table $onboardParams -Name "UseManagedIdentity" -Value $UseManagedIdentity

    & $onboardScript @onboardParams
}

if ($DeployConditionalAccessPolicies) {
    Write-Section "Step 9: Apply break-glass hardening policy and sign-in report"
    $hardeningScript = Join-Path $scriptRoot "Invoke-BreakGlassPostBootstrapHardening.ps1"
    $hardeningParams = @{
        TenantId = $TenantId
        BreakGlassGroupName = $BreakGlassGroupName
        TrustedLocationName = $TrustedNamedLocationName
        ReplaceExisting = $true
        OutputFolder = $OutputFolder
    }
    if ($SkipTrustedLocation -or (-not $TrustedIpCidrs -or $TrustedIpCidrs.Count -eq 0)) {
        $hardeningParams.SkipTrustedLocation = $true
    }
    Add-OptionalSwitch -Table $hardeningParams -Name "UseManagedIdentity" -Value $UseManagedIdentity
    if (-not $EnforcePolicies) {
        $hardeningParams.ReportOnly = $true
    }

    & $hardeningScript @hardeningParams
}

if ($ExportEvidence) {
    Write-Section "Step 10: Export Essential Eight evidence"
    $evidenceScript = Join-Path $scriptRoot "Export-Essential8Evidence.ps1"
    $evidenceParams = @{
        TenantId = $TenantId
        OutputFolder = $OutputFolder
    }
    Add-OptionalSwitch -Table $evidenceParams -Name "UseManagedIdentity" -Value $UseManagedIdentity

    & $evidenceScript @evidenceParams
}

Write-Section "Completed"
Write-Host "New tenant bootstrap workflow finished." -ForegroundColor Green
Write-Host "Foundation file: $foundationFile" -ForegroundColor Green
Write-Host "CA reference data file: $referenceFile" -ForegroundColor Green
Write-Host "Checklist file: $checklistFile" -ForegroundColor Green
Write-Host "Generated CA policy folder: $resolvedGeneratedPolicyFolder" -ForegroundColor Green
if (-not $DeployConditionalAccessPolicies) {
    Write-Host "Conditional Access policies were validated but not deployed. Re-run with -DeployConditionalAccessPolicies to deploy." -ForegroundColor Yellow
}
if (-not $EnforcePolicies) {
    Write-Host "Policies are in safer rollout mode (report-only where applicable). Re-run with -EnforcePolicies when ready." -ForegroundColor Yellow
}
