<#
.SYNOPSIS
    Sets up Role-Based Access Control (RBAC) with security groups and OU delegation.

.DESCRIPTION
    Creates security groups for role-based access control and delegates
    permissions on OUs to enforce least-privilege:
      - GG-IT-Admins: full control of IT OU, read on all OUs
      - GG-Sales-Users: read-only on Staff OU
      - GG-Finance-Users: read-only on Staff OU
      - GG-Helpdesk-Operators: reset passwords + unlock accounts in Staff OU
    Also creates role-based distribution groups. Idempotent.

.NOTES
    Run as Administrator on DC01.
    Part of AD-HomeLab Phase 10 (RBAC).
#>

#Requires -RunAsAdministrator
#Requires -Modules ActiveDirectory

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$DomainDN = "DC=homelab,DC=local"
$LogDir   = Join-Path $PSScriptRoot '..\logs'
$LogFile  = Join-Path $LogDir 'setup-rbac.log'

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $entry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $entry
    if ($Level -eq 'WARN') { Write-Host "  [WARN] $Message" -ForegroundColor Yellow }
    else { Write-Host "  $Message" -ForegroundColor Cyan }
}

function New-GroupIfMissing {
    param(
        [string]$Name,
        [string]$Description,
        [string]$GroupScope = 'Global',
        [string]$Path = $DomainDN
    )
    $existing = Get-ADGroup -Filter "Name -eq '$Name'" -ErrorAction SilentlyContinue
    if (-not $existing) {
        New-ADGroup -Name $Name -GroupScope $GroupScope -Description $Description -Path $Path -ErrorAction Stop
        Write-Log "  Created group: $Name ($GroupScope)"
    }
    else {
        Write-Log "  Group '$Name' already exists."
    }
    return Get-ADGroup -Identity $Name
}

function Set-OUDelegation {
    param(
        [string]$OUPath,
        [string]$Trustee,
        [string]$Right,
        [string]$ObjectType = $null
    )
    try {
        $trusteeObj = Get-ADGroup -Identity $Trustee -ErrorAction Stop
        $trusteeSID = New-Object System.Security.Principal.SecurityIdentifier($trusteeObj.SID)

        switch ($Right) {
            'ResetPassword' {
                # Reset Password extended right (GUID: 00299570-246d-11d0-a768-00aa006e0529)
                $all = [System.DirectoryServices.ActiveDirectorySecurityInheritance]::All
                $ace = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
                    $trusteeSID,
                    [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight,
                    [System.Security.AccessControl.AccessControlType]::Allow,
                    [guid]'00299570-246d-11d0-a768-00aa006e0529',
                    $all
                )
            }
            'UnlockAccount' {
                $all = [System.DirectoryServices.ActiveDirectorySecurityInheritance]::All
                $ace = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
                    $trusteeSID,
                    [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight,
                    [System.Security.AccessControl.AccessControlType]::Allow,
                    [guid]'ccc2dc7d-a6bf-11d2-bb15-00c04f8f0d85',
                    $all
                )
            }
            'FullControl' {
                $ace = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
                    $trusteeSID,
                    [System.DirectoryServices.ActiveDirectoryRights]::GenericAll,
                    [System.Security.AccessControl.AccessControlType]::Allow
                )
            }
            'ReadOnly' {
                $ace = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
                    $trusteeSID,
                    [System.DirectoryServices.ActiveDirectoryRights]::GenericRead,
                    [System.Security.AccessControl.AccessControlType]::Allow
                )
            }
            default {
                Write-Log "  Unknown right: $Right" 'WARN'
                return
            }
        }

        $acl = Get-Acl -Path "AD:\$OUPath"
        $acl.AddAccessRule($ace)
        Set-Acl -Path "AD:\$OUPath" -AclObject $acl
        Write-Log "  Delegated '$Right' on $OUPath to $Trustee"
    }
    catch {
        Write-Log "  Delegation failed: $($_.Exception.Message)" 'WARN'
    }
}

Write-Log "=== RBAC Setup ==="

# ── 1. Create Security Groups ──
Write-Log "1. Creating role-based security groups..."

$groups = @(
    @{ Name = 'GG-IT-Admins';          Description = 'IT administrators - full control of IT OU';          Scope = 'Global' }
    @{ Name = 'GG-Sales-Users';        Description = 'Sales department users - read access to Staff OU';   Scope = 'Global' }
    @{ Name = 'GG-Finance-Users';      Description = 'Finance department users - read access to Staff OU'; Scope = 'Global' }
    @{ Name = 'GG-Ops-Users';          Description = 'Operations department users';                        Scope = 'Global' }
    @{ Name = 'GG-HR-Users';           Description = 'HR department users';                                Scope = 'Global' }
    @{ Name = 'GG-Helpdesk-Operators'; Description = 'Helpdesk - reset passwords and unlock accounts';     Scope = 'Global' }
    @{ Name = 'DL-Workstations-Admins'; Description = 'Local admin on workstation computers';              Scope = 'DomainLocal' }
)

