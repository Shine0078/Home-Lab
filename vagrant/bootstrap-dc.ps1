<#
.SYNOPSIS
    Vagrant provisioner script for DC01 (domain controller setup).

.DESCRIPTION
    Called automatically by Vagrant after the VM is booted. Installs
    AD DS, DNS, and DHCP roles, promotes to a new forest, creates OUs,
    and configures a DHCP scope. This is the Vagrant equivalent of
    scripts/01-Setup-DC.ps1.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$AdminPassword
)

Write-Output "=== Vagrant Provisioner: DC01 ==="

function ConvertTo-SecurePassword {
    param([Parameter(Mandatory = $true)][string]$Text)

    $secure = New-Object System.Security.SecureString
    foreach ($char in $Text.ToCharArray()) {
        $secure.AppendChar($char)
    }
    $secure.MakeReadOnly()
    return $secure
}

# Set static IP
$adapter = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
New-NetIPAddress -InterfaceIndex $adapter.ifIndex -IPAddress '10.0.0.10' -PrefixLength 24 -DefaultGateway '10.0.0.1' -ErrorAction SilentlyContinue | Out-Null
Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses '127.0.0.1'

# Install features
Install-WindowsFeature -Name AD-Domain-Services, DNS, DHCP -IncludeManagementTools | Out-Null

# Promote to DC
$dsrmPassword = ConvertTo-SecurePassword $AdminPassword
Install-ADDSForest -DomainName 'homelab.local' -DomainNetbiosName 'HOMELAB' -SafeModeAdministratorPassword $dsrmPassword -InstallDNS -Force -NoReboot:$false

Write-Output "DC01 provisioning initiated. VM will reboot."
