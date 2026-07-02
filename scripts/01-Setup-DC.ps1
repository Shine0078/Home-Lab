<#
.SYNOPSIS
    Configures the Domain Controller (DC01) for homelab.local.

.DESCRIPTION
    Run ON DC01 after OS installation. Sets static IP, renames computer,
    installs AD DS + DNS, promotes to new forest homelab.local, and creates
    OU structure (Staff, IT, Workstations). Idempotent — checks state
    before each action. Logs to logs/setup-dc.log.

.NOTES
    Run as Administrator on DC01.
    Part of AD-HomeLab Phase 2.
#>

#Requires -RunAsAdministrator

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$DomainName   = 'homelab.local'
$DomainNetBIOS = 'HOMELAB'
$TargetHost   = 'DC01'
$StaticIP     = '10.0.0.10'
$PrefixLength = 24
$Gateway      = '10.0.0.1'
$DNSPrimary   = '127.0.0.1'

$LogDir  = Join-Path $PSScriptRoot '..\logs'
$LogFile = Join-Path $LogDir 'setup-dc.log'

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $entry = "[$timestamp] $Message"
    Add-Content -Path $LogFile -Value $entry
    Write-Host $entry -ForegroundColor Cyan
}

function Test-ADReady {
    try {
        $null = Get-ADDomain -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

# ── Step 1: Rename Computer ──
$currentName = $env:COMPUTERNAME
if ($currentName -ne $TargetHost) {
    Write-Log "Renaming computer from '$currentName' to '$TargetHost'..."
    Rename-Computer -NewName $TargetHost -Force
    Write-Log "Computer renamed. Reboot required before continuing."
    Write-Log "After reboot, re-run this script."
    # Schedule a scheduled task to resume after reboot
    $scriptPath = $MyInvocation.MyCommand.Path
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-ExecutionPolicy Bypass -File `"$scriptPath`""
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    Register-ScheduledTask -TaskName 'AD-HomeLab-Resume-DC' -Action $action -Trigger $trigger -RunLevel Highest -Force | Out-Null
    Write-Log "Scheduled task 'AD-HomeLab-Resume-DC' created to resume after reboot."
    Restart-Computer -Force
    exit 0
}
else {
    Write-Log "Computer name is already '$TargetHost'."
    # Clean up scheduled task if it exists
    Unregister-ScheduledTask -TaskName 'AD-HomeLab-Resume-DC' -Confirm:$false -ErrorAction SilentlyContinue
}

# ── Step 2: Set Static IP ──
Write-Log "Configuring static IP: $StaticIP/$PrefixLength..."
$adapter = Get-NetAdapter -Physical | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
if (-not $adapter) { throw "No active network adapter found." }

$currentIP = (Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -IPv4Address -ErrorAction SilentlyContinue).IPAddress
if ($currentIP -ne $StaticIP) {
    New-NetIPAddress -InterfaceIndex $adapter.ifIndex -IPAddress $StaticIP -PrefixLength $PrefixLength -DefaultGateway $Gateway -ErrorAction SilentlyContinue | Out-Null
    Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses $DNSPrimary
    Write-Log "Static IP set to $StaticIP on $($adapter.Name)."
}
else {
    Write-Log "IP already configured as $StaticIP."
}

# ── Step 3: Install AD DS + DNS ──
Write-Log "Checking AD DS installation..."
$adDS = Get-WindowsFeature -Name AD-Domain-Services -ErrorAction SilentlyContinue
if ($adDS -and -not $adDS.Installed) {
    Write-Log "Installing AD-Domain-Services..."
    Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools | Out-Null
    Write-Log "AD-Domain-Services installed."
}
else {
    Write-Log "AD-Domain-Services already installed."
}

Write-Log "Checking DNS Server installation..."
$dns = Get-WindowsFeature -Name DNS -ErrorAction SilentlyContinue
if ($dns -and -not $dns.Installed) {
    Write-Log "Installing DNS Server..."
    Install-WindowsFeature -Name DNS -IncludeManagementTools | Out-Null
    Write-Log "DNS Server installed."
}
else {
    Write-Log "DNS Server already installed."
}

# ── Step 4: Promote to Domain Controller ──
if (-not (Test-ADReady)) {
    Write-Log "Promoting to Domain Controller (new forest: $DomainName)..."
    $securePassword = Read-Host -Prompt "Enter DSRM password" -AsSecureString
    Install-ADDSForest `
        -DomainName $DomainName `
        -DomainNetbiosName $DomainNetBIOS `
        -SafeModeAdministratorPassword $securePassword `
        -InstallDNS:$true `
        -NoReboot:$false `
        -Force:$true
    Write-Log "Domain Controller promotion initiated. Server will reboot."
    # After reboot, the DC is ready — OU creation happens next run
    exit 0
}
else {
    Write-Log "Domain controller already promoted. Forest: $DomainName"
}

# ── Step 5: Create OU Structure ──
Write-Log "Ensuring OU structure exists..."
Import-Module ActiveDirectory -ErrorAction Stop

$ous = @('Staff', 'IT', 'Workstations')
foreach ($ou in $ous) {
    $existing = Get-ADOrganizationalUnit -Filter "Name -eq '$ou'" -ErrorAction SilentlyContinue
    if (-not $existing) {
        New-ADOrganizationalUnit -Name $ou -Path "DC=homelab,DC=local" -ProtectedFromAccidentalDeletion $true
        Write-Log "Created OU: $ou"
    }
    else {
        Write-Log "OU '$ou' already exists."
    }
}

# ── Step 6: Create DNS Forwarders ──
Write-Log "Configuring DNS forwarders..."
$forwarders = Get-DnsServerForwarder -ErrorAction SilentlyContinue
if (-not $forwarders -or $forwarders.IPAddress.Count -eq 0) {
    Set-DnsServerForwarder -IPAddress '8.8.8.8', '1.1.1.1' -PassThru | Out-Null
    Write-Log "DNS forwarders set to 8.8.8.8, 1.1.1.1"
}
else {
    Write-Log "DNS forwarders already configured."
}

Write-Log "=== DC01 setup complete ==="
