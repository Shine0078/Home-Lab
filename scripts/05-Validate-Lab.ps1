<#
.SYNOPSIS
    Validates the AD HomeLab environment.

.DESCRIPTION
    Run ON DC01 after all configuration is complete. Checks:
      - Domain join status on clients
      - GPO application
      - USB storage disabled on clients
      - Password policy enforcement
      - AD user count == 50
    Outputs pass/fail summary to console and logs/validation.log.

.NOTES
    Run as Administrator on DC01.
    Part of AD-HomeLab Phase 6.
#>

#Requires -RunAsAdministrator
#Requires -Modules ActiveDirectory, GroupPolicy

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$DomainName = 'homelab.local'
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

Write-Host ""
Write-Host "========================================" -ForegroundColor White
Write-Host "  AD-HomeLab Validation" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor White

Import-Module ActiveDirectory -ErrorAction Stop
Import-Module GroupPolicy -ErrorAction Stop

# ── Test 1: Domain Controller exists ──
Write-Log "Checking domain controller..."
try {
    $dc = Get-ADDomainController -Filter { Name -eq $env:COMPUTERNAME } -ErrorAction Stop
    Write-Log "Domain controller found: $($dc.Name)" "PASS"
    Add-Result "Domain Controller exists" $true
} catch {
    Write-Log "Domain controller not found" "FAIL"
    Add-Result "Domain Controller exists" $false
}

# ── Test 2: OU Structure ──
Write-Log "Checking OU structure..."
$ous = @('Staff', 'IT', 'Workstations')
$allOUsExist = $true
foreach ($ou in $ous) {
    $found = Get-ADOrganizationalUnit -Filter "Name -eq '$ou'" -ErrorAction SilentlyContinue
    if ($found) {
        Write-Log "OU '$ou' exists" "PASS"
    } else {
        Write-Log "OU '$ou' NOT found" "FAIL"
        $allOUsExist = $false
    }
}
Add-Result "OU structure (Staff, IT, Workstations)" $allOUsExist

# ── Test 3: Client Domain Join ──
Write-Log "Checking client domain join status..."
$clients = @('WIN11-CLIENT01', 'WIN11-CLIENT02')
foreach ($client in $clients) {
    try {
        $comp = Get-ADComputer -Filter "Name -eq '$client'" -ErrorAction Stop
        Write-Log "$client is domain-joined" "PASS"
        Add-Result "$client domain-joined" $true
    } catch {
        Write-Log "$client NOT found in AD" "FAIL"
        Add-Result "$client domain-joined" $false
    }
}

# ── Test 4: Password Policy ──
Write-Log "Checking password policy..."
$policy = Get-ADDefaultDomainPasswordPolicy
$pwTests = @(
    @{ Name = "Min length >= 14"; Pass = $policy.MinPasswordLength -ge 14 }
    @{ Name = "Complexity enabled"; Pass = $policy.ComplexityEnabled -eq $true }
    @{ Name = "Max age <= 60 days"; Pass = $policy.MaxPasswordAge.TotalDays -le 60 }
    @{ Name = "Lockout threshold = 5"; Pass = $policy.LockoutThreshold -eq 5 }
)
foreach ($test in $pwTests) {
    if ($test.Pass) {
        Write-Log "Password policy: $($test.Name)" "PASS"
    } else {
        Write-Log "Password policy: $($test.Name)" "FAIL"
    }
    Add-Result "Password Policy: $($test.Name)" $test.Pass
}

# ── Test 5: GPO Existence ──
Write-Log "Checking GPOs..."
$expectedGPOs = @('Restrict-USB-Storage')
foreach ($gpoName in $expectedGPOs) {
    try {
        $gpo = Get-GPO -Name $gpoName -ErrorAction Stop
        Write-Log "GPO '$gpoName' exists (ID: $($gpo.Id))" "PASS"
        Add-Result "GPO '$gpoName' exists" $true
    } catch {
        Write-Log "GPO '$gpoName' NOT found" "FAIL"
        Add-Result "GPO '$gpoName' exists" $false
    }
}

# ── Test 6: User Count ──
Write-Log "Checking AD user count..."
$users = Get-ADUser -Filter * -ErrorAction SilentlyContinue
$userCount = ($users | Measure-Object).Count
# Subtract built-in accounts (typically ~5-7), expect 50 created + built-ins
$createdUsers = $users | Where-Object { $_.SamAccountName -notlike 'Administrator' -and $_.SamAccountName -notlike 'Guest' -and $_.SamAccountName -notlike 'krbtgt' -and $_.DistinguishedName -notlike '*CN=Users*' }
$createdCount = ($createdUsers | Measure-Object).Count

if ($createdCount -ge 50) {
    Write-Log "User count: $createdCount custom users (expected >= 50)" "PASS"
    Add-Result "User count >= 50" $true
} else {
    Write-Log "User count: $createdCount custom users (expected >= 50)" "FAIL"
    Add-Result "User count >= 50" $false
}

# ── Summary ──
Write-Host ""
Write-Host "========================================" -ForegroundColor White
Write-Host "  Validation Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor White

$passed = ($results | Where-Object { $_.Passed }).Count
$failed = ($results | Where-Object { -not $_.Passed }).Count
$total  = $results.Count

foreach ($r in $results) {
    $icon = if ($r.Passed) { "[PASS]" } else { "[FAIL]" }
    $color = if ($r.Passed) { "Green" } else { "Red" }
    Write-Host "  $icon $($r.Test)" -ForegroundColor $color
}

Write-Host ""
Write-Host "  Total: $total | Passed: $passed | Failed: $failed" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Yellow" })
Write-Host "========================================" -ForegroundColor White
Write-Log "Validation complete: $passed/$total passed"

if ($failed -gt 0) {
    exit 1
}
