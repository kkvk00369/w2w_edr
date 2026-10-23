[CmdletBinding()]
param(
    [switch]$Force
)

$requiredModules = @(
    "Microsoft.Graph.Authentication",
    "Microsoft.Graph.Groups"
)

foreach ($module in $requiredModules) {
    $installed = Get-Module -ListAvailable -Name $module
    if ($installed -and -not $Force) {
        Write-Host "Module already installed: $module"
        continue
    }

    Write-Host "Installing module: $module"
    Install-Module -Name $module -Scope CurrentUser -Repository PSGallery -Force
}

Write-Host "Expedited update Graph prerequisite check complete."
