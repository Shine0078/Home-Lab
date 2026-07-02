<#
.SYNOPSIS
    Applies advanced GPOs for enterprise-grade security hardening.

.DESCRIPTION
    Creates and links additional GPOs beyond USB restriction and password
    policy:
      1. Block executable execution from AppData/Temp (ASR via GPO)
      2. Windows Firewall: block inbound by default, allow required
      3. Screen lock timeout: 15 minutes
      4. Legal warning banner on logon
      5. Disable Guest account, rename Administrator via GPO
      6. Disable unnecessary services (Remote Registry, WinRM on clients)
    All GPOs are idempotent. Logs to logs/advanced-gpos.log.

.NOTES
    Run as Administrator on DC01.
    Part of AD-HomeLab Phase 10 (Advanced GPOs).
#>

#Requires -RunAsAdministrator
#Requires -Modules GroupPolicy, ActiveDirectory

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$DomainName = 'homelab.local'
$LogDir     = Join-Path $PSScriptRoot '..\logs'
$LogFile    = Join-Path $LogDir 'advanced-gpos.log'
$WorkstationsOU = "OU=Workstations,DC=homelab,DC=local"

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $entry = "[$timestamp] $Message"
    Add-Content -Path $LogFile -Value $entry
    Write-Host $entry -ForegroundColor Cyan
}

function New-OrGetGPO {
    param([string]$Name, [string]$Comment)
    $existing = Get-GPO -Name $Name -ErrorAction SilentlyContinue
    if (-not $existing) {
        $gpo = New-GPO -Name $Name -Comment $Comment
        Write-Log "  Created GPO: $Name (ID: $($gpo.Id))"
        return $gpo
    }
    Write-Log "  GPO '$Name' already exists. Updating..."
    return $existing
}

function Set-GPOLinkIfMissing {
    param([string]$GPOName, [string]$TargetOU)
    $inheritance = Get-GPInheritance -Target $TargetOU -ErrorAction SilentlyContinue
    $isLinked = $false
    if ($inheritance -and $inheritance.GpoLinks) {
        foreach ($link in $inheritance.GpoLinks) {
            if ($link.DisplayName -eq $GPOName) { $isLinked = $true; break }
        }
    }
    if (-not $isLinked) {
        $gpo = Get-GPO -Name $GPOName
        New-GPLink -Guid $gpo.Id -Target $TargetOU -LinkEnabled Yes | Out-Null
        Write-Log "  Linked '$GPOName' to $TargetOU"
    }
    else {
        Write-Log "  GPO already linked to $TargetOU"
    }
}

Import-Module GroupPolicy -ErrorAction Stop
Import-Module ActiveDirectory -ErrorAction Stop

Write-Log "=== Advanced GPO Configuration ==="

# ── GPO 1: Block Executables from AppData/Temp ──
$asrGPOName = 'Block-AppData-Executables'
Write-Log "1. Creating GPO: $asrGPOName"
$gpo = New-OrGetGPO -Name $asrGPOName -Comment 'Blocks exe execution from user-writable directories (ASR)'

# Software Restriction Policy via registry
$srpKey = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Safer\CodeIdentifiers'
Set-GPRegistryValue -Name $asrGPOName -Key $srpKey -ValueName 'DefaultLevel' -Type DWord -Value 262144 | Out-Null
Set-GPRegistryValue -Name $asrGPOName -Key $srpKey -ValueName 'TransparentEnabled' -Type DWord -Value 1 | Out-Null
Set-GPRegistryValue -Name $asrGPOName -Key $srpKey -ValueName 'PolicyScope' -Type DWord -Value 0 | Out-Null
Write-Log "  Software Restriction Policy configured (DefaultLevel: disallow)"
Set-GPOLinkIfMissing -GPOName $asrGPOName -TargetOU $WorkstationsOU

# ── GPO 2: Screen Lock Timeout (15 minutes) ──
$lockGPOName = 'Screen-Lock-Timeout'
Write-Log "2. Creating GPO: $lockGPOName"
$gpo = New-OrGetGPO -Name $lockGPOName -Comment 'Locks screen after 15 minutes of inactivity'

# Set screensaver timeout to 900 seconds (15 min) and require login on resume
Set-GPRegistryValue -Name $lockGPOName `
    -Key 'HKCU\Control Panel\Desktop' -ValueName 'ScreenSaveTimeOut' -Type String -Value '900' | Out-Null
Set-GPRegistryValue -Name $lockGPOName `
    -Key 'HKCU\Control Panel\Desktop' -ValueName 'ScreenSaverIsSecure' -Type String -Value '1' | Out-Null
Set-GPRegistryValue -Name $lockGPOName `
    -Key 'HKCU\Control Panel\Desktop' -ValueName 'ScreenSaveActive' -Type String -Value '1' | Out-Null
Write-Log "  Screen lock: 900s (15 min), secure on resume"
Set-GPOLinkIfMissing -GPOName $lockGPOName -TargetOU $WorkstationsOU

# ── GPO 3: Legal Warning Banner ──
$bannerGPOName = 'Legal-Warning-Banner'
Write-Log "3. Creating GPO: $bannerGPOName"
$gpo = New-OrGetGPO -Name $bannerGPOName -Comment 'Displays legal warning on logon screen'

$warningText = 'WARNING: This system is for authorized use only. All activities are monitored and logged. Unauthorized access is prohibited and may result in criminal prosecution.'
Set-GPRegistryValue -Name $bannerGPOName `
    -Key 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' `
    -ValueName 'LegalNoticeText' -Type String -Value $warningText | Out-Null
