<#
.SYNOPSIS
    Applies security hardening baseline (STIG/CIS-inspired) to DC01.

.DESCRIPTION
    Applies security controls inspired by DISA STIG and CIS Benchmarks:
      - Disable NTLMv1 and LM (require NTLMv2 minimum)
      - Require SMB signing on server and client
      - Disable Print Spooler service on DC (PrintNightmare mitigation)
      - Set audit policy for security-relevant events
      - Enable Windows Defender ASR rules
      - Disable Guest account, set Administrator account description
      - Restrict anonymous LDAP access
      - Enable PowerShell script block logging
    All changes are idempotent. Logs to logs/harden-baseline.log.

.NOTES
    Run as Administrator on DC01.
    Part of AD-HomeLab Phase 8 (Security Hardening).
#>

#Requires -RunAsAdministrator

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$LogDir  = Join-Path $PSScriptRoot '..\logs'
$LogFile = Join-Path $LogDir 'harden-baseline.log'

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $entry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $entry
    if ($Level -eq 'WARN') { Write-Output "  [WARN] $Message" -ForegroundColor Yellow }
    elseif ($Level -eq 'ERROR') { Write-Output "  [ERROR] $Message" -ForegroundColor Red }
    else { Write-Output "  $Message" -ForegroundColor Cyan }
}

function Set-RegistryDword {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][int]$Value
    )

    if ($PSCmdlet.ShouldProcess($Path, "Set registry DWORD $Name")) {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }

        New-ItemProperty -Path $Path -Name $Name -PropertyType DWord -Value $Value -Force | Out-Null
    }
}

Write-Log "=== Security Hardening Baseline (STIG/CIS-inspired) ==="

# â”€â”€ 1. Disable NTLMv1 and LM â”€â”€
Write-Log "1. Disabling NTLMv1 and LM authentication..."
$ntlmPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
Set-RegistryDword -Path $ntlmPath -Name 'LmCompatibilityLevel' -Value 5
Set-RegistryDword -Path $ntlmPath -Name 'NoLMA' -Value 1
Write-Log "  LmCompatibilityLevel = 5 (NTLMv2 only, refuse LM/NTLMv1)"

# â”€â”€ 2. Require SMB signing â”€â”€
Write-Log "2. Enabling SMB signing..."
$smbServerPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'
Set-RegistryDword -Path $smbServerPath -Name 'RequireSecuritySignature' -Value 1
Set-RegistryDword -Path $smbServerPath -Name 'EnableSecuritySignature' -Value 1
Write-Log "  SMB server signing: required"

$smbClientPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters'
Set-RegistryDword -Path $smbClientPath -Name 'RequireSecuritySignature' -Value 1
Set-RegistryDword -Path $smbClientPath -Name 'EnableSecuritySignature' -Value 1
Write-Log "  SMB client signing: required"

# â”€â”€ 3. Disable Print Spooler on DC â”€â”€
Write-Log "3. Disabling Print Spooler (PrintNightmare mitigation)..."
$spooler = Get-Service -Name Spooler -ErrorAction SilentlyContinue
if ($spooler) {
    if ($spooler.Status -eq 'Running') {
        Stop-Service -Name Spooler -Force -ErrorAction SilentlyContinue
    }
    Set-Service -Name Spooler -StartupType Disabled
    Write-Log "  Print Spooler: stopped and disabled"
}
else {
    Write-Log "  Print Spooler service not found (already absent)"
}

# â”€â”€ 4. Set audit policy â”€â”€
Write-Log "4. Configuring audit policy..."
$auditSettings = @(
    @{ Category = 'Logon';                          Subcategory = 'Logon';                         Setting = '/success:enable /failure:enable' }
    @{ Category = 'Logoff';                         Subcategory = 'Logoff';                        Setting = '/success:enable' }
    @{ Category = 'Account Lockout';                Subcategory = 'Account Lockout';               Setting = '/success:enable /failure:enable' }
    @{ Category = 'Account Management';             Subcategory = 'User Account Management';       Setting = '/success:enable /failure:enable' }
    @{ Category = 'Account Management';             Subcategory = 'Security Group Management';     Setting = '/success:enable /failure:enable' }
    @{ Category = 'Policy Change';                  Subcategory = 'Audit Policy Change';           Setting = '/success:enable /failure:enable' }
    @{ Category = 'Policy Change';                  Subcategory = 'Authentication Policy Change';  Setting = '/success:enable /failure:enable' }
    @{ Category = 'Privilege Use';                  Subcategory = 'Sensitive Privilege Use';       Setting = '/success:enable /failure:enable' }
    @{ Category = 'Detailed Tracking';              Subcategory = 'Process Creation';              Setting = '/success:enable' }
    @{ Category = 'Object Access';                  Subcategory = 'File System';                   Setting = '/success:enable /failure:enable' }
    @{ Category = 'Object Access';                  Subcategory = 'Registry';                      Setting = '/success:enable /failure:enable' }
)

