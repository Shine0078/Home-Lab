<#
.SYNOPSIS
    Configures Group Policy Objects for the homelab.

.DESCRIPTION
    Run ON DC01 after domain is promoted and clients are joined. Creates
    two GPOs:
      - Restrict-USB-Storage: disables USB mass storage on workstations
      - Password Policy: enforces strong password requirements
    Links GPOs to appropriate OUs and forces gpupdate on clients.

.NOTES
    Run as Administrator on DC01.
    Part of AD-HomeLab Phase 4.
#>

#Requires -RunAsAdministrator
#Requires -Modules GroupPolicy, ActiveDirectory

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$DomainName = 'homelab.local'
$LogDir     = Join-Path $PSScriptRoot '..\logs'
$LogFile    = Join-Path $LogDir 'configure-gpos.log'

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $entry = "[$timestamp] $Message"
    Add-Content -Path $LogFile -Value $entry
    Write-Host $entry -ForegroundColor Cyan
}

Import-Module GroupPolicy -ErrorAction Stop
Import-Module ActiveDirectory -ErrorAction Stop

$ouPath = "OU=Workstations,DC=homelab,DC=local"

# â”€â”€ GPO 1: USB Storage Restriction â”€â”€
$usbGPOName = 'Restrict-USB-Storage'
Write-Log "--- Creating GPO: $usbGPOName ---"

$existingUSB = Get-GPO -Name $usbGPOName -ErrorAction SilentlyContinue
if (-not $existingUSB) {
    $gpo = New-GPO -Name $usbGPOName -Comment 'Disables USB mass storage devices on workstations'
    Write-Log "Created GPO: $usbGPOName (ID: $($gpo.Id))"
}
else {
    $gpo = $existingUSB
    Write-Log "GPO '$usbGPOName' already exists. Updating settings..."
}

# Set registry preference: HKLM\SYSTEM\CurrentControlSet\Services\USBSTOR\Start = 4
$regKeyPath = 'HKLM\SYSTEM\CurrentControlSet\Services\USBSTOR'
$regValue = 4

Set-GPRegistryValue -Name $usbGPOName `
    -Key $regKeyPath `
    -ValueName 'Start' `
    -Type DWord `
    -Value $regValue | Out-Null
Write-Log "Registry preference set: $regKeyPath\Start = $regValue"

# Link to OU=Workstations -- check if already linked
$inheritance = Get-GPInheritance -Target $ouPath -ErrorAction SilentlyContinue
$alreadyLinked = $false
if ($inheritance -and $inheritance.GpoLinks) {
    foreach ($link in $inheritance.GpoLinks) {
        if ($link.DisplayName -eq $usbGPOName) {
            $alreadyLinked = $true
            break
        }
    }
}

if (-not $alreadyLinked) {
    New-GPLink -Guid $gpo.Id -Target $ouPath -LinkEnabled Yes | Out-Null
    Write-Log "Linked '$usbGPOName' to $ouPath"
}
else {
    Write-Log "GPO already linked to $ouPath"
}

# â”€â”€ GPO 2: Password Policy â”€â”€
Write-Log "--- Configuring Password Policy ---"

# Password policy via Default Domain Policy using Set-ADDefaultDomainPasswordPolicy
$currentPolicy = Get-ADDefaultDomainPasswordPolicy
Write-Log "Current policy: MinLength=$($currentPolicy.MinPasswordLength), Complexity=$($currentPolicy.ComplexityEnabled), MaxAge=$($currentPolicy.MaxPasswordAge)"

Set-ADDefaultDomainPasswordPolicy `
    -Identity $DomainName `
    -MinPasswordLength 14 `
    -ComplexityEnabled $true `
    -MaxPasswordAge (New-TimeSpan -Days 60) `
    -MinPasswordAge (New-TimeSpan -Days 1) `
    -PasswordHistoryCount 24 `
    -LockoutThreshold 5 `
    -LockoutDuration (New-TimeSpan -Minutes 15) `
    -LockoutObservationWindow (New-TimeSpan -Minutes 15)

Write-Log "Password policy updated:"
Write-Log "  Min length: 14"
Write-Log "  Complexity: Enabled"
Write-Log "  Max age: 60 days"
Write-Log "  Lockout threshold: 5 attempts"
Write-Log "  Lockout duration: 15 minutes"

# â”€â”€ Force GPUpdate on Clients â”€â”€
Write-Log "--- Forcing GPUpdate on clients ---"
$clients = @('WIN11-CLIENT01', 'WIN11-CLIENT02')
foreach ($client in $clients) {
    $reachable = $false
    try {
        $reachable = Test-Connection -ComputerName $client -Count 1 -Quiet -ErrorAction SilentlyContinue
    }
    catch {
        Write-Log "WARNING: Could not test reachability for ${client}: $($_.Exception.Message)"
    }

    if (-not $reachable) {
        Write-Log "WARNING: $client not reachable. Skipping gpupdate. Run 'Invoke-GPUpdate -Computer $client' manually later."
        continue
    }

    try {
        Invoke-GPUpdate -Computer $client -RandomDurationMinutesVariance 0 -ErrorAction Stop
        Write-Log "GPUpdate triggered on $client"
    }
    catch {
        # Fallback: use Invoke-Command to run gpupdate.exe directly
        try {
            Invoke-Command -ComputerName $client -ScriptBlock { gpupdate.exe /force } -ErrorAction Stop
            Write-Log "GPUpdate triggered on $client (via Invoke-Command fallback)"
        }
        catch {
            Write-Log "WARNING: Could not trigger gpupdate on ${client}: $($_.Exception.Message)"
            Write-Log "  Run 'gpupdate /force' manually on ${client}"
        }
    }
}

# â”€â”€ Generate GPO Report â”€â”€
$reportPath = Join-Path $LogDir 'gpo-report.html'
try {
    Get-GPOReport -All -ReportType HTML -Path $reportPath -ErrorAction Stop
    Write-Log "GPO report saved to $reportPath"
}
catch {
    Write-Log "WARNING: Could not generate GPO report: $($_.Exception.Message)"
}

Write-Log "=== GPO configuration complete ==="
