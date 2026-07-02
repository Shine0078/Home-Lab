# Security Hardening Baseline

## Overview

This document maps each security control applied by `scripts/06-Harden-Baseline.ps1`
to its corresponding DISA STIG / CIS Benchmark reference. This demonstrates
that the hardening is not arbitrary — each setting has a documented rationale
and maps to a recognized security standard.

## Control Mapping

| # | Control | Setting | STIG Reference | CIS Reference | Rationale |
|---|---------|---------|----------------|---------------|-----------|
| 1 | Disable NTLMv1/LM | `LmCompatibilityLevel=5` | WN16-SO-000050 | 18.10.4.1 | NTLMv1 and LM are cryptographically broken; only NTLMv2+ is permitted |
| 2 | SMB signing required | `RequireSecuritySignature=1` | WN16-SO-000070 | 18.10.7.2 | Prevents SMB relay attacks; ensures packet integrity |
| 3 | Print Spooler disabled | `Spooler=Disabled` | WN16-DC-000240 | 18.3.3 | PrintNightmare (CVE-2021-34527) mitigation; DC should not print |
| 4 | Audit: Logon success+failure | `auditpol /subcategory:"Logon"` | WN16-AU-000010 | 17.1.1 | Detects unauthorized access attempts and successful logins |
| 5 | Audit: Account Lockout | `auditpol /subcategory:"Account Lockout"` | WN16-AU-000100 | 17.1.6 | Detects brute-force attacks |
| 6 | Audit: User Account Mgmt | `auditpol /subcategory:"User Account Management"` | WN16-AU-000150 | 17.2.1 | Detects unauthorized account creation/modification |
| 7 | Audit: Security Group Mgmt | `auditpol /subcategory:"Security Group Management"` | WN16-AU-000160 | 17.2.2 | Detects privilege escalation via group changes |
| 8 | Audit: Audit Policy Change | `auditpol /subcategory:"Audit Policy Change"` | WN16-AU-000200 | 17.3.1 | Detects tampering with audit configuration |
| 9 | Audit: Sensitive Privilege Use | `auditpol /subcategory:"Sensitive Privilege Use"` | WN16-AU-000250 | 17.5.1 | Detects use of SeDebugPrivilege, SeTcbPrivilege, etc. |
| 10 | Audit: Process Creation | `auditpol /subcategory:"Process Creation"` | WN16-AU-000300 | 17.7.1 | Enables tracking of process lineage for incident response |
| 11 | Defender ASR: Block email exec | Rule `BE9BA2D9...` | N/A | 18.9.3.1 | Prevents malware delivered via email attachments from executing |
| 12 | Defender ASR: Block Office child procs | Rule `D4F940AB...` | N/A | 18.9.3.1 | Prevents macro-based attacks from spawning processes |
| 13 | Defender ASR: Block LSASS cred steal | Rule `E6DB77E5...` | N/A | 18.9.3.1 | Prevents credential dumping via LSASS access |
| 14 | Controlled Folder Access | `EnableControlledFolderAccess=Enabled` | N/A | 18.9.3.3 | Ransomware protection for user documents |
| 15 | Guest account disabled | `Disable-LocalUser Guest` | WN16-SO-000060 | 18.1.1.2 | Guest account has well-known SID; disabling prevents anonymous access |
| 16 | Anonymous LDAP restricted | `LDAPAnonRestrict=1` | WN16-DC-000290 | 18.3.4 | Prevents LDAP enumeration by unauthenticated attackers |
| 17 | PowerShell script block logging | `EnableScriptBlockLogging=1` | N/A | 18.9.4.1 | Captures all PowerShell execution for threat hunting and IR |
| 18 | Firewall: all profiles enabled | `Domain,Public,Private=Enabled` | WN16-FW-000010 | 9.1.1 | Ensures network filtering is always active |
| 19 | Firewall: inbound blocked by default | `DefaultInboundAction=Block` | WN16-FW-000020 | 9.1.2 | Default-deny inbound; explicit rules for required services |

## Verification

After running `scripts/06-Harden-Baseline.ps1`, verify controls:

```powershell
# Check NTLM level
(Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa').LmCompatibilityLevel
# Expected: 5

# Check SMB signing
(Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters').RequireSecuritySignature
# Expected: 1

# Check Print Spooler
Get-Service Spooler | Select-Object Name, Status, StartType
# Expected: Stopped, Disabled

# Check audit policy
auditpol /get /category:"Logon/Logoff"

# Check ASR rules
Get-MpPreference | Select-Object -ExpandProperty AttackSurfaceReductionRules_Ids

# Check Firewall
Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction
```

## References

- [DISA STIG Windows Server 2016](https://www.stigviewer.com/stig/windows_server_2016/) (applies to 2022)
- [CIS Microsoft Windows Server 2022 Benchmark](https://www.cisecurity.org/benchmark/microsoft_windows_server/)
- [Microsoft Defender ASR rules reference](https://learn.microsoft.com/en-us/microsoft-365/security/defender-endpoint/attack-surface-reduction-rules-reference)
- [PrintNightmare (CVE-2021-34527)](https://msrc.microsoft.com/update/en-US/vulnerability/CVE-2021-34527)
