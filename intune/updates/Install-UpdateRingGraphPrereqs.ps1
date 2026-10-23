[CmdletBinding()]
param(
    [switch]$Force
)

$moduleName = "Microsoft.Graph.DeviceManagement"
$installed = Get-Module -ListAvailable -Name $moduleName

if ($installed -and -not $Force) {
    Write-Host "Module already installed: $moduleName"
}
else {
    Write-Host "Installing module: $moduleName"
    Install-Module -Name $moduleName -Scope CurrentUser -Repository PSGallery -Force
}

Write-Host "Update ring Graph prerequisite check complete."
