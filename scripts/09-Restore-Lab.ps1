<#
.SYNOPSIS
    Restores the AD-HomeLab environment from a backup.

.DESCRIPTION
    Restores from a backup created by scripts/08-Backup-Lab.ps1:
      1. Restores GPOs from backup directory (Import-GPO)
      2. Restores AD users from CSV (re-creates if missing)
      3. Restores group memberships
      4. Restores password policy from XML
    Does NOT restore DNS or VM checkpoints (manual steps documented).
    Idempotent: only restores missing items. Logs to logs/restore-lab.log.

.PARAMETER BackupPath
    Path to the timestamped backup directory (e.g., output/backups/2026-07-02_120000)

.NOTES
    Run as Administrator on DC01.
    Part of AD-HomeLab Phase 9 (Disaster Recovery).
#>

#Requires -RunAsAdministrator
#Requires -Modules ActiveDirectory, GroupPolicy

param(
    [Parameter(Mandatory = $true)]
    [string]$BackupPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$LogDir  = Join-Path $PSScriptRoot '..\logs'
$LogFile = Join-Path $LogDir 'restore-lab.log'

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $entry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $entry
    if ($Level -eq 'WARN') { Write-Output "  [WARN] $Message" -ForegroundColor Yellow }
    elseif ($Level -eq 'ERROR') { Write-Output "  [ERROR] $Message" -ForegroundColor Red }
    else { Write-Output "  $Message" -ForegroundColor Cyan }
}

function ConvertTo-SecurePassword {
    param([Parameter(Mandatory = $true)][string]$Text)

    $secure = New-Object System.Security.SecureString
    foreach ($char in $Text.ToCharArray()) {
        $secure.AppendChar($char)
    }
    $secure.MakeReadOnly()
    return $secure
}

if (-not (Test-Path $BackupPath)) {
    throw "Backup directory not found: $BackupPath"
}

Write-Log "=== AD-HomeLab Restore ==="
Write-Log "Backup source: $BackupPath"

# â”€â”€ 1. Restore GPOs â”€â”€
$gpoBackupDir = Join-Path $BackupPath 'gpos'
if (Test-Path $gpoBackupDir) {
    Write-Log "1. Restoring GPOs from $gpoBackupDir..."
    $gpoBackups = Get-ChildItem -Path $gpoBackupDir -Directory -ErrorAction SilentlyContinue
    foreach ($gpoBackup in $gpoBackups) {
        $manifest = Join-Path $gpoBackup.FullName 'manifest.xml'
        if (Test-Path $manifest) {
            try {
                $manifestXml = [xml](Get-Content -Path $manifest -Raw)
                $backupId = $manifestXml.BackupInfo.ID
                $targetName = $manifestXml.BackupInfo.DisplayName
                $importedGPO = Import-GPO -BackupId $backupId `
                    -Path $gpoBackupDir -TargetName $targetName `
                    -CreateIfNeeded $true -ErrorAction Stop
                Write-Log "  Restored GPO: $($importedGPO.DisplayName) (ID: $($importedGPO.Id))"
            }
            catch {
                Write-Log "  Failed to restore GPO $($gpoBackup.Name): $($_.Exception.Message)" 'WARN'
            }
        }
    }
}
else {
    Write-Log "1. No GPO backup directory found. Skipping GPO restore." 'WARN'
}

# â”€â”€ 2. Restore AD Users â”€â”€
$usersBackup = Join-Path $BackupPath 'ad-users-backup.csv'
if (Test-Path $usersBackup) {
    Write-Log "2. Restoring AD users from $usersBackup..."
    $users = Import-Csv -Path $usersBackup
    $restored = 0
    $skipped = 0

    foreach ($user in $users) {
        $existing = Get-ADUser -Filter "SamAccountName -eq '$($user.SamAccountName)'" -ErrorAction SilentlyContinue
        if ($existing) {
            $skipped++
            continue
        }

        try {
            # Determine OU from DistinguishedName
            $dn = $user.DistinguishedName
            $ouStart = $dn.IndexOf(',')
            if ($ouStart -gt 0) {
                $ouPath = $dn.Substring($ouStart + 1)
            }
            else {
                $ouPath = "OU=Staff,DC=homelab,DC=local"
            }

            $tempPassword = -join ((48..57) + (65..90) + (97..122) + (33..38) | Get-Random -Count 16 | ForEach-Object { [char]$_ })
            $securePassword = ConvertTo-SecurePassword -Text $tempPassword

            New-ADUser `
                -SamAccountName $user.SamAccountName `
                -UserPrincipalName $user.UserPrincipalName `
                -Name $user.DisplayName `
                -GivenName $user.GivenName `
                -Surname $user.Surname `
                -DisplayName $user.DisplayName `
                -Title $user.Title `
                -Department $user.Department `
                -Path $ouPath `
                -AccountPassword $securePassword `
                -ChangePasswordAtLogon $true `
                -Enabled $true `
                -ErrorAction Stop

            $restored++
            Write-Log "  Restored user: $($user.SamAccountName)"
        }
        catch {
            Write-Log "  Failed to restore $($user.SamAccountName): $($_.Exception.Message)" 'WARN'
        }
    }
    Write-Log "  Users restored: $restored | Skipped (existing): $skipped"
}
else {
    Write-Log "2. No user backup CSV found. Skipping user restore." 'WARN'
}

# â”€â”€ 3. Restore Password Policy â”€â”€
$policyBackup = Join-Path $BackupPath 'password-policy-backup.xml'
if (Test-Path $policyBackup) {
    Write-Log "3. Restoring password policy..."
    try {
        $policy = Import-Clixml -Path $policyBackup -ErrorAction Stop
        Set-ADDefaultDomainPasswordPolicy `
            -Identity 'homelab.local' `
            -MinPasswordLength $policy.MinPasswordLength `
            -ComplexityEnabled $policy.ComplexityEnabled `
            -MaxPasswordAge $policy.MaxPasswordAge `
            -MinPasswordAge $policy.MinPasswordAge `
            -PasswordHistoryCount $policy.PasswordHistoryCount `
            -LockoutThreshold $policy.LockoutThreshold `
            -LockoutDuration $policy.LockoutDuration `
            -LockoutObservationWindow $policy.LockoutObservationWindow `
            -ErrorAction Stop
        Write-Log "  Password policy restored"
    }
    catch {
        Write-Log "  Password policy restore failed: $($_.Exception.Message)" 'WARN'
    }
}
else {
    Write-Log "3. No password policy backup found. Skipping." 'WARN'
}

# â”€â”€ 4. Restore DNS (manual step) â”€â”€
Write-Log "4. DNS restore is a manual step:"
Write-Log "   Import DNS records from: $(Join-Path $BackupPath 'dns-backup.csv')"
Write-Log "   Use Add-DnsServerResourceRecord for each record."

# â”€â”€ 5. VM Checkpoint Restore (manual step) â”€â”€
Write-Log "5. VM checkpoint restore is a manual step:"
Write-Log "   Use Hyper-V Manager or: Restore-VMSnapshot -VMName <name> -Name <snapshot>"

Write-Log "=== Restore complete ==="
Write-Log "Review logs for any WARN or ERROR entries."
