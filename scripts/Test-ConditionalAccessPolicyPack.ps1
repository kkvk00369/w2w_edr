[CmdletBinding()]
param(
    [Parameter()]
    [string]$PolicyFolder = "../config/conditional-access",

    [Parameter()]
    [switch]$IncludeHardened,

    [Parameter()]
    [switch]$AllowPlaceholders
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-InputFolder {
    param([string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    $scriptRoot = Split-Path -Parent $PSCommandPath
    return (Resolve-Path (Join-Path $scriptRoot $Path)).Path
}

function Find-PlaceholderValues {
    param([object]$Node)

    $matches = New-Object System.Collections.Generic.List[string]

    function Visit {
        param([object]$Current)

        if ($null -eq $Current) {
            return
        }

        if ($Current -is [System.Collections.IDictionary]) {
            foreach ($key in $Current.Keys) {
                Visit -Current $Current[$key]
            }
            return
        }

        if (($Current -is [System.Collections.IEnumerable]) -and -not ($Current -is [string])) {
            foreach ($item in $Current) {
                Visit -Current $item
            }
            return
        }

        if ($Current -is [string] -and $Current.StartsWith("REPLACE_WITH_")) {
            [void]$matches.Add($Current)
        }
    }

    Visit -Current $Node
    return $matches
}

$resolvedFolder = Resolve-InputFolder -Path $PolicyFolder
$targets = @($resolvedFolder)
if ($IncludeHardened) {
    $hardened = Join-Path $resolvedFolder "hardened"
    if (Test-Path -Path $hardened) {
        $targets += $hardened
    }
}

$errors = New-Object System.Collections.Generic.List[string]

foreach ($target in $targets) {
    $files = Get-ChildItem -Path $target -Filter "*.json" -File
    foreach ($file in $files) {
        $raw = Get-Content -Path $file.FullName -Raw
        try {
            $obj = ConvertFrom-Json -InputObject $raw -AsHashtable
        }
        catch {
            [void]$errors.Add("Invalid JSON: $($file.FullName)")
            continue
        }

        foreach ($required in @("displayName", "state", "conditions", "grantControls")) {
            if (-not $obj.ContainsKey($required)) {
                [void]$errors.Add("Missing required property '$required' in $($file.FullName)")
            }
        }

        if ($obj.ContainsKey("state")) {
            $validStates = @("enabled", "disabled", "enabledForReportingButNotEnforced")
            if ($validStates -notcontains [string]$obj.state) {
                [void]$errors.Add("Invalid state '$($obj.state)' in $($file.FullName)")
            }
        }

        if (-not $AllowPlaceholders) {
            $placeholders = Find-PlaceholderValues -Node $obj
            if ($placeholders.Count -gt 0) {
                $unique = $placeholders | Sort-Object -Unique
                $joined = [string]::Join(", ", $unique)
                [void]$errors.Add("Unresolved placeholders in $($file.FullName): $joined")
            }
        }
    }
}

if ($errors.Count -gt 0) {
    Write-Host "Conditional Access policy validation failed:" -ForegroundColor Red
    foreach ($err in $errors) {
        Write-Host " - $err" -ForegroundColor Red
    }
    exit 1
}

Write-Host "Conditional Access policy validation passed." -ForegroundColor Green
