# RB-005: User Account Locked Out

## Symptom
A user reports they cannot log in — "The referenced account is currently locked out and may not be logged on to."

## Diagnosis

### Step 1: Check lockout status
```powershell
# On DC01:
Search-ADAccount -LockedOut | Select-Object Name, SamAccountName, LastLogonDate
```

### Step 2: Identify the source of bad passwords
```powershell
# On DC01: Check security event log for Event ID 4740 (lockout) and 4625 (failed logon)
Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4740} -MaxEvents 10 |
    Select-Object TimeCreated, Message
Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4625} -MaxEvents 20 |
    Select-Object TimeCreated, @{N='CallerComputer';E={$_.Properties[18].Value}}
```

### Step 3: Check bad password count
```powershell
Get-ADUser -Identity 'jdoe' -Properties badPwdCount, badPasswordTime, lockoutTime |
    Select-Object SamAccountName, badPwdCount, badPasswordTime, lockoutTime
```

## Resolution

### Fix 1: Unlock the account
```powershell
Unlock-ADAccount -Identity 'jdoe'
```

### Fix 2: Reset password (if user forgot it)
```powershell
$newPassword = ConvertTo-SecureString 'NewP@ssw0rd123!' -AsPlainText -Force
Set-ADAccountPassword -Identity 'jdoe' -NewPassword $newPassword
Unlock-ADAccount -Identity 'jdoe'
```

### Fix 3: Identify and stop the source
Common causes:
- Mobile device with old password (cached credential)
- Mapped drive with old password
- Service running under user account with old password
- RDP session with saved credentials

Check for cached credentials on the user's machine:
```powershell
# On the user's computer:
cmdkey /list
```

## Verification
```powershell
Get-ADUser -Identity 'jdoe' -Properties lockoutTime, badPwdCount |
    Select-Object SamAccountName, lockoutTime, badPwdCount
# lockoutTime should be 0, badPwdCount should be 0
```

## Prevention
- Set reasonable lockout threshold (5 attempts in this lab)
- Monitor Event ID 4740 via WEF (configured by 07-Setup-Monitoring.ps1)
- Educate users to update cached credentials after password changes
