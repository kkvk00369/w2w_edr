[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TenantFoundationFile,

    [Parameter(Mandatory = $true)]
    [string]$ReferenceDataFile,

    [Parameter()]
    [string]$PolicyFolder = "../config/conditional-access",

    [Parameter()]
    [string]$OutputFolder = "../generated/conditional-access",

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

function Replace-Token {
    param(
        [string]$Text,
        [string]$Token,
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $Text
    }

    return $Text.Replace($Token, $Value)
}

$foundationPath = Resolve-PathFromScriptRoot -Path $TenantFoundationFile
$referencePath = Resolve-PathFromScriptRoot -Path $ReferenceDataFile
$sourceFolder = Resolve-PathFromScriptRoot -Path $PolicyFolder
$targetFolder = Resolve-PathFromScriptRoot -Path $OutputFolder

if (-not (Test-Path -Path $foundationPath)) {
    throw "Tenant foundation file not found: $foundationPath"
}
if (-not (Test-Path -Path $referencePath)) {
    throw "Reference data file not found: $referencePath"
}
if (-not (Test-Path -Path $sourceFolder)) {
    throw "Policy folder not found: $sourceFolder"
}
if (-not (Test-Path -Path $targetFolder)) {
    New-Item -ItemType Directory -Path $targetFolder -Force | Out-Null
}

$foundation = Get-Content -Path $foundationPath -Raw | ConvertFrom-Json
$reference = Get-Content -Path $referencePath -Raw | ConvertFrom-Json

$breakGlassId = $null
if ($foundation.breakGlassAccounts -and $foundation.breakGlassAccounts.Count -gt 0) {
    $breakGlassId = $foundation.breakGlassAccounts[0].id
}

$trustedLocationId = $null
if ($null -ne $foundation.trustedNamedLocation) {
    $trustedLocationId = $foundation.trustedNamedLocation.id
}

$authStrength = @($reference.authenticationStrengthPolicies | Where-Object {
    $_.displayName -like "*$PhishingResistantAuthStrengthName*"
} | Select-Object -First 1)

$authStrengthId = $null
if ($authStrength.Count -gt 0) {
    $authStrengthId = $authStrength[0].id
}

$files = Get-ChildItem -Path $sourceFolder -Filter "*.json" -File -Recurse
if (-not $files) {
    throw "No CA policy JSON files found in: $sourceFolder"
}

$written = @()

foreach ($file in $files) {
    $relative = $file.FullName.Substring($sourceFolder.Length).TrimStart('/', '\\')
    $targetPath = Join-Path $targetFolder $relative
    $targetDir = Split-Path -Parent $targetPath
    if (-not (Test-Path -Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    $raw = Get-Content -Path $file.FullName -Raw
    $updated = $raw

    $updated = Replace-Token -Text $updated -Token "REPLACE_WITH_BREAK_GLASS_OBJECT_ID_1" -Value $breakGlassId
    $updated = Replace-Token -Text $updated -Token "REPLACE_WITH_PHISHING_RESISTANT_AUTH_STRENGTH_ID" -Value $authStrengthId
    $updated = Replace-Token -Text $updated -Token "REPLACE_WITH_TRUSTED_LOCATION_ID_1" -Value $trustedLocationId

    Set-Content -Path $targetPath -Value $updated -Encoding utf8
    $written += $targetPath
}

Write-Host "Generated tenant-ready CA policy files in: $targetFolder" -ForegroundColor Green
if (-not $breakGlassId) {
    Write-Host "Warning: break-glass account id was not found in foundation file." -ForegroundColor Yellow
}
if (-not $authStrengthId) {
    Write-Host "Warning: phishing-resistant auth strength id was not found." -ForegroundColor Yellow
}
if (-not $trustedLocationId) {
    Write-Host "Warning: trusted named location id was not found; location placeholders remain." -ForegroundColor Yellow
}

Write-Host "Files written:" -ForegroundColor Green
foreach ($path in $written) {
    Write-Host " - $path"
}
