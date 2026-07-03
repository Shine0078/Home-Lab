<#
.SYNOPSIS
    Configures the Domain Controller (DC01) for homelab.local.

.DESCRIPTION
    Run ON DC01 after OS installation. Sets static IP, renames computer,
    installs AD DS + DNS + DHCP, promotes to new forest homelab.local,
    creates OU structure (Staff, IT, Workstations), and configures a DHCP
    scope for the lab network (10.0.0.100-200/24). Idempotent -- checks
    state before each action. Logs to logs/setup-dc.log.

.NOTES
    Run as Administrator on DC01.
    Part of AD-HomeLab Phase 2.
#>

#Requires -RunAsAdministrator

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$DomainName    = 'homelab.local'
$DomainNetBIOS = 'HOMELAB'
$TargetHost    = 'DC01'
$StaticIP      = '10.0.0.10'
$PrefixLength  = 24
$Gateway       = '10.0.0.1'
$DNSPrimary    = '127.0.0.1'

# DHCP scope parameters
$DhcpScopeName   = 'AD-Lab-Scope'
$DhcpStartRange  = '10.0.0.100'
$DhcpEndRange    = '10.0.0.200'
$DhcpSubnetMask  = '255.255.255.0'
$DhcpDnsServer   = '10.0.0.10'
$DhcpRouter      = '10.0.0.1'

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

function Install-FeatureIfMissing {
    param([string]$FeatureName)
    $feature = Get-WindowsFeature -Name $FeatureName -ErrorAction SilentlyContinue
    if (-not $feature) {
        Write-Log "WARNING: Feature '$FeatureName' not found on this edition. Skipping."
        return
    }
    if (-not $feature.Installed) {
        Write-Log "Installing $FeatureName..."
        Install-WindowsFeature -Name $FeatureName -IncludeManagementTools | Out-Null
        Write-Log "$FeatureName installed."
    }
    else {
        Write-Log "$FeatureName already installed."
    }
}

# â”€â”€ Step 1: Rename Computer â”€â”€
$currentName = $env:COMPUTERNAME
if ($currentName -ne $TargetHost) {
    Write-Log "Renaming computer from '$currentName' to '$TargetHost'..."
    Rename-Computer -NewName $TargetHost -Force

    $scriptPath = $MyInvocation.MyCommand.Path
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-ExecutionPolicy Bypass -File `"$scriptPath`""
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User "$env:COMPUTERNAME\Administrator"
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    Register-ScheduledTask -TaskName 'AD-HomeLab-Resume-DC' -Action $action -Trigger $trigger -Principal $principal -Force | Out-Null
    Write-Log "Scheduled task 'AD-HomeLab-Resume-DC' created to resume after reboot."
    Write-Log "Rebooting now. Script will auto-resume on next logon."
    Restart-Computer -Force
    exit 0
}
else {
    Write-Log "Computer name is already '$TargetHost'."
    Unregister-ScheduledTask -TaskName 'AD-HomeLab-Resume-DC' -Confirm:$false -ErrorAction SilentlyContinue
}

# â”€â”€ Step 2: Set Static IP â”€â”€
Write-Log "Configuring static IP: $StaticIP/$PrefixLength..."
$adapter = Get-NetAdapter -Physical | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
if (-not $adapter) { throw "No active network adapter found." }

$currentIPs = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
$hasTargetIP = $false
foreach ($ip in $currentIPs) {
    if ($ip.IPAddress -eq $StaticIP) { $hasTargetIP = $true; break }
}

if (-not $hasTargetIP) {
    # Remove any existing IP configuration on this adapter first
    $existingIPs = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
    foreach ($ip in $existingIPs) {
        if ($ip.PrefixOrigin -eq 'Manual' -or $ip.PrefixOrigin -eq 'DHCP') {
            Remove-NetIPAddress -InterfaceIndex $adapter.ifIndex -IPAddress $ip.IPAddress -Confirm:$false -ErrorAction SilentlyContinue
        }
    }
    $existingGateway = Get-NetRoute -InterfaceIndex $adapter.ifIndex -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue
    if ($existingGateway) {
        Remove-NetRoute -InterfaceIndex $adapter.ifIndex -DestinationPrefix '0.0.0.0/0' -Confirm:$false -ErrorAction SilentlyContinue
    }

    New-NetIPAddress -InterfaceIndex $adapter.ifIndex -IPAddress $StaticIP -PrefixLength $PrefixLength -DefaultGateway $Gateway | Out-Null
    Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses $DNSPrimary
    Write-Log "Static IP set to $StaticIP on $($adapter.Name)."
}
else {
    Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses $DNSPrimary -ErrorAction SilentlyContinue
    Write-Log "IP already configured as $StaticIP."
}

