# RB-003: GPO Not Applying on Client

## Symptom
A Group Policy Object is configured on DC01 but not taking effect on a client VM. Examples:
- USB storage still works despite Restrict-USB-Storage GPO
- Password policy not enforced
- Legal banner not appearing

## Diagnosis

### Step 1: Check GPO link on DC01
```powershell
# On DC01:
Get-GPInheritance -Target "OU=Workstations,DC=homelab,DC=local" |
    Select-Object -ExpandProperty GpoLinks
```

### Step 2: Check GPO scope (security filtering)
```powershell
Get-GPO -Name 'Restrict-USB-Storage' | Select-Object DisplayName, Id
Get-GPPermission -Name 'Restrict-USB-Storage' -All | Where-Object { $_.Permission -eq 'GpoApply' }
```

### Step 3: Check if client is in the correct OU
```powershell
# On DC01:
Get-ADComputer -Identity WIN11-CLIENT01 | Select-Object Name, DistinguishedName
```
Expected: `CN=WIN11-CLIENT01,OU=Workstations,DC=homelab,DC=local`

### Step 4: Run gpresult on the client
```powershell
# On the client (as Administrator):
gpresult /r
gpresult /h C:\gpo-report.html
```

### Step 5: Check registry value on client
```powershell
# On the client:
Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\USBSTOR' -Name 'Start'
```
Expected: `4` (if USB restriction GPO is applied)

## Resolution

### Fix 1: Force GPUpdate
```powershell
# On the client:
gpupdate /force
```

### Fix 2: Move computer to correct OU
```powershell
# On DC01:
Get-ADComputer WIN11-CLIENT01 | Move-ADObject -TargetPath "OU=Workstations,DC=homelab,DC=local"
```
Then run `gpupdate /force` on the client.

### Fix 3: Fix security filtering
GPO must have "Authenticated Users" or the specific computer group in Security Filtering:
```powershell
Set-GPPermission -Name 'Restrict-USB-Storage' -PermissionLevel GpoApply -TargetName 'Authenticated Users' -TargetType Group
```

### Fix 4: Check for GPO enforcement/blocking
```powershell
# Check if inheritance is blocked on the OU
Get-GPInheritance -Target "OU=Workstations,DC=homelab,DC=local" | Select-Object InheritanceBlocked
```

### Fix 5: Check WMI filters
```powershell
Get-GPO -Name 'Restrict-USB-Storage' | Select-Object WmiFilter
```
If a WMI filter is applied and the client doesn't match, the GPO won't apply.

## Verification
```powershell
# On the client:
gpresult /r | Select-String "Restrict-USB-Storage"
# Should show "Applied Group Policies" section with the GPO name
```

## Prevention
- Run `scripts/05-Validate-Lab.ps1` which checks GPO application via gpresult
- Use the `Set-GPOLinkIfMissing` function from the ADHomeLab module to verify links
