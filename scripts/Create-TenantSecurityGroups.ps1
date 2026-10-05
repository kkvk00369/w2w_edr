[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TenantId,

    [Parameter()]
    [string]$DomainName,

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
    [switch]$CreateBreakGlassAccounts,

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
        "User.ReadWrite.All",
        "Group.ReadWrite.All",
        "Directory.ReadWrite.All",
        "RoleManagement.ReadWrite.Directory"
    )

    if ($UseManagedIdentity) {
        Connect-MgGraph -Identity -TenantId $TenantId -NoWelcome
    }
    else {
        Connect-MgGraph -TenantId $TenantId -Scopes $scopes -NoWelcome
    }

    Select-MgProfile -Name "beta"
}

function Get-DefaultDomainName {
    $org = Invoke-MgGraphRequest -Method GET -Uri "/v1.0/domains" -OutputType PSObject
    $default = @($org.value | Where-Object { $_.isDefault -eq $true } | Select-Object -First 1)
    if ($default.Count -eq 0) {
        throw "Unable to determine default domain. Provide -DomainName explicitly."
    }
    return $default[0].id
}

function New-StrongPassword {
    $chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@$%*+-_"
    $length = 32
    $rnd = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
    $bytes = New-Object byte[]($length)
    $rnd.GetBytes($bytes)
    $passwordChars = for ($i = 0; $i -lt $length; $i++) {
        $chars[$bytes[$i] % $chars.Length]
    }
    return (-join $passwordChars)
}

function Ensure-SecurityGroup {
    param([string]$DisplayName)

    $escaped = $DisplayName.Replace("'", "''")
    $existing = Invoke-MgGraphRequest -Method GET -Uri "/v1.0/groups?`$filter=displayName eq '$escaped'" -OutputType PSObject
    if ($existing.value.Count -gt 0) {
        return $existing.value[0]
    }

    $mailNick = ($DisplayName -replace "[^a-zA-Z0-9]", "").ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($mailNick)) {
        $mailNick = "secgroup"
    }

    $body = @{
        displayName = $DisplayName
        description = "Managed by tenant security automation"
        mailEnabled = $false
        securityEnabled = $true
        mailNickname = $mailNick
    } | ConvertTo-Json -Depth 8

    return (Invoke-MgGraphRequest -Method POST -Uri "/v1.0/groups" -Body $body -ContentType "application/json" -OutputType PSObject)
}

function Get-UserByUpn {
    param([string]$UserPrincipalName)

    $escaped = $UserPrincipalName.Replace("'", "''")
    $result = Invoke-MgGraphRequest -Method GET -Uri "/v1.0/users?`$filter=userPrincipalName eq '$escaped'" -OutputType PSObject
    if ($result.value.Count -gt 0) {
        return $result.value[0]
    }

    return $null
}

function Ensure-BreakGlassAccount {
    param(
        [string]$UserPrincipalName,
        [string]$DisplayName,
        [string]$GivenName,
        [string]$Surname
    )

    $existing = Get-UserByUpn -UserPrincipalName $UserPrincipalName
    if ($null -ne $existing) {
        return [PSCustomObject]@{
            User = $existing
            Created = $false
            Password = $null
        }
    }

    $password = New-StrongPassword
    $mailNick = ($UserPrincipalName.Split("@") | Select-Object -First 1)

    $body = @{
        accountEnabled = $true
        displayName = $DisplayName
        givenName = $GivenName
        surname = $Surname
        userPrincipalName = $UserPrincipalName
        mailNickname = $mailNick
        passwordPolicies = "DisablePasswordExpiration"
        passwordProfile = @{
            forceChangePasswordNextSignIn = $false
            password = $password
        }
    } | ConvertTo-Json -Depth 12

    $created = Invoke-MgGraphRequest -Method POST -Uri "/v1.0/users" -Body $body -ContentType "application/json" -OutputType PSObject
    return [PSCustomObject]@{
        User = $created
        Created = $true
        Password = $password
    }
}

function Ensure-DirectoryRole {
    param([string]$RoleTemplateId)

    $existing = Invoke-MgGraphRequest -Method GET -Uri "/v1.0/directoryRoles?`$filter=roleTemplateId eq '$RoleTemplateId'" -OutputType PSObject
    if ($existing.value.Count -gt 0) {
        return $existing.value[0]
    }

    $activateBody = @{ roleTemplateId = $RoleTemplateId } | ConvertTo-Json
    [void](Invoke-MgGraphRequest -Method POST -Uri "/v1.0/directoryRoles" -Body $activateBody -ContentType "application/json")

    $after = Invoke-MgGraphRequest -Method GET -Uri "/v1.0/directoryRoles?`$filter=roleTemplateId eq '$RoleTemplateId'" -OutputType PSObject
    if ($after.value.Count -eq 0) {
        throw "Failed to activate directory role template id: $RoleTemplateId"
    }

    return $after.value[0]
}

