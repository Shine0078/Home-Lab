<#
.SYNOPSIS
    Joins a Windows client to the homelab.local domain.

.DESCRIPTION
    Run ON each client VM after OS installation. Sets DNS to point at DC01,
    joins homelab.local, places computer in OU=Workstations, renames per
    hostname, and handles reboot with a resume flag file.

.PARAMETER TargetDC
    IP or hostname of the domain controller. Default: 10.0.0.10

.PARAMETER DomainName
    FQDN of the domain. Default: homelab.local

.NOTES
    Run as Administrator on each client.
    Part of AD-HomeLab Phase 3.
#>

#Requires -RunAsAdministrator

param(
    [string]$TargetDC     = '10.0.0.10',
    [string]$DomainName   = 'homelab.local',
    [string]$TargetHost   = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$LogDir  = Join-Path $PSScriptRoot '..\logs'
$LogFile = Join-Path $LogDir 'join-domain.log'
$FlagFile = Join-Path $LogDir 'domain-join-done.flag'

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $entry = "[$timestamp] $Message"
    Add-Content -Path $LogFile -Value $entry
    Write-Host $entry -ForegroundColor Cyan
}

# Auto-detect hostname if not provided
if (-not $TargetHost) {
    $TargetHost = if ($env:COMPUTERNAME -like 'DESKTOP-*' -or $env:COMPUTERNAME -like 'WIN-*') {
        'WIN11-CLIENT01'  # default; user should pass correct name
    } else {
        $env:COMPUTERNAME
    }
    Write-Log "Auto-detected hostname: $TargetHost (pass -TargetHost to override)"
}

# ── Step 1: Check if already domain-joined ──
$computerSystem = Get-CimInstance Win32_ComputerSystem
if ($computerSystem.PartOfDomain) {
    Write-Log "Computer is already domain-joined to $($computerSystem.Domain)."
    if (Test-Path $FlagFile) {
        Write-Log "Domain join already completed. Skipping."
        exit 0
    }
}

# ── Step 2: Set DNS to DC01 ──
Write-Log "Setting DNS to $TargetDC..."
$adapter = Get-NetAdapter -Physical | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
if (-not $adapter) { throw "No active network adapter found." }

Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses $TargetDC
Write-Log "DNS set to $TargetDC on $($adapter.Name)."

# ── Step 3: Rename Computer (before domain join) ──
if ($env:COMPUTERNAME -ne $TargetHost) {
    Write-Log "Renaming computer from '$($env:COMPUTERNAME)' to '$TargetHost'..."
    Rename-Computer -NewName $TargetHost -Force
    Write-Log "Computer renamed. Reboot required before domain join."
    $scriptPath = $MyInvocation.MyCommand.Path
    $argString = "-ExecutionPolicy Bypass -File `"$scriptPath`" -TargetHost $TargetHost -TargetDC $TargetDC -DomainName $DomainName"
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $argString
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    Register-ScheduledTask -TaskName 'AD-HomeLab-Resume-DomainJoin' -Action $action -Trigger $trigger -RunLevel Highest -Force | Out-Null
    Write-Log "Scheduled task created to resume domain join after reboot."
    Restart-Computer -Force
    exit 0
}

# ── Step 4: Join Domain ──
Write-Log "Joining domain $DomainName..."
$credential = Get-Credential -Message "Enter domain admin credentials for $DomainName"
$ouPath = "OU=Workstations,DC=homelab,DC=local"

try {
    Add-Computer -DomainName $DomainName `
        -Credential $credential `
        -OUPath $ouPath `
        -NewName $TargetHost `
        -Force `
        -Options PasswordWithProtectedComputer
    Write-Log "Successfully joined $DomainName and placed in $ouPath."
}
catch {
    Write-Log "ERROR joining domain: $($_.Exception.Message)"
    throw
}

# ── Step 5: Cleanup and Reboot ──
Unregister-ScheduledTask -TaskName 'AD-HomeLab-Resume-DomainJoin' -Confirm:$false -ErrorAction SilentlyContinue
New-Item -Path $FlagFile -ItemType File -Force | Out-Null
Write-Log "Domain join complete. Rebooting..."
Restart-Computer -Force
