<#
.SYNOPSIS
    Validates the AD HomeLab environment.

.DESCRIPTION
    Run ON DC01 after all configuration is complete. Checks:
      - Domain controller operational
      - OU structure exists (Staff, IT, Workstations)
      - Both clients domain-joined in AD
      - GPO existence and link status
      - USB storage restriction GPO registry value
      - Password policy enforcement (length, complexity, lockout)
      - AD user count == 50
      - gpresult output on a reachable client
    Outputs pass/fail summary to console and logs/validation.log.

.NOTES
    Run as Administrator on DC01.
    Part of AD-HomeLab Phase 6.
#>

#Requires -RunAsAdministrator
#Requires -Modules ActiveDirectory, GroupPolicy

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$LogDir     = Join-Path $PSScriptRoot '..\logs'
$LogFile    = Join-Path $LogDir 'validation.log'

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $entry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $entry
    switch ($Level) {
        'PASS'  { Write-Host "  [PASS] $Message" -ForegroundColor Green }
        'FAIL'  { Write-Host "  [FAIL] $Message" -ForegroundColor Red }
        'WARN'  { Write-Host "  [WARN] $Message" -ForegroundColor Yellow }
        default { Write-Host "  $Message" -ForegroundColor Cyan }
    }
}

$results = [System.Collections.ArrayList]::new()

function Add-Result {
    param([string]$TestName, [bool]$Passed)
    [void]$results.Add([PSCustomObject]@{ Test = $TestName; Passed = $Passed })
}

Write-Output ""
Write-Host "========================================" -ForegroundColor White
Write-Host "  AD-HomeLab Validation" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor White

Import-Module ActiveDirectory -ErrorAction Stop
Import-Module GroupPolicy -ErrorAction Stop

# â”€â”€ Test 1: Domain Controller exists â”€â”€
Write-Log "Checking domain controller..."
try {
    $dc = Get-ADDomainController -Filter * -ErrorAction Stop | Where-Object { $_.HostName -like "*$env:COMPUTERNAME*" }
    if ($dc) {
        Write-Log "Domain controller found: $($dc.HostName)" 'PASS'
        Add-Result "Domain Controller exists" $true
    } else {
        Write-Log "Domain controller not found for $env:COMPUTERNAME" 'FAIL'
        Add-Result "Domain Controller exists" $false
    }
} catch {
    Write-Log "Domain controller check failed: $($_.Exception.Message)" 'FAIL'
    Add-Result "Domain Controller exists" $false
}

# â”€â”€ Test 2: OU Structure â”€â”€
Write-Log "Checking OU structure..."
$ous = @('Staff', 'IT', 'Workstations')
$allOUsExist = $true
foreach ($ou in $ous) {
    $found = Get-ADOrganizationalUnit -Filter "Name -eq '$ou'" -ErrorAction SilentlyContinue
    if ($found) {
        Write-Log "OU '$ou' exists" 'PASS'
    } else {
        Write-Log "OU '$ou' NOT found" 'FAIL'
        $allOUsExist = $false
    }
}
Add-Result "OU structure (Staff, IT, Workstations)" $allOUsExist

# â”€â”€ Test 3: Client Domain Join â”€â”€
Write-Log "Checking client domain join status..."
$clients = @('WIN11-CLIENT01', 'WIN11-CLIENT02')
$joinedClients = 0
foreach ($client in $clients) {
    try {
        $comp = Get-ADComputer -Filter "Name -eq '$client'" -ErrorAction Stop
        Write-Log "$client is domain-joined (DN: $($comp.DistinguishedName))" 'PASS'
        Add-Result "$client domain-joined" $true
        $joinedClients++
    } catch {
        Write-Log "$client NOT found in AD" 'FAIL'
        Add-Result "$client domain-joined" $false
    }
}

# â”€â”€ Test 4: Password Policy â”€â”€
Write-Log "Checking password policy..."
$policy = Get-ADDefaultDomainPasswordPolicy -ErrorAction Stop
$pwTests = @(
    @{ Name = "Min length >= 14"; Pass = ($policy.MinPasswordLength -ge 14) }
    @{ Name = "Complexity enabled"; Pass = ($policy.ComplexityEnabled -eq $true) }
    @{ Name = "Max age <= 60 days"; Pass = ($policy.MaxPasswordAge.TotalDays -le 60) }
    @{ Name = "Lockout threshold = 5"; Pass = ($policy.LockoutThreshold -eq 5) }
    @{ Name = "Lockout duration = 15 min"; Pass = ($policy.LockoutDuration.TotalMinutes -le 15) }
)
foreach ($test in $pwTests) {
    if ($test.Pass) {
        Write-Log "Password policy: $($test.Name)" 'PASS'
    } else {
        Write-Log "Password policy: $($test.Name) -- got: $($policy.MinPasswordLength) / $($policy.ComplexityEnabled) / $($policy.MaxPasswordAge.TotalDays) / $($policy.LockoutThreshold) / $($policy.LockoutDuration.TotalMinutes)" 'FAIL'
    }
    Add-Result "Password Policy: $($test.Name)" $test.Pass
}