function Ensure-RoleMember {
    param(
        [string]$DirectoryRoleId,
        [string]$ObjectId
    )

    $members = Invoke-MgGraphRequest -Method GET -Uri "/v1.0/directoryRoles/$DirectoryRoleId/members?`$select=id" -OutputType PSObject
    $exists = @($members.value | Where-Object { $_.id -eq $ObjectId }).Count -gt 0
    if ($exists) {
        return
    }

    $body = @{ "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$ObjectId" } | ConvertTo-Json
    [void](Invoke-MgGraphRequest -Method POST -Uri "/v1.0/directoryRoles/$DirectoryRoleId/members/`$ref" -Body $body -ContentType "application/json")
}

function Ensure-GroupMember {
    param(
        [string]$GroupId,
        [string]$ObjectId
    )

    $members = Invoke-MgGraphRequest -Method GET -Uri "/v1.0/groups/$GroupId/members?`$select=id" -OutputType PSObject
    $exists = @($members.value | Where-Object { $_.id -eq $ObjectId }).Count -gt 0
    if ($exists) {
        return
    }

    $body = @{ "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$ObjectId" } | ConvertTo-Json
    [void](Invoke-MgGraphRequest -Method POST -Uri "/v1.0/groups/$GroupId/members/`$ref" -Body $body -ContentType "application/json")
}

Write-Section "Authenticating to Microsoft Graph"
Connect-Graph

if (-not $DomainName) {
    $DomainName = Get-DefaultDomainName
}

Write-Host "Using domain: $DomainName" -ForegroundColor Green

Write-Section "Ensuring baseline security groups"
$pilotGroup = Ensure-SecurityGroup -DisplayName $PilotGroupName
$productionGroup = Ensure-SecurityGroup -DisplayName $ProductionGroupName
$exclusionGroup = Ensure-SecurityGroup -DisplayName $ExclusionGroupName
$breakGlassGroup = Ensure-SecurityGroup -DisplayName $BreakGlassGroupName

Write-Host "Pilot group: $($pilotGroup.id)" -ForegroundColor Green
Write-Host "Production group: $($productionGroup.id)" -ForegroundColor Green
Write-Host "Exclusion group: $($exclusionGroup.id)" -ForegroundColor Green
Write-Host "Break-glass group: $($breakGlassGroup.id)" -ForegroundColor Green

$breakGlassAccounts = @()
if ($CreateBreakGlassAccounts) {
    Write-Section "Ensuring break-glass accounts"
    for ($i = 1; $i -le $BreakGlassAccountCount; $i++) {
        $upn = "{0}{1}@{2}" -f $BreakGlassPrefix, $i, $DomainName
        $displayName = "Break Glass {0}" -f $i
        $acct = Ensure-BreakGlassAccount -UserPrincipalName $upn -DisplayName $displayName -GivenName "Break" -Surname "Glass$i"
        $breakGlassAccounts += $acct

        Ensure-GroupMember -GroupId $breakGlassGroup.id -ObjectId $acct.User.id
        Ensure-GroupMember -GroupId $exclusionGroup.id -ObjectId $acct.User.id

        Write-Host "Ensured break-glass account: $upn" -ForegroundColor Green
    }

    Write-Section "Ensuring break-glass role assignments"
    foreach ($roleTemplateId in $BreakGlassRoleTemplateIds) {
        $role = Ensure-DirectoryRole -RoleTemplateId $roleTemplateId
        foreach ($acct in $breakGlassAccounts) {
            Ensure-RoleMember -DirectoryRoleId $role.id -ObjectId $acct.User.id
        }
        Write-Host "Ensured role assignment for roleTemplateId: $roleTemplateId" -ForegroundColor Green
    }
}
else {
    Write-Host "Break-glass account creation skipped. Re-run with -CreateBreakGlassAccounts to create emergency accounts." -ForegroundColor Yellow
}

Write-Section "Completed"
$payload = [PSCustomObject]@{
    tenantId = $TenantId
    domainName = $DomainName
    groups = [PSCustomObject]@{
        pilot = [PSCustomObject]@{ id = $pilotGroup.id; displayName = $pilotGroup.displayName }
        production = [PSCustomObject]@{ id = $productionGroup.id; displayName = $productionGroup.displayName }
        exclusion = [PSCustomObject]@{ id = $exclusionGroup.id; displayName = $exclusionGroup.displayName }
        breakGlass = [PSCustomObject]@{ id = $breakGlassGroup.id; displayName = $breakGlassGroup.displayName }
    }
    breakGlassAccounts = @(
        foreach ($acct in $breakGlassAccounts) {
            [PSCustomObject]@{
                id = $acct.User.id
                userPrincipalName = $acct.User.userPrincipalName
                displayName = $acct.User.displayName
                createdThisRun = $acct.Created
                initialPassword = $acct.Password
            }
        }
    )
}

$payload | ConvertTo-Json -Depth 30
