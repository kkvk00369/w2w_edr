[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TenantId,

    [Parameter()]
    [string]$OutputFolder = "../out",

    [Parameter()]
    [switch]$UseManagedIdentity
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Section {
    param([string]$Message)
    Write-Host "`n==== $Message ====" -ForegroundColor Cyan
}

function Ensure-Module {
    param([string]$Name)
    if (-not (Get-Module -ListAvailable -Name $Name)) {
        Write-Host "Installing module: $Name" -ForegroundColor Yellow
        Install-Module -Name $Name -Scope CurrentUser -Force -AllowClobber
    }
    Import-Module $Name -ErrorAction Stop
}

function Connect-Graph {
    Ensure-Module -Name "Microsoft.Graph.Authentication"

    $scopes = @(
        "Policy.Read.All",
        "Directory.Read.All"
    )

    if ($UseManagedIdentity) {
        Connect-MgGraph -Identity -TenantId $TenantId -NoWelcome
    }
    else {
        Connect-MgGraph -TenantId $TenantId -Scopes $scopes -NoWelcome
    }

    Select-MgProfile -Name "beta"
}

function Resolve-OutputFolder {
    param([string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    $scriptRoot = Split-Path -Parent $PSCommandPath
    return (Join-Path $scriptRoot $Path)
}

function Write-JsonFile {
    param(
        [string]$Path,
        [object]$Data
    )

    $json = $Data | ConvertTo-Json -Depth 40
    Set-Content -Path $Path -Value $json -Encoding utf8
}

Write-Section "Authenticating to Microsoft Graph"
Connect-Graph

Write-Section "Preparing output folder"
$resolvedOutput = Resolve-OutputFolder -Path $OutputFolder
if (-not (Test-Path -Path $resolvedOutput)) {
    New-Item -ItemType Directory -Path $resolvedOutput -Force | Out-Null
}
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outPath = Join-Path $resolvedOutput "ca-reference-data-$timestamp.json"

Write-Section "Collecting authentication strengths"
$authStrengths = Invoke-MgGraphRequest -Method GET -Uri "/beta/identity/conditionalAccess/authenticationStrength/policies" -OutputType PSObject

Write-Section "Collecting named locations"
$namedLocations = Invoke-MgGraphRequest -Method GET -Uri "/beta/identity/conditionalAccess/namedLocations" -OutputType PSObject

Write-Section "Collecting directory roles"
$directoryRoles = Invoke-MgGraphRequest -Method GET -Uri "/v1.0/directoryRoles" -OutputType PSObject

$report = [PSCustomObject]@{
    generatedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
    tenantId = $TenantId
    authenticationStrengthPolicies = $authStrengths.value
    namedLocations = $namedLocations.value
    activeDirectoryRoles = $directoryRoles.value
}

Write-JsonFile -Path $outPath -Data $report

Write-Host "Reference data written to: $outPath" -ForegroundColor Green
