<#
.SYNOPSIS
    Desired State Configuration for the AD-HomeLab domain controller.

.DESCRIPTION
    Declares the desired state for DC01 in a declarative manner using
    PowerShell DSC. This is an alternative to the imperative scripts in
    scripts/01-Setup-DC.ps1 and demonstrates declarative config management.
    Configures: Windows features (AD DS, DNS, DHCP), static IP, OU structure,
    and DNS forwarders. Requires the xActiveDirectory, xDhcpServer, and
    xNetworking DSC resources.

.PARAMETER DomainName
    FQDN of the domain. Default: homelab.local

.PARAMETER DomainAdminPassword
    DSRM / domain admin password as a PSCredential object.

.NOTES
    Run ON DC01 as Administrator.
    Requires DSC resources: xActiveDirectory, xDhcpServer, xNetworking,
    xComputerManagement. Install via:
    Install-Module xActiveDirectory, xDhcpServer, xNetworking, xComputerManagement -Force
    Part of AD-HomeLab Phase 7 (DSC).
#>

param(
    [string]$DomainName = 'homelab.local',
    [PSCredential]$DomainAdminPassword
)

Configuration LabDscConfiguration {
    param(
        [string]$NodeName = 'localhost',
        [string]$DomainName = 'homelab.local',
        [PSCredential]$DomainAdminPassword
    )

    Import-DscResource -ModuleName xActiveDirectory
    Import-DscResource -ModuleName xDhcpServer
    Import-DscResource -ModuleName xNetworking
    Import-DscResource -ModuleName xComputerManagement
    Import-DscResource -ModuleName PSDesiredStateConfiguration

    Node $NodeName {
        # ── Windows Features ──
        WindowsFeature ADDomainServices {
            Name   = 'AD-Domain-Services'
            Ensure = 'Present'
            IncludeAllSubFeature = $true
            IncludeManagementTools = $true
        }

        WindowsFeature DNS {
            Name   = 'DNS'
            Ensure = 'Present'
            IncludeManagementTools = $true
        }

        WindowsFeature DHCP {
            Name   = 'DHCP'
            Ensure = 'Present'
            IncludeManagementTools = $true
        }

        # ── Static IP Configuration ──
        xIPAddress LabIP {
            IPAddress      = '10.0.0.10'
            InterfaceAlias = 'Ethernet'
            SubnetMask     = 24
            AddressFamily  = 'IPv4'
            DependsOn      = '[WindowsFeature]ADDomainServices'
        }

        xDnsServerAddress DnsServer {
            Address        = '127.0.0.1'
            InterfaceAlias = 'Ethernet'
            AddressFamily  = 'IPv4'
            DependsOn      = '[xIPAddress]LabIP'
        }

        # ── AD Domain (new forest) ──
        xADDomain HomelabForest {
            DomainName                    = $DomainName
            DomainAdministratorCredential = $DomainAdminPassword
            SafemodeAdministratorPassword = $DomainAdminPassword
            DatabasePath                  = 'C:\Windows\NTDS'
            LogPath                       = 'C:\Windows\NTDS'
            DependsOn                     = '[WindowsFeature]ADDomainServices', '[xDnsServerAddress]DnsServer'
        }

        # ── OU Structure ──
        xADOrganizationalUnit Staff {
            Name                            = 'Staff'
            Path                            = "DC=homelab,DC=local"
            ProtectedFromAccidentalDeletion = $true
            Description                     = 'Staff user accounts (non-IT)'
            DependsOn                       = '[xADDomain]HomelabForest'
        }

        xADOrganizationalUnit IT {
            Name                            = 'IT'
            Path                            = "DC=homelab,DC=local"
            ProtectedFromAccidentalDeletion = $true
            Description                     = 'IT department user accounts'
            DependsOn                       = '[xADDomain]HomelabForest'
        }

        xADOrganizationalUnit Workstations {
            Name                            = 'Workstations'
            Path                            = "DC=homelab,DC=local"
            ProtectedFromAccidentalDeletion = $true
            Description                     = 'Domain-joined workstation computers'
            DependsOn                       = '[xADDomain]HomelabForest'
        }

        # ── DHCP Scope ──
        xDhcpServerScope LabScope {
            Name        = 'AD-Lab-Scope'
            IPStartRange = '10.0.0.100'
            IPEndRange   = '10.0.0.200'
            SubnetMask   = '255.255.255.0'
            State        = 'Active'
            DependsOn    = '[WindowsFeature]DHCP', '[xADDomain]HomelabForest'
        }

        xDhcpServerOptionValue LabDhcpOptions {
            ScopeID     = '10.0.0.0'
            DnsDomain   = $DomainName
            DnsServerIP = '10.0.0.10'
            Router      = '10.0.0.1'
            AddressFamily = 'IPv4'
            DependsOn    = '[xDhcpServerScope]LabScope'
        }

        # ── DNS Forwarders ──
        xDnsServerForwarder ExternalForwarders {
            IPAddress  = @('8.8.8.8', '1.1.1.1')
            IsOverride = $true
            DependsOn  = '[WindowsFeature]DNS'
        }
    }
}
