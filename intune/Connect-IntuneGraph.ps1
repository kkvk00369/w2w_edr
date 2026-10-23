[CmdletBinding()]
param(
    [string]$TenantId,
    [string[]]$Scopes = @(
        "Group.ReadWrite.All",
        "Policy.ReadWrite.MobilityManagement",
        "DeviceManagementConfiguration.ReadWrite.All",
        "DeviceManagementManagedDevices.ReadWrite.All",
        "Directory.ReadWrite.All"
    )
)

if ($TenantId) {
    Connect-MgGraph -TenantId $TenantId -Scopes $Scopes -NoWelcome
}
else {
    Connect-MgGraph -Scopes $Scopes -NoWelcome
}

$ctx = Get-MgContext
if (-not $ctx) {
    throw "Microsoft Graph connection failed."
}

Write-Host "Connected to Microsoft Graph."
Write-Host "Tenant: $($ctx.TenantId)"
Write-Host "Account: $($ctx.Account)"
Write-Host "Scopes: $($ctx.Scopes -join ', ')"
