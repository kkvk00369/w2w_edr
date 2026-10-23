[CmdletBinding()]
param(
    [string]$TenantId,
    [string[]]$Scopes = @(
        "DeviceManagementConfiguration.ReadWrite.All",
        "Group.Read.All"
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
