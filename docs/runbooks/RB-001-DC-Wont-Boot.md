# RB-001: DC01 Won't Boot

## Symptom
DC01 virtual machine fails to start or boots to a blue screen / recovery environment.

## Diagnosis

### Step 1: Check VM state in Hyper-V
```powershell
Get-VM -Name DC01 | Select-Object Name, State, HealthCheck
```

### Step 2: Check Hyper-V event logs
```powershell
Get-WinEvent -LogName 'Microsoft-Windows-Hyper-V-Worker-Admin' -MaxEvents 10 |
    Where-Object { $_.Message -like '*DC01*' }
```

### Step 3: Boot into Safe Mode
1. In Hyper-V Manager, connect to DC01
2. Press F8 during boot or use `bcdedit /set safeboot minimal` from recovery
3. If Safe Mode works, disable recently installed drivers/services

## Resolution

### Scenario A: Corrupted AD database
1. Boot to DSRM (Directory Services Restore Mode): press F8, select DSRM
2. Log in with DSRM administrator account (set during DC promotion)
3. Run `ntdsutil` to repair:
   ```
   ntdsutil
   activate instance ntds
   files
   recover
   quit
   quit
   ```
4. Reboot normally

### Scenario B: VHDX corruption
1. On Hyper-V host: `Repair-VHD -Path "C:\path\to\DC01.vhdx"`
2. If repair fails, restore from VM checkpoint:
   ```powershell
   Restore-VMSnapshot -VMName DC01 -Name "Pre-Backup-<timestamp>"
   ```

### Scenario C: Blue screen after update
1. Boot to Windows Recovery Environment
2. Uninstall latest update: `dism /image:C:\ /cleanup-image /revertpendingactions`
3. Reboot

## Verification
```powershell
# Verify AD is healthy
Get-ADDomain | Select-Object Name, DNSRoot
repadmin /showrepl
Get-Service NTDS, DNS, DHCPServer | Select-Object Name, Status
```

## Prevention
- Create VM checkpoints before updates: `Checkpoint-VM -Name DC01 -SnapshotName "Pre-Update"`
- Run `08-Backup-Lab.ps1` weekly
