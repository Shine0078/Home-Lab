<#
.SYNOPSIS
    Vagrant provisioner script for Windows 11 clients (domain join).

.DESCRIPTION
    Called automatically by Vagrant after each client VM is booted.
    Sets DNS to DC01, joins the homelab.local domain, and places the
    computer in OU=Workstations. This is the Vagrant equivalent of
    scripts/02-Join-Domain.ps1.

.PARAMETER Hostname
    Target hostname (WIN11-CLIENT01 or WIN11-CLIENT02).

.PARAMETER DcIP
    IP address of the domain controller (DC01).

.PARAMETER DomainName
    FQDN of the domain to join.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$Hostname,

    [Parameter(Mandatory = $true)]
    [string]$DcIP,

    [Parameter(Mandatory = $true)]
    [string]$DomainName
)

function ConvertTo-SecurePassword {
    param([Parameter(Mandatory = $true)][string]$Text)

    $secure = New-Object System.Security.SecureString
    foreach ($char in $Text.ToCharArray()) {
        $secure.AppendChar($char)
    }
    $secure.MakeReadOnly()
    return $secure
}

Write-Output "=== Vagrant Provisioner: $Hostname ==="

# Set DNS to DC01
$adapter = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses $DcIP

# Rename computer
if ($env:COMPUTERNAME -ne $Hostname) {
    Rename-Computer -NewName $Hostname -Force
    Write-Output "Computer renamed to $Hostname. Reboot required before domain join."
    # Vagrant will re-run provisioning after reboot
    exit 0
}

# Join domain
$credential = New-Object System.Management.Automation.PSCredential(
    'HOMELAB\Administrator',
    (ConvertTo-SecurePassword 'LabAdm1n!2026')
)

Add-Computer -DomainName $DomainName -Credential $credential -OUPath 'OU=Workstations,DC=homelab,DC=local' -NewName $Hostname -Force -Options JoinWithNewName

Write-Output "$Hostname joined to $DomainName. Rebooting."
