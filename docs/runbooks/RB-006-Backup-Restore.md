# RB-006: Backup and Restore

## Symptom
Need to restore one or more AD objects, GPOs, or the entire environment from backup.

## Diagnosis

### Step 1: Identify available backups
```powershell
Get-ChildItem -Path "output\backups" -Directory | Sort-Object Name -Descending
```

### Step 2: Check backup contents
```powershell
$latest = Get-ChildItem -Path "output\backups" -Directory | Sort-Object Name -Descending | Select-Object -First 1
Get-ChildItem -Path $latest.FullName -Recurse | Select-Object FullName, Length
```

### Step 3: Check VM checkpoints
```powershell
# On Hyper-V host:
Get-VMSnapshot -VMName DC01
Get-VMSnapshot -VMName WIN11-CLIENT01
```

## Resolution

### Scenario A: Restore specific GPO
```powershell
.\scripts\09-Restore-Lab.ps1 -BackupPath "output\backups\<timestamp>"
# GPOs are restored via Import-GPO, creates if missing
```

### Scenario B: Restore deleted users
```powershell
.\scripts\09-Restore-Lab.ps1 -BackupPath "output\backups\<timestamp>"
# Users are re-created with temp passwords; ChangePasswordAtLogon=true
```

### Scenario C: Restore from AD Recycle Bin (if enabled)
```powershell
# Check if Recycle Bin is enabled
Get-ADOptionalFeature -Filter 'Name -eq "Recycle Bin Feature"'

# If enabled, restore deleted object:
Get-ADObject -Filter 'isDeleted -eq $true' -IncludeDeletedObjects |
    Where-Object { $_.Name -like '*jdoe*' } |
    Restore-ADObject
```

### Scenario D: Restore entire VM from checkpoint
```powershell
# On Hyper-V host:
Restore-VMSnapshot -VMName DC01 -Name "Pre-Backup-<timestamp>"
# VM must be stopped first if running
```

### Scenario E: Full environment rebuild
1. `hyperv\Provision-All.ps1` — recreate VMs
2. `hyperv\04-Attach-ISO.ps1` — install OS
3. `scripts\01-Setup-DC.ps1` — promote DC
4. `scripts\02-Join-Domain.ps1` — join clients
5. `scripts\03-Configure-GPOs.ps1` — configure GPOs
6. `scripts\09-Restore-Lab.ps1 -BackupPath <backup>` — restore data
7. `scripts\05-Validate-Lab.ps1` — validate

## Verification
```powershell
# Validate the full environment
.\scripts\05-Validate-Lab.ps1

# Verify specific objects
Get-ADUser -Filter * | Measure-Object  # Should match pre-incident count
Get-GPO -All | Select-Object DisplayName  # Should match backup
```

## Prevention
- Run `08-Backup-Lab.ps1` daily (schedule via Task Scheduler)
- Enable AD Recycle Bin for quick object recovery:
  ```powershell
  Enable-ADOptionalFeature -Identity 'Recycle Bin Feature' -Scope ForestOrConfigurationSet -Target homelab.local
  ```
- Create VM checkpoints before any major change