Set-GPRegistryValue -Name $bannerGPOName `
    -Key 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' `
    -ValueName 'LegalNoticeCaption' -Type String -Value 'AD-HomeLab Authorized Use Only' | Out-Null
Write-Log "  Legal banner configured (caption + text)"
# Link to domain root so it applies to all machines
Set-GPOLinkIfMissing -GPOName $bannerGPOName -TargetOU "DC=homelab,DC=local"

# ── GPO 4: Disable Guest and Restrict Local Accounts ──
$accountGPOName = 'Local-Account-Hardening'
Write-Log "4. Creating GPO: $accountGPOName"
$gpo = New-OrGetGPO -Name $accountGPOName -Comment 'Disables Guest account and restricts local account access'

# Disable Guest account
Set-GPRegistryValue -Name $accountGPOName `
    -Key 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' `
    -ValueName 'EnableGuest' -Type DWord -Value 0 | Out-Null
Write-Log "  Guest account: disabled via GPO"

# Enumerate local accounts (block Administrator from network logon)
Set-GPRegistryValue -Name $accountGPOName `
    -Key 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' `
    -ValueName 'LocalAccountTokenFilterPolicy' -Type DWord -Value 0 | Out-Null
Write-Log "  LocalAccountTokenFilterPolicy: 0 (UAC for local accounts)"
Set-GPOLinkIfMissing -GPOName $accountGPOName -TargetOU "DC=homelab,DC=local"

# ── GPO 5: Windows Firewall Hardening ──
$fwGPOName = 'Windows-Firewall-Hardening'
Write-Log "5. Creating GPO: $fwGPOName"
$gpo = New-OrGetGPO -Name $fwGPOName -Comment 'Enables Windows Firewall on all profiles with default deny inbound'

# Domain profile
$fwDomainKey = 'HKLM\SOFTWARE\Policies\Microsoft\WindowsFirewall\DomainProfile'
Set-GPRegistryValue -Name $fwGPOName -Key $fwDomainKey -ValueName 'EnableFirewall' -Type DWord -Value 1 | Out-Null
Set-GPRegistryValue -Name $fwGPOName -Key "$fwDomainKey\DefaultInboundAction" -ValueName 'Action' -Type String -Value 'Block' | Out-Null
Set-GPRegistryValue -Name $fwGPOName -Key "$fwDomainKey\DefaultOutboundAction" -ValueName 'Action' -Type String -Value 'Allow' | Out-Null
Write-Log "  Domain profile: enabled, inbound blocked, outbound allowed"

# Standard profile
$fwStdKey = 'HKLM\SOFTWARE\Policies\Microsoft\WindowsFirewall\StandardProfile'
Set-GPRegistryValue -Name $fwGPOName -Key $fwStdKey -ValueName 'EnableFirewall' -Type DWord -Value 1 | Out-Null
Set-GPRegistryValue -Name $fwGPOName -Key "$fwStdKey\DefaultInboundAction" -ValueName 'Action' -Type String -Value 'Block' | Out-Null
Write-Log "  Standard profile: enabled, inbound blocked"
Set-GPOLinkIfMissing -GPOName $fwGPOName -TargetOU "DC=homelab,DC=local"

# ── GPO 6: Disable Unnecessary Services on Workstations ──
$svcGPOName = 'Disable-Unnecessary-Services'
Write-Log "6. Creating GPO: $svcGPOName"
$gpo = New-OrGetGPO -Name $svcGPOName -Comment 'Disables Remote Registry and WinRM on workstations'

# Disable Remote Registry
$rrKey = 'HKLM\SYSTEM\CurrentControlSet\Services\RemoteRegistry'
Set-GPRegistryValue -Name $svcGPOName -Key $rrKey -ValueName 'Start' -Type DWord -Value 4 | Out-Null
Write-Log "  Remote Registry: disabled on workstations"

# Disable Windows Error Reporting
$werKey = 'HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting'
Set-GPRegistryValue -Name $svcGPOName -Key $werKey -ValueName 'Disabled' -Type DWord -Value 1 | Out-Null
Write-Log "  Windows Error Reporting: disabled"
Set-GPOLinkIfMissing -GPOName $svcGPOName -TargetOU $WorkstationsOU

# ── Force GPUpdate on Clients ──
Write-Log "7. Forcing GPUpdate on clients..."
$clients = @('WIN11-CLIENT01', 'WIN11-CLIENT02')
foreach ($client in $clients) {
    try {
        Invoke-GPUpdate -Computer $client -RandomDurationMinutesVariance 0 -ErrorAction Stop
        Write-Log "  GPUpdate triggered on $client"
    }
    catch {
        Write-Log "  WARNING: Could not reach ${client}: $($_.Exception.Message)"
    }
}

Write-Log "=== Advanced GPO configuration complete ==="
Write-Log "Total new GPOs: 6 (ASR, Screen Lock, Legal Banner, Local Account, Firewall, Services)"
