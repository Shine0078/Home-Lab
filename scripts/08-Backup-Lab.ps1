<#
.SYNOPSIS
    Backs up the AD-HomeLab environment (GPOs, AD users, VM checkpoints).

.DESCRIPTION
    Creates a full backup of the lab environment:
      1. Exports all GPOs to config/gpo-exports/ (Backup-GPO)
      2. Exports all AD users to output/ad-users-backup.csv
      3. Exports AD group membership to output/ad-groups-backup.csv
      4. Exports DNS zone to output/dns-backup.csv
      5. Creates VM checkpoints (snapshots) on Hyper-V host
    Idempotent: overwrites previous backup. Logs to logs/backup-lab.log.

.PARAMETER BackupDir
    Base directory for backups. Default: output/backups/

.NOTES
    Run as Administrator on DC01 (or Hyper-V host for VM checkpoints).
    Part of AD-HomeLab Phase 9 (Disaster Recovery).
#>

#Requires -RunAsAdministrator
#Requires -Modules ActiveDirectory, GroupPolicy

param(
    [string]$BackupDir = (Join-Path $PSScriptRoot '..\output\backups')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$LogDir  = Join-Path $PSScriptRoot '..\logs'
$LogFile = Join-Path $LogDir 'backup-lab.log'

if (-not (Test-Path $LogDir))      { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
if (-not (Test-Path $BackupDir))  { New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null }

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $entry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $entry
    if ($Level -eq 'WARN') { Write-Host "  [WARN] $Message" -ForegroundColor Yellow }
    elseif ($Level -eq 'ERROR') { Write-Host "  [ERROR] $Message" -ForegroundColor Red }
    else { Write-Host "  $Message" -ForegroundColor Cyan }
}

$timestamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$sessionBackupDir = Join-Path $BackupDir $timestamp
New-Item -ItemType Directory -Path $sessionBackupDir -Force | Out-Null

Write-Log "=== AD-HomeLab Backup ($timestamp) ==="

# ── 1. Backup GPOs ──
Write-Log "1. Backing up GPOs..."
$gpoBackupPath = Join-Path $sessionBackupDir 'gpos'
New-Item -ItemType Directory -Path $gpoBackupPath -Force | Out-Null

try {
    $allGPOs = Get-GPO -All -ErrorAction Stop
    foreach ($gpo in $allGPOs) {
        $gpoBackupName = $gpo.DisplayName -replace '[^a-zA-Z0-9_-]', '_'
        try {
            Backup-GPO -Guid $gpo.Id -Path $gpoBackupPath -ErrorAction Stop | Out-Null
            Write-Log "  Backed up GPO: $($gpo.DisplayName)"
        }
        catch {
            Write-Log "  Failed to backup GPO $($gpo.DisplayName): $($_.Exception.Message)" 'WARN'
        }
    }
    Write-Log "  GPO backup complete: $($allGPOs.Count) GPOs"
}
catch {
    Write-Log "  GPO backup failed: $($_.Exception.Message)" 'ERROR'
}

# ── 2. Export AD Users ──
Write-Log "2. Exporting AD users..."
$usersBackupPath = Join-Path $sessionBackupDir 'ad-users-backup.csv'
try {
    $users = Get-ADUser -Filter * -Properties * -ErrorAction Stop |
        Select-Object SamAccountName, UserPrincipalName, DisplayName, GivenName, Surname,
               Title, Department, Enabled, DistinguishedName, EmailAddress, Description
    $users | Export-Csv -Path $usersBackupPath -NoTypeInformation -Force
    Write-Log "  Exported $($users.Count) users to $usersBackupPath"
}
catch {
    Write-Log "  User export failed: $($_.Exception.Message)" 'ERROR'
}

# ── 3. Export AD Groups and Memberships ──
Write-Log "3. Exporting AD group memberships..."
$groupsBackupPath = Join-Path $sessionBackupDir 'ad-groups-backup.csv'
try {
    $groups = Get-ADGroup -Filter * -Properties Members -ErrorAction Stop
    $groupExport = @()
    foreach ($group in $groups) {
        foreach ($memberDN in $group.Members) {
            $groupExport += [PSCustomObject]@{
                GroupName = $group.Name
                GroupDN   = $group.DistinguishedName
                MemberDN  = $memberDN
            }
        }
    }
    $groupExport | Export-Csv -Path $groupsBackupPath -NoTypeInformation -Force
    Write-Log "  Exported $($groups.Count) groups with $($groupExport.Count) memberships"
}
catch {
    Write-Log "  Group export failed: $($_.Exception.Message)" 'ERROR'
}

# ── 4. Export DNS Zone ──
Write-Log "4. Exporting DNS zone records..."
$dnsBackupPath = Join-Path $sessionBackupDir 'dns-backup.csv'
try {
    $dnsRecords = Get-DnsServerResourceRecord -ZoneName 'homelab.local' -ErrorAction SilentlyContinue
    if ($dnsRecords) {
        $dnsRecords | Select-Object HostName, RecordType, RecordData, TimeToLive |
            Export-Csv -Path $dnsBackupPath -NoTypeInformation -Force
        Write-Log "  Exported $($dnsRecords.Count) DNS records"
    }
    else {
        Write-Log "  No DNS records found (zone may not exist)"
    }
}
catch {
    Write-Log "  DNS export failed: $($_.Exception.Message)" 'WARN'
}

# ── 5. Export AD OU Structure ──
Write-Log "5. Exporting OU structure..."
$ouBackupPath = Join-Path $sessionBackupDir 'ou-structure-backup.csv'
try {
    $ous = Get-ADOrganizationalUnit -Filter * -Properties Description -ErrorAction Stop |
        Select-Object Name, DistinguishedName, Description, ProtectedFromAccidentalDeletion
    $ous | Export-Csv -Path $ouBackupPath -NoTypeInformation -Force
    Write-Log "  Exported $($ous.Count) OUs"
}
catch {
    Write-Log "  OU export failed: $($_.Exception.Message)" 'ERROR'
}

# ── 6. Export Password Policy ──
Write-Log "6. Exporting password policy..."
$policyBackupPath = Join-Path $sessionBackupDir 'password-policy-backup.xml'
try {
    $policy = Get-ADDefaultDomainPasswordPolicy -ErrorAction Stop
    $policy | Export-Clixml -Path $policyBackupPath -Force
    Write-Log "  Password policy exported (XML)"
}
catch {
    Write-Log "  Policy export failed: $($_.Exception.Message)" 'ERROR'
}

# ── 7. VM Checkpoints (if Hyper-V module available) ──
Write-Log "7. Creating VM checkpoints..."
$vmNames = @('DC01', 'WIN11-CLIENT01', 'WIN11-CLIENT02')
$hyperAvailable = Get-Module -ListAvailable -Name Hyper-V -ErrorAction SilentlyContinue

if ($hyperAvailable -and -not (Test-Path 'C:\Windows\System32\vmms.exe')) {
    Write-Log "  Running on Hyper-V host. Creating checkpoints..."
    foreach ($vmName in $vmNames) {
        $vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue
        if ($vm) {
            $checkpointName = "Pre-Backup-$timestamp"
            Checkpoint-VM -Name $vmName -SnapshotName $checkpointName -ErrorAction SilentlyContinue
            Write-Log "  Checkpoint created: $vmName ($checkpointName)"
        }
        else {
            Write-Log "  VM '$vmName' not found on this host" 'WARN'
        }
    }
}
else {
    Write-Log "  Not running on Hyper-V host. Skipping VM checkpoints."
    Write-Log "  Run this script on the Hyper-V host to create checkpoints."
}

Write-Log "=== Backup complete ==="
Write-Log "  Backup location: $sessionBackupDir"
Write-Log "  Total size: $((Get-ChildItem -Path $sessionBackupDir -Recurse | Measure-Object -Property Length -Sum).Sum / 1KB) KB"