# â”€â”€ Test 5: GPO Existence and Link â”€â”€
Write-Log "Checking GPOs..."
$expectedGPOs = @('Restrict-USB-Storage')
foreach ($gpoName in $expectedGPOs) {
    try {
        $gpo = Get-GPO -Name $gpoName -ErrorAction Stop
        Write-Log "GPO '$gpoName' exists (ID: $($gpo.Id))" 'PASS'
        Add-Result "GPO '$gpoName' exists" $true

        # Check if linked to OU=Workstations
        $inheritance = Get-GPInheritance -Target "OU=Workstations,DC=homelab,DC=local" -ErrorAction SilentlyContinue
        $isLinked = $false
        if ($inheritance -and $inheritance.GpoLinks) {
            foreach ($link in $inheritance.GpoLinks) {
                if ($link.DisplayName -eq $gpoName) { $isLinked = $true; break }
            }
        }
        if ($isLinked) {
            Write-Log "GPO '$gpoName' is linked to OU=Workstations" 'PASS'
            Add-Result "GPO '$gpoName' linked to Workstations" $true
        } else {
            Write-Log "GPO '$gpoName' NOT linked to OU=Workstations" 'FAIL'
            Add-Result "GPO '$gpoName' linked to Workstations" $false
        }
    } catch {
        Write-Log "GPO '$gpoName' NOT found" 'FAIL'
        Add-Result "GPO '$gpoName' exists" $false
    }
}

# â”€â”€ Test 6: USB Storage Registry Value in GPO â”€â”€
Write-Log "Checking USB storage restriction GPO registry value..."
try {
    $regValue = Get-GPRegistryValue -Name 'Restrict-USB-Storage' `
        -Key 'HKLM\SYSTEM\CurrentControlSet\Services\USBSTOR' `
        -ValueName 'Start' -ErrorAction Stop
    if ($regValue.Value -eq 4) {
        Write-Log "USBSTOR Start = 4 (disabled) in GPO" 'PASS'
        Add-Result "USB storage disabled via GPO registry" $true
    } else {
        Write-Log "USBSTOR Start = $($regValue.Value) (expected 4)" 'FAIL'
        Add-Result "USB storage disabled via GPO registry" $false
    }
} catch {
    Write-Log "Could not read USBSTOR registry value from GPO" 'FAIL'
    Add-Result "USB storage disabled via GPO registry" $false
}

# â”€â”€ Test 7: USB Storage on Client (if reachable) â”€â”€
Write-Log "Checking USB storage on client via remote registry..."
if ($joinedClients -gt 0) {
    $testClient = $clients[0]
    try {
        $usbStart = Invoke-Command -ComputerName $testClient -ScriptBlock {
            (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\USBSTOR' -Name 'Start' -ErrorAction SilentlyContinue).Start
        } -ErrorAction Stop

        if ($usbStart -eq 4) {
            Write-Log "USB storage disabled on $testClient (USBSTOR Start = 4)" 'PASS'
            Add-Result "USB storage disabled on client" $true
        } else {
            Write-Log "USB storage NOT disabled on $testClient (Start = $usbStart) -- GPO may not have applied yet" 'WARN'
            Add-Result "USB storage disabled on client" $false
        }
    } catch {
        Write-Log "Could not check USB storage on $testClient (client not reachable via PSRemoting)" 'WARN'
        Add-Result "USB storage disabled on client" $false
    }
} else {
    Write-Log "No clients joined; skipping client USB check" 'WARN'
    Add-Result "USB storage disabled on client" $false
}

# â”€â”€ Test 8: GPO Application on Client (gpresult) â”€â”€
Write-Log "Checking GPO application on client..."
if ($joinedClients -gt 0) {
    $testClient = $clients[0]
    try {
        $gpResult = Invoke-Command -ComputerName $testClient -ScriptBlock {
            gpresult /r 2>&1 | Out-String
        } -ErrorAction Stop

        if ($gpResult -match 'Restrict-USB-Storage') {
            Write-Log "GPO 'Restrict-USB-Storage' found in gpresult on $testClient" 'PASS'
            Add-Result "GPO applied on client (gpresult)" $true
        } else {
            Write-Log "GPO 'Restrict-USB-Storage' NOT found in gpresult on $testClient -- may need gpupdate /force" 'WARN'
            Add-Result "GPO applied on client (gpresult)" $false
        }
    } catch {
        Write-Log "Could not run gpresult on $testClient" 'WARN'
        Add-Result "GPO applied on client (gpresult)" $false
    }
} else {
    Write-Log "No clients joined; skipping gpresult check" 'WARN'
    Add-Result "GPO applied on client (gpresult)" $false
}

# â”€â”€ Test 9: User Count â”€â”€
Write-Log "Checking AD user count..."
$allUsers = Get-ADUser -Filter * -ErrorAction SilentlyContinue
$customUsers = $allUsers | Where-Object {
    $_.DistinguishedName -match 'OU=Staff|OU=IT'
}
$customCount = ($customUsers | Measure-Object).Count

if ($customCount -ge 50) {
    Write-Log "User count: $customCount custom users in OU=Staff and OU=IT (expected >= 50)" 'PASS'
    Add-Result "User count >= 50" $true
} else {
    Write-Log "User count: $customCount custom users (expected >= 50)" 'FAIL'
    Add-Result "User count >= 50" $false
}

# â”€â”€ Summary â”€â”€
Write-Output ""
Write-Host "========================================" -ForegroundColor White
Write-Host "  Validation Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor White

$passed = ($results | Where-Object { $_.Passed }).Count
$failed = ($results | Where-Object { -not $_.Passed }).Count
$total  = $results.Count

foreach ($r in $results) {
    $icon = if ($r.Passed) { '[PASS]' } else { '[FAIL]' }
    $color = if ($r.Passed) { 'Green' } else { 'Red' }
    Write-Host "  $icon $($r.Test)" -ForegroundColor $color
}

Write-Output ""
Write-Host "  Total: $total | Passed: $passed | Failed: $failed" -ForegroundColor $(if ($failed -eq 0) { 'Green' } else { 'Yellow' })
Write-Host "========================================" -ForegroundColor White
Write-Log "Validation complete: $passed/$total passed"

if ($failed -gt 0) {
    exit 1
}
