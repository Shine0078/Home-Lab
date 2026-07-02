# Backup & Recovery Strategy

## Overview

This document defines the backup and recovery strategy for the AD-HomeLab environment. It covers what is backed up, how often, where backups are stored, and how to restore from them.

## Backup Components

| Component | Method | Format | Automated? |
|-----------|--------|--------|------------|
| Group Policy Objects | `Backup-GPO` | GPO backup directory | Yes (`08-Backup-Lab.ps1`) |
| AD Users | `Get-ADUser -Properties *` | CSV | Yes |
| AD Group Memberships | `Get-ADGroup -Properties Members` | CSV | Yes |
| DNS Zone Records | `Get-DnsServerResourceRecord` | CSV | Yes |
| OU Structure | `Get-ADOrganizationalUnit` | CSV | Yes |
| Password Policy | `Get-ADDefaultDomainPasswordPolicy` | CLI XML | Yes |
| VM State | `Checkpoint-VM` | Hyper-V snapshot | Yes (on HV host) |
| DSRM Password | Manual | Secure note | No (document offline) |

## Recovery Point Objective (RPO) and Recovery Time Objective (RTO)

| Metric | Target | Notes |
|--------|--------|-------|
| **RPO** | 24 hours | Backup runs daily; max 1 day of data loss |
| **RTO** | 30 minutes | GPO + user restore via script; VM checkpoint restore is fastest |
| **RTO (full)** | 2 hours | Full rebuild from scratch including DC promotion |

## Backup Schedule

| Frequency | What | Script | Retention |
|-----------|------|--------|-----------|
| Daily (2:00 AM) | Full backup | `08-Backup-Lab.ps1` | 7 days |
| Weekly (Sunday) | VM checkpoints | `Checkpoint-VM` | 4 weeks |
| Monthly (1st) | Full backup + GPO export | `08-Backup-Lab.ps1` | 90 days |

## Backup Storage

- **Primary**: `output/backups/<timestamp>/` (local on DC01)
- **Secondary**: Copy to Hyper-V host or external drive (manual)
- **Format**: Timestamped directories, each self-contained
- **Size**: ~2-5 MB per backup (without VM snapshots)

## Recovery Procedures

### Scenario 1: Accidental GPO deletion
```powershell
# Identify the backup
Get-ChildItem output/backups -Directory | Sort-Object Name -Descending | Select-Object -First 1

# Restore
.\scripts\09-Restore-Lab.ps1 -BackupPath "output\backups\<timestamp>"
```

### Scenario 2: Accidental user deletion
```powershell
# Restore from latest backup
.\scripts\09-Restore-Lab.ps1 -BackupPath "output\backups\<timestamp>"
# Users get temp passwords; ChangePasswordAtLogon is enabled
```

### Scenario 3: DC failure (VM won't boot)
```powershell
# On Hyper-V host:
# 1. Restore VM from checkpoint
Restore-VMSnapshot -VMName DC01 -Name "Pre-Backup-<timestamp>"

# 2. If no checkpoint, rebuild from scratch:
#    Run scripts/01-Setup-DC.ps1 -> scripts/04-Create-Users.ps1
#    Then restore from backup: scripts/09-Restore-Lab.ps1
```

### Scenario 4: Full environment loss
1. Re-provision VMs: `hyperv/Provision-All.ps1`
2. Install OS: `hyperv/04-Attach-ISO.ps1`
3. Setup DC: `scripts/01-Setup-DC.ps1`
4. Join clients: `scripts/02-Join-Domain.ps1`
5. Configure GPOs: `scripts/03-Configure-GPOs.ps1`
6. Restore users: `scripts/09-Restore-Lab.ps1 -BackupPath <backup>`
7. Validate: `scripts/05-Validate-Lab.ps1`

## Verification

After any restore, validate the environment:

```powershell
# Run full validation
.\scripts\05-Validate-Lab.ps1

# Check GPO count
(Get-GPO -All).Count

# Check user count
(Get-ADUser -Filter * | Where-Object { $_.DistinguishedName -match 'OU=Staff|OU=IT' }).Count

# Check password policy
Get-ADDefaultDomainPasswordPolicy | Select-Object MinPasswordLength, ComplexityEnabled, LockoutThreshold
```

## What this demonstrates

| Component | Skill |
|-----------|-------|
| GPO backup/restore | Group Policy lifecycle management |
| AD user export/import | Directory service recovery |
| VM checkpoints | Virtualization disaster recovery |
| RPO/RTO definition | Business continuity planning |
| Backup scheduling | Operational discipline |
| Documented runbooks | Operational readiness |
