[CmdletBinding()]
param()

if (-not $IsWindows) {
    throw "This script must be run on a Windows endpoint."
}

$usoClient = Join-Path $env:SystemRoot "System32/UsoClient.exe"
if (-not (Test-Path -Path $usoClient)) {
    throw "UsoClient.exe not found at expected path: $usoClient"
}

Write-Host "Triggering interactive Windows Update scan via UsoClient..."
& $usoClient StartInteractiveScan
Write-Host "Scan command sent. Verify update status in Settings > Windows Update."