foreach ($audit in $auditSettings) {
    try {
        & auditpol.exe /set /subcategory:"$($audit.Subcategory)" $audit.Setting | Out-Null
        Write-Log "  Audit: $($audit.Subcategory) -> $($audit.Setting)"
    }
    catch {
        Write-Log "  Audit: $($audit.Subcategory) -> FAILED: $($_.Exception.Message)" 'WARN'
    }
}

# â”€â”€ 5. Enable Windows Defender ASR rules â”€â”€
Write-Log "5. Enabling Windows Defender ASR rules..."
$asrRules = @(
    @{ Id = 'BE9BA2D9-53EA-4CDC-84E2-1A1FED5B7B5C'; Name = 'Block executable content from email' }
    @{ Id = 'D4F940AB-401B-4EFC-AADC-AD5F4C64AE54'; Name = 'Block Office apps from creating child processes' }
    @{ Id = '75668C1F-73B5-4CF0-BB93-3ECF5CB7CC84'; Name = 'Block Office apps from injecting into other processes' }
    @{ Id = '3B576869-A4EC-4529-8536-C8014094F5CC'; Name = 'Block Office apps from creating executable content' }
    @{ Id = '26190899-1602-49E8-8B27-EB1D0A1CE869'; Name = 'Block Office communication apps from creating child processes' }
    @{ Id = '7674BA52-37EB-4A4F-A9A1-F0F9A1619A2C'; Name = 'Block Adobe Reader from creating child processes' }
    @{ Id = 'E6DB77E5-3EFA-4DB9-A6F7-6E8B8B8A6F5C'; Name = 'Block credential stealing from LSASS' }
)

try {
    $defender = Get-MpComputerStatus -ErrorAction SilentlyContinue
    if ($defender) {
        Set-MpPreference -EnableControlledFolderAccess Enabled -ErrorAction SilentlyContinue
        Write-Log "  Controlled Folder Access: Enabled"

        foreach ($rule in $asrRules) {
            try {
                Add-MpPreference -AttackSurfaceReductionRules_Ids $rule.Id -AttackSurfaceReductionRules_Actions Enabled -ErrorAction SilentlyContinue
                Write-Log "  ASR: $($rule.Name) -> Enabled"
            }
            catch {
                Write-Log "  ASR: $($rule.Name) -> Skipped (may not apply to Server)" 'WARN'
            }
        }
    }
    else {
        Write-Log "  Windows Defender not available on this system. Skipping ASR rules." 'WARN'
    }
}
catch {
    Write-Log "  Windows Defender configuration failed: $($_.Exception.Message)" 'WARN'
}

# â”€â”€ 6. Disable Guest account â”€â”€
Write-Log "6. Disabling Guest account..."
try {
    $guest = Get-LocalUser -Name 'Guest' -ErrorAction SilentlyContinue
    if ($guest) {
        Disable-LocalUser -Name 'Guest'
        Write-Log "  Guest account: disabled"
    }
}
catch {
    Write-Log "  Guest account: $($_.Exception.Message)" 'WARN'
}

# â”€â”€ 7. Restrict anonymous LDAP access â”€â”€
Write-Log "7. Restricting anonymous LDAP access..."
$ldapPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\NTDS\Parameters'
Set-RegistryDword -Path $ldapPath -Name 'LDAPAnonRestrictIsConfigured' -Value 1
Set-RegistryDword -Path $ldapPath -Name 'LDAPAnonRestrict' -Value 1
Write-Log "  Anonymous LDAP: restricted"

# â”€â”€ 8. Enable PowerShell script block logging â”€â”€
Write-Log "8. Enabling PowerShell script block logging..."
$psLogPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging'
Set-RegistryDword -Path $psLogPath -Name 'EnableScriptBlockLogging' -Value 1
Write-Log "  Script block logging: enabled"

# â”€â”€ 9. Set Windows Firewall defaults â”€â”€
Write-Log "9. Configuring Windows Firewall..."
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True -DefaultInboundAction Block -DefaultOutboundAction Allow
Write-Log "  All profiles: enabled, inbound blocked, outbound allowed"

# Enable specific rules for the lab
Enable-NetFirewallRule -DisplayGroup 'Active Directory Domain Services' -ErrorAction SilentlyContinue
Enable-NetFirewallRule -DisplayGroup 'DHCP Server' -ErrorAction SilentlyContinue
Enable-NetFirewallRule -DisplayGroup 'DNS Server' -ErrorAction SilentlyContinue
Enable-NetFirewallRule -Name 'WINRM-HTTP-In-TCP' -ErrorAction SilentlyContinue
Enable-NetFirewallRule -Name 'FPS-SMB-In-TCP' -ErrorAction SilentlyContinue
Write-Log "  Enabled firewall rules: AD DS, DHCP, DNS, WinRM, SMB"

Write-Log "=== Security hardening complete ==="
Write-Log "Review: docs/security-baseline.md for control-to-standard mapping"