foreach ($group in $groups) {
    New-GroupIfMissing -Name $group.Name -Description $group.Description -GroupScope $group.Scope
}

# ── 2. Create a Groups OU to hold these groups ──
$groupsOU = "OU=Groups,$DomainDN"
$existingOU = Get-ADOrganizationalUnit -Filter "Name -eq 'Groups'" -ErrorAction SilentlyContinue
if (-not $existingOU) {
    New-ADOrganizationalUnit -Name 'Groups' -Path $DomainDN -ProtectedFromAccidentalDeletion $true
    Write-Log "2. Created OU=Groups for security groups"
}
else {
    Write-Log "2. OU=Groups already exists"
}

# Move groups into Groups OU (if they're in the domain root)
foreach ($group in $groups) {
    $g = Get-ADGroup -Identity $group.Name -ErrorAction SilentlyContinue
    if ($g -and $g.DistinguishedName -notlike '*OU=Groups*') {
        try {
            Move-ADObject -Identity $g.DistinguishedName -TargetPath $groupsOU -ErrorAction Stop
            Write-Log "  Moved $($group.Name) to OU=Groups"
        }
        catch {
            Write-Log "  Could not move $($group.Name): $($_.Exception.Message)" 'WARN'
        }
    }
}

# ── 3. Delegate Permissions ──
Write-Log "3. Delegating OU permissions..."

# IT Admins: full control of IT OU
Set-OUDelegation -OUPath "OU=IT,$DomainDN" -Trustee 'GG-IT-Admins' -Right 'FullControl'

# IT Admins: read on all OUs
Set-OUDelegation -OUPath "OU=Staff,$DomainDN" -Trustee 'GG-IT-Admins' -Right 'ReadOnly'
Set-OUDelegation -OUPath "OU=Workstations,$DomainDN" -Trustee 'GG-IT-Admins' -Right 'ReadOnly'

# Helpdesk: reset passwords + unlock in Staff OU
Set-OUDelegation -OUPath "OU=Staff,$DomainDN" -Trustee 'GG-Helpdesk-Operators' -Right 'ResetPassword'
Set-OUDelegation -OUPath "OU=Staff,$DomainDN" -Trustee 'GG-Helpdesk-Operators' -Right 'UnlockAccount'

# Helpdesk: also in IT OU (for IT staff password resets)
Set-OUDelegation -OUPath "OU=IT,$DomainDN" -Trustee 'GG-Helpdesk-Operators' -Right 'ResetPassword'

# Department groups: read-only on Staff OU
Set-OUDelegation -OUPath "OU=Staff,$DomainDN" -Trustee 'GG-Sales-Users' -Right 'ReadOnly'
Set-OUDelegation -OUPath "OU=Staff,$DomainDN" -Trustee 'GG-Finance-Users' -Right 'ReadOnly'
Set-OUDelegation -OUPath "OU=Staff,$DomainDN" -Trustee 'GG-Ops-Users' -Right 'ReadOnly'
Set-OUDelegation -OUPath "OU=Staff,$DomainDN" -Trustee 'GG-HR-Users' -Right 'ReadOnly'

# ── 4. Add IT users to IT-Admins group ──
Write-Log "4. Populating group memberships..."
$itUsers = Get-ADUser -Filter "Department -eq 'IT'" -SearchBase "OU=IT,$DomainDN" -ErrorAction SilentlyContinue
if ($itUsers) {
    foreach ($user in $itUsers) {
        try {
            Add-ADGroupMember -Identity 'GG-IT-Admins' -Members $user.SamAccountName -ErrorAction SilentlyContinue
        }
        catch { }
    }
    Write-Log "  Added $($itUsers.Count) IT users to GG-IT-Admins"
}
else {
    Write-Log "  No IT users found in OU=IT (run 04-Create-Users.ps1 first)" 'WARN'
}

# Add Sales users to Sales group
$salesUsers = Get-ADUser -Filter "Department -eq 'Sales'" -SearchBase "OU=Staff,$DomainDN" -ErrorAction SilentlyContinue
if ($salesUsers) {
    foreach ($user in $salesUsers) {
        try { Add-ADGroupMember -Identity 'GG-Sales-Users' -Members $user.SamAccountName -ErrorAction SilentlyContinue } catch { }
    }
    Write-Log "  Added $($salesUsers.Count) Sales users to GG-Sales-Users"
}

# Add Finance users to Finance group
$finUsers = Get-ADUser -Filter "Department -eq 'Finance'" -SearchBase "OU=Staff,$DomainDN" -ErrorAction SilentlyContinue
if ($finUsers) {
    foreach ($user in $finUsers) {
        try { Add-ADGroupMember -Identity 'GG-Finance-Users' -Members $user.SamAccountName -ErrorAction SilentlyContinue } catch { }
    }
    Write-Log "  Added $($finUsers.Count) Finance users to GG-Finance-Users"
}

Write-Log "=== RBAC setup complete ==="
Write-Log "Review: docs/rbac-matrix.md for delegation matrix"
