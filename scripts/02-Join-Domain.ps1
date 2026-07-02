<#
.SYNOPSIS
    Joins a Windows client to the homelab.local domain.

.DESCRIPTION
    Run ON each client VM after OS installation. Sets DNS to point at DC01,
    renames the computer to the specified target hostname, joins homelab.local,
    places the computer object in OU=Workstations, and handles reboots
    with a resume flag file and scheduled task.

.PARAMETER TargetHost
    REQUIRED. The desired hostname for this client (WIN11-CLIENT01 or
    WIN11-CLIENT02). Must be specified explicitly to prevent naming collisions.

.PARAMETER TargetDC
    IP address or hostname of the domain controller. Default: 10.0.0.10

.PARAMETER DomainName
    FQDN of the domain. Default: homelab.local

.NOTES
    Run as Administrator on each client.
    Part of AD-HomeLab Phase 3.
#>

#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory = $true, HelpMessage = 'Desired hostname: WIN11-CLIENT01 or WIN11-CLIENT02')]
    [ValidateSet('WIN11-CLIENT01', 'WIN11-CLIENT02')]
    [string]$TargetHost,

    [string]$TargetDC   = '10.0.0.10',
    [string]$DomainName = 'homelab.local'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$LogDir   = Join-Path $PSScriptRoot '..\logs'
$LogFile  = Join-Path $LogDir 'join-domain.log'
$FlagFile = Join-Path $LogDir "$TargetHost-domain-join-done.flag"

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $entry = "[$timestamp] $Message"
    Add-Content -Path $LogFile -Value $entry
    Write-Output $entry -ForegroundColor Cyan
}

Write-Log "=== Domain Join Script: $TargetHost ==="

# â”€â”€ Step 1: Check if already domain-joined AND flag exists â”€â”€
$computerSystem = Get-CimInstance Win32_ComputerSystem
if ($computerSystem.PartOfDomain -and (Test-Path $FlagFile)) {
    Write-Log "Computer already domain-joined to $($computerSystem.Domain) and flag file exists. Nothing to do."
    exit 0
}
if ($computerSystem.PartOfDomain -and -not (Test-Path $FlagFile)) {
    Write-Log "Computer is domain-joined but flag file is missing. Creating flag and exiting."
    New-Item -Path $FlagFile -ItemType File -Force | Out-Null
    exit 0
}

# â”€â”€ Step 2: Set DNS to DC01 â”€â”€
Write-Log "Setting DNS to $TargetDC..."
$adapter = Get-NetAdapter -Physical | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
if (-not $adapter) { throw "No active network adapter found." }

Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses $TargetDC
Write-Log "DNS set to $TargetDC on $($adapter.Name)."

# Verify DNS resolution before proceeding
Write-Log "Verifying DNS resolution for $DomainName..."
$dnsResolve = Resolve-DnsName -Name $DomainName -Server $TargetDC -ErrorAction SilentlyContinue
if (-not $dnsResolve) {
    Write-Log "ERROR: Cannot resolve $DomainName via DNS server $TargetDC. Verify DC01 is running."
    throw "DNS resolution failed for $DomainName"
}
Write-Log "DNS resolution successful."

# â”€â”€ Step 3: Rename Computer (before domain join) â”€â”€
if ($env:COMPUTERNAME -ne $TargetHost) {
    Write-Log "Renaming computer from '$($env:COMPUTERNAME)' to '$TargetHost'..."
    Rename-Computer -NewName $TargetHost -Force

    $scriptPath = $MyInvocation.MyCommand.Path
    $argString = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -TargetHost $TargetHost -TargetDC $TargetDC -DomainName $DomainName"
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $argString
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    Register-ScheduledTask -TaskName 'AD-HomeLab-Resume-DomainJoin' -Action $action -Trigger $trigger -Principal $principal -Force | Out-Null
    Write-Log "Scheduled task created to resume domain join after reboot."
    Write-Log "Rebooting now..."
    Restart-Computer -Force
    exit 0
}

# â”€â”€ Step 4: Join Domain â”€â”€
Write-Log "Joining domain $DomainName..."
$credential = Get-Credential -Message "Enter domain admin credentials for $DomainName (use HOMELAB\Administrator)"
$ouPath = "OU=Workstations,DC=homelab,DC=local"

try {
    Add-Computer -DomainName $DomainName `
        -Credential $credential `
        -OUPath $ouPath `
        -NewName $TargetHost `
        -Force `
        -Options JoinWithNewName
    Write-Log "Successfully joined $DomainName and placed in $ouPath."
}
catch {
    Write-Log "ERROR joining domain: $($_.Exception.Message)"
    Write-Log "Troubleshooting:"
    Write-Log "  1. Verify DC01 is online and reachable: Test-Connection $TargetDC"
    Write-Log "  2. Verify DNS: nslookup $DomainName"
    Write-Log "  3. Verify credentials are correct (HOMELAB\Administrator)"
    throw
}

# â”€â”€ Step 5: Cleanup and Reboot â”€â”€
Unregister-ScheduledTask -TaskName 'AD-HomeLab-Resume-DomainJoin' -Confirm:$false -ErrorAction SilentlyContinue
New-Item -Path $FlagFile -ItemType File -Force | Out-Null
Write-Log "Domain join complete for $TargetHost. Rebooting..."
Restart-Computer -Force