# â”€â”€ Step 3: Install AD DS + DNS + DHCP â”€â”€
Write-Log "--- Installing Windows Features ---"
Install-FeatureIfMissing -FeatureName 'AD-Domain-Services'
Install-FeatureIfMissing -FeatureName 'DNS'
Install-FeatureIfMissing -FeatureName 'DHCP'

# â”€â”€ Step 4: Promote to Domain Controller â”€â”€
if (-not (Test-ADReady)) {
    Write-Log "Promoting to Domain Controller (new forest: $DomainName)..."
    $securePassword = Read-Host -Prompt "Enter DSRM password (min 8 chars)" -AsSecureString
    Install-ADDSForest `
        -DomainName $DomainName `
        -DomainNetbiosName $DomainNetBIOS `
        -SafeModeAdministratorPassword $securePassword `
        -InstallDNS:$true `
        -NoReboot:$false `
        -Force:$true
    Write-Log "Domain Controller promotion initiated. Server will reboot."
    exit 0
}
else {
    Write-Log "Domain controller already promoted. Forest: $DomainName"
}

# â”€â”€ Step 5: Create OU Structure â”€â”€
Write-Log "Ensuring OU structure exists..."
Import-Module ActiveDirectory -ErrorAction Stop

$DomainDN = (Get-ADDomain).DistinguishedName
$ous = @('Staff', 'IT', 'Workstations')
foreach ($ou in $ous) {
    $ouDN = "OU=$ou,$DomainDN"
    $existing = Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$ouDN'" -ErrorAction SilentlyContinue
    if (-not $existing) {
        New-ADOrganizationalUnit -Name $ou -Path $DomainDN -ProtectedFromAccidentalDeletion $true
        Write-Log "Created OU: $ou ($ouDN)"
    }
    else {
        Write-Log "OU '$ou' already exists."
    }
}

# â”€â”€ Step 6: Configure DNS Forwarders â”€â”€
Write-Log "Configuring DNS forwarders..."
$forwarders = Get-DnsServerForwarder -ErrorAction SilentlyContinue
if (-not $forwarders -or $forwarders.IPAddress.Count -eq 0) {
    Set-DnsServerForwarder -IPAddress '8.8.8.8', '1.1.1.1' -PassThru | Out-Null
    Write-Log "DNS forwarders set to 8.8.8.8, 1.1.1.1"
}
else {
    Write-Log "DNS forwarders already configured."
}

# â”€â”€ Step 7: Authorize DHCP and Create Scope â”€â”€
Write-Log "Configuring DHCP..."
Import-Module DnsServer -ErrorAction SilentlyContinue

$dhcpFeature = Get-WindowsFeature -Name DHCP -ErrorAction SilentlyContinue
if ($dhcpFeature -and $dhcpFeature.Installed) {
    # Authorize DHCP in AD
    $dhcpAuthorized = $false
    try {
        $dhcpServers = Get-DhcpServerInDC -ErrorAction SilentlyContinue
        foreach ($srv in $dhcpServers) {
            if ($srv.IPAddress -eq $StaticIP -or $srv.DnsName -like "*$TargetHost*") {
                $dhcpAuthorized = $true
                break
            }
        }
    } catch {
        Write-Log "WARNING: Could not query DHCP authorization state: $($_.Exception.Message)"
    }

    if (-not $dhcpAuthorized) {
        Add-DhcpServerInDC -IPAddress $StaticIP -DnsName "$TargetHost.$DomainName" -ErrorAction SilentlyContinue
        Write-Log "DHCP server authorized in AD."
    }
    else {
        Write-Log "DHCP server already authorized."
    }

    # Create scope
    $existingScope = Get-DhcpServerv4Scope -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq $DhcpScopeName }
    if (-not $existingScope) {
        Add-DhcpServerv4Scope `
            -Name $DhcpScopeName `
            -StartRange $DhcpStartRange `
            -EndRange $DhcpEndRange `
            -SubnetMask $DhcpSubnetMask `
            -State Active
        Set-DhcpServerv4OptionValue -ScopeId '10.0.0.0' -DnsServer $DhcpDnsServer -Router $DhcpRouter -ErrorAction SilentlyContinue
        Write-Log "DHCP scope created: $DhcpStartRange - $DhcpEndRange"
    }
    else {
        Write-Log "DHCP scope '$DhcpScopeName' already exists."
    }
}
else {
    Write-Log "WARNING: DHCP feature not installed. Skipping scope creation."
}

# Restart DHCP service to pick up authorization
Restart-Service DHCPServer -Force -ErrorAction SilentlyContinue

Write-Log "=== DC01 setup complete ==="
