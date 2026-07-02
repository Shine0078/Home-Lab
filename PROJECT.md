# AD-HomeLab — Project Documentation

## Overview

This project provisions a complete Active Directory environment on a single Hyper-V host for learning, testing, and portfolio demonstration. It automates VM creation, domain controller setup, client domain joins, GPO enforcement, and bulk user creation using idempotent PowerShell scripts, while keeping initial OS installation and WinRM enablement explicit and documented.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   HYPER-V HOST                       │
│                  (Windows 11 Pro)                    │
│                                                      │
│  ┌──────────────────────────────────────────────┐   │
│  │           AD-Lab-Switch (Internal)           │   │
│  │              10.0.0.0/24                     │   │
│  │                                              │   │
│  │  ┌────────────┐  ┌───────────┐  ┌──────────┐│   │
│  │  │   DC01     │  │WIN11-     │  │WIN11-    ││   │
│  │  │ 10.0.0.10  │  │CLIENT01   │  │CLIENT02  ││   │
│  │  │            │  │DHCP       │  │DHCP      ││   │
│  │  │ AD DS      │  │ Domain    │  │ Domain   ││   │
│  │  │ DNS        │  │ Joined    │  │ Joined   ││   │
│  │  │ DHCP       │  │ DHCP      │  │ DHCP     ││   │
│  │  │ Scope:     │  │ Client    │  │ Client   ││   │
│  │  │ .100-.200  │  │           │  │          ││   │
│  │  │            │  │           │  │          ││   │
│  │  │ Server     │  │ Win 11    │  │ Win 11   ││   │
│  │  │ 2022 Std   │  │ Pro       │  │ Pro      ││   │
│  │  └────────────┘  └───────────┘  └──────────┘│   │
│  └──────────────────────────────────────────────┘   │
│                                                      │
│  Domain: homelab.local                              │
│  OUs: Staff, IT, Workstations                       │
│  GPOs: Restrict-USB-Storage, Password-Policy        │
│  Users: 50 accounts (IT, Sales, Finance, Ops, HR)   │
└─────────────────────────────────────────────────────┘
```

## Prerequisites

### Host Requirements
- **OS**: Windows 10/11 Pro or Windows Server with Hyper-V
- **RAM**: 16 GB minimum (8 GB for VMs + host overhead)
- **Storage**: 200 GB free (60 GB DC + 80 GB clients + ISOs)
- **CPU**: 4+ cores with SLAT (Intel VT-x / AMD-V)
- **Hyper-V**: Enabled (see Manual Steps below)

### Software Required
- Windows Server 2022 Standard EVAL ISO ([download](https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-2022))
- Windows 11 Pro ISO ([download](https://www.microsoft.com/en-us/software-download/windows11))
- PowerShell 5.1+ (built into Windows)

### Licensing Note
This lab uses **evaluation editions** of Windows Server 2022 and Windows 11. Evaluation licenses provide 180 days of use — sufficient for lab and portfolio purposes. No production license keys are required.

## Manual Steps Required

### Step 1: Enable Hyper-V (if not enabled)

Hyper-V requires a reboot. Run this in an elevated PowerShell:

```powershell
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
```

Reboot when prompted. After reboot, resume automation from Phase 1.

### Step 2: OS Installation (Human-in-the-loop)

ISO boot + OOBE cannot be automated without volume licensing. For each VM:

1. Mount the appropriate ISO in Hyper-V Manager
2. Boot from ISO, complete Windows installation
3. Enable WinRM/PSRemoting:
   ```powershell
   Enable-PSRemoting -Force -SkipNetworkProfileCheck
   ```
4. Set a static password for the local Administrator account
5. Verify connectivity from the host:
   ```powershell
   Test-WSMan -ComputerName <VM-IP>
   ```

### Step 3: Resume Automation

Once all VMs are installed and WinRM is reachable, run the scripts in order:

| Phase | Script | Run On | Purpose |
|-------|--------|--------|---------|
| 2 | `scripts/01-Setup-DC.ps1` | DC01 | Configure DC: IP, AD DS, DNS, DHCP, OUs |
| 3 | `scripts/02-Join-Domain.ps1` | Each client | Join to homelab.local |
| 4 | `scripts/03-Configure-GPOs.ps1` | DC01 | Create and link GPOs |
| 5 | `scripts/04-Create-Users.ps1` | DC01 | Bulk create 50 users |
| 6 | `scripts/05-Validate-Lab.ps1` | DC01 | Run full validation |

> **Note on Phase 3**: The `-TargetHost` parameter is mandatory. Run with:
> `.\02-Join-Domain.ps1 -TargetHost WIN11-CLIENT01` on client 1, and
> `.\02-Join-Domain.ps1 -TargetHost WIN11-CLIENT02` on client 2.

## Script Details

### Phase 0 — Cleanup / Teardown

`scripts/00-Teardown-Lab.ps1` removes lab-only AD users, groups, GPOs, and monitoring tasks. Use `-WhatIf` first.

### Phase 1 — Hyper-V Provisioning

| Script | Description |
|--------|-------------|
| `hyperv/01-Create-Switch.ps1` | Creates AD-Lab-Switch (internal) |
| `hyperv/02-Provision-DC01.ps1` | Creates DC01 VM (4GB, 2 CPU, 60GB) |
| `hyperv/03-Provision-Clients.ps1` | Creates WIN11-CLIENT01/02 (4GB, 2 CPU, 40GB, TPM/SecureBoot) |
| `hyperv/04-Attach-ISO.ps1` | Attaches ISOs and stages unattend media for OS installation |
| `hyperv/Provision-All.ps1` | Runs all provisioning in sequence |
| `hyperv/unattend/*.xml` | Unattend answer files for Server 2022 and Win11 |

### Phase 2 — Domain Controller Setup

`scripts/01-Setup-DC.ps1` performs:
- Static IP configuration (10.0.0.10/24)
- Computer rename to DC01
- AD DS + DNS + DHCP role installation
- New forest promotion (homelab.local)
- OU creation (Staff, IT, Workstations)
- DNS forwarder configuration (8.8.8.8, 1.1.1.1)
- DHCP scope creation (10.0.0.100-200/24) with DNS/router options
- DHCP server authorization in Active Directory

### Phase 3 — Domain Join

`scripts/02-Join-Domain.ps1` performs:
- DNS pointed at DC01 (10.0.0.10)
- Computer rename (if needed, with reboot handling)
- Domain join with OU placement (OU=Workstations)
- Resume flag file for reboot continuity

### Phase 4 — GPO Configuration

`scripts/03-Configure-GPOs.ps1` creates:
- **Restrict-USB-Storage**: Disables USB mass storage via registry (`USBSTOR\Start = 4`), linked to OU=Workstations
- **Password Policy**: Min 14 chars, complexity enabled, 60-day max age, 5-attempt lockout

### Phase 5 — Bulk User Creation

`scripts/04-Create-Users.ps1` creates 50 users from `data/users.csv`:
- Random 16-character passwords
- `ChangePasswordAtLogon = $true`
- IT users -> OU=IT, others -> OU=Staff
- Credentials exported to `output/user-credentials.csv` (gitignored)

### Phase 6 — Validation

`scripts/05-Validate-Lab.ps1` confirms:
- Domain controller operational
- OU structure exists (Staff, IT, Workstations)
- Both clients domain-joined in AD
- Password policy enforced (length, complexity, lockout, duration)
- USB restriction GPO exists and linked to OU=Workstations
- USBSTOR Start=4 registry value present in GPO
- USB storage disabled on a reachable client (remote registry check)
- GPO application verified via gpresult on a client
- AD user count >= 50 in OU=Staff and OU=IT

### Phase 7 — DSC (Declarative Configuration)

`dsc/LabDscConfiguration.ps1` provides a declarative alternative:
- Same desired state as imperative scripts using xActiveDirectory, xDhcpServer, xNetworking DSC resources
- Supports drift detection via `Test-DscConfiguration`
- Run via `dsc/Start-DscRun.ps1`

### Phase 8 — Security Hardening & Monitoring

`scripts/06-Harden-Baseline.ps1` applies STIG/CIS-inspired controls:
- NTLMv2-only (LmCompatibilityLevel=5)
- SMB signing required
- Print Spooler disabled (PrintNightmare mitigation)
- 12 audit categories via auditpol
- 7 Windows Defender ASR rules + Controlled Folder Access
- Guest account disabled, anonymous LDAP restricted
- PowerShell script block logging enabled
- See `docs/security-baseline.md` for control-to-standard mapping

`scripts/07-Setup-Monitoring.ps1` configures:
- Windows Event Forwarding (WEF) collector on DC01
- SourceInitiated subscription for 32 security event types
- Alert scheduled tasks for critical events
- See `docs/security-dashboard.md` for monitoring architecture

### Phase 9 — Disaster Recovery

`scripts/08-Backup-Lab.ps1` and `scripts/09-Restore-Lab.ps1`:
- Backup: GPOs, AD users, group memberships, DNS records, OU structure, password policy, VM checkpoints
- Restore: GPOs (Import-GPO), users (re-create with temp passwords), password policy (from XML)
- See `docs/backup-strategy.md` for RPO/RTO targets and 4 recovery scenarios

### Phase 10 — Advanced GPOs & RBAC

`scripts/10-Advanced-GPOs.ps1` creates 6 additional GPOs:
- Block-AppData-Executables, Screen-Lock-Timeout, Legal-Warning-Banner
- Local-Account-Hardening, Windows-Firewall-Hardening, Disable-Unnecessary-Services

`scripts/11-Setup-RBAC.ps1` creates:
- 7 security groups (GG-IT-Admins, GG-Helpdesk-Operators, etc.)
- OU-level delegation via AD ACLs (ResetPassword, UnlockAccount, FullControl, ReadOnly)
- Auto-populates group memberships from user Department attribute
- See `docs/rbac-matrix.md` for delegation matrix

## GPO Details

### Restrict-USB-Storage
- **Type**: Computer Configuration > Preferences > Windows Settings > Registry
- **Key**: `HKLM\SYSTEM\CurrentControlSet\Services\USBSTOR`
- **Value**: `Start` = `4` (disabled)
- **Scope**: OU=Workstations

### Password-Policy (Default Domain Policy)
- Minimum password length: 14 characters
- Complexity requirements: Enabled
- Maximum password age: 60 days
- Account lockout threshold: 5 invalid attempts
- Lockout duration: 15 minutes
- Password history: 24 passwords

## DHCP Configuration

- **Scope name**: AD-Lab-Scope
- **IP range**: 10.0.0.100 -- 10.0.0.200
- **Subnet mask**: 255.255.255.0 (/24)
- **DNS server**: 10.0.0.10 (DC01)
- **Router/gateway**: 10.0.0.1
- **AD authorization**: DHCP server authorized in AD on first run
- **State**: Active

## Repository Structure

```
AD-HomeLab/
├── .github/workflows/    # CI: PSScriptAnalyzer linting + Pester tests
├── config/gpo-exports/   # GPO backup export directory
├── data/                 # User CSV + monitored events dataset
├── docs/                 # Architecture, runbooks, security, cost, demo
│   ├── screenshots/      # Screenshot placeholders
│   └── runbooks/         # 6 operational runbooks (RB-001 to RB-006)
├── dsc/                  # Desired State Configuration (declarative)
├── hyperv/               # Hyper-V provisioning + unattend XMLs + ISO attach
├── logs/                 # Runtime logs (gitignored)
├── modules/ADHomeLab/    # PowerShell module (shared functions)
├── output/               # Credential reports + backups (gitignored)
├── scripts/              # 12 scripts: teardown, DC, join, GPO, users, validation,
│                         #   hardening, monitoring, backup, restore,
│                         #   advanced GPOs, RBAC
├── tests/                # Pester tests (syntax, help, data, mocks)
├── vagrant/              # Vagrant alternative with Hyper-V provider
├── .gitignore
├── .gitattributes
├── CHANGELOG.md
├── CODE_OF_CONDUCT.md
├── CONTRIBUTING.md
├── LICENSE
├── PROJECT.md            # This file
├── README.md
└── Vagrantfile
```

## Screenshots

> Screenshots are stored in `docs/screenshots/`. Capture during execution for portfolio presentation.

Placeholders:
- `docs/screenshots/hyperv-switch.png` — Virtual switch created
- `docs/screenshots/vm-provisioned.png` — VMs in Hyper-V Manager
- `docs/screenshots/dc-promotion.png` — Domain controller promotion
- `docs/screenshots/gpo-usb.png` — USB restriction GPO
- `docs/screenshots/gpo-password.png` — Password policy settings
- `docs/screenshots/validation-pass.png` — All tests passing
- `docs/screenshots/ad-users.png` — 50 users in ADUC

## Troubleshooting

### Hyper-V: "A hypervisor has been detected"
This is expected on VMs running inside another hypervisor. Nested virtualization must be enabled for Hyper-V inside a VM:
```powershell
Set-VMProcessor -VMName <name> -ExposeVirtualizationExtensions $true
```

### DC Promotion Fails: "Verification of prerequisites for DNS delegation failed"
Ensure the static IP is configured and the network adapter is up before promotion. Re-run the script.

### Domain Join Fails: "The domain name could not be found"
- Verify DC01 is running and DNS is set correctly on the client
- Test: `nslookup homelab.local` from the client
- Ensure the client DNS points to 10.0.0.10

### GPO Not Applying on Client
- Run `gpupdate /force` on the client
- Check with `gpresult /r` or `gpresult /h report.html`
- Ensure the computer object is in the correct OU

### Users Not Created
- Verify `data/users.csv` exists and has 50 rows
- Check `logs/create-users.log` for specific errors
- Ensure running as Domain Admin on DC01

### WinRM Connection Refused
- On the target VM: `Enable-PSRemoting -Force`
- From host: `Test-WSMan -ComputerName <IP>`
- Check Windows Firewall allows WinRM (port 5985/5986)

### DHCP Scope Not Handing Out Addresses
- Verify DHCP service is running: `Get-Service DHCPServer`
- Verify DHCP is authorized in AD: `Get-DhcpServerInDC`
- Check scope state: `Get-DhcpServerv4Scope`
- Ensure clients are on the same virtual switch (AD-Lab-Switch)
- Restart DHCP service: `Restart-Service DHCPServer -Force`

### Windows 11 Installation Fails (TPM/Secure Boot)
- Ensure the client VM has TPM enabled: `Get-VMKeyProtector -VMName WIN11-CLIENT01`
- Verify Secure Boot template: `Get-VMFirmware -VMName WIN11-CLIENT01`
- If the VM was created before the hardening pass, rerun `scripts/00-Teardown-Lab.ps1` for lab objects and recreate the VM so `Enable-VMTPM` is applied cleanly
- Host must support TPM 2.0 and virtualization-based security

### Lab Scripts Stop on Missing Dependencies
- If `PSScriptAnalyzer` is not installed, use the bundled copy under `.tools/PSScriptAnalyzer`
- If DSC errors mention `xActiveDirectory`, `xDhcpServer`, or `xNetworking`, install those modules before running `dsc/Start-DscRun.ps1`
- If WEF setup fails, confirm `Windows-Event-Collector` is available and WinRM is enabled on the collector and clients
- If DHCP scope creation fails, verify the script is using network `10.0.0.0/24` and not the host IP as the scope ID

## What This Demonstrates

This project maps directly to real-world sysadmin and infrastructure skills:

| Component | Skill Demonstrated |
|-----------|-------------------|
| Hyper-V provisioning | Infrastructure-as-Code, VM lifecycle management |
| Unattend.xml + ISO attach | Semi-automated OS deployment, UEFI partitioning |
| Static IP + DNS | Network configuration, DNS architecture |
| DHCP scope + authorization | IP address management, AD-integrated DHCP |
| AD DS promotion | Domain controller deployment, forest design |
| OU structure | Organizational unit design, delegation model |
| GPO creation + linking | Group Policy management, security hardening |
| Advanced GPOs (6 additional) | Enterprise policy design, ASR, firewall, banner |
| USB restriction | Endpoint security, registry-based policy |
| Password policy | Account security, compliance controls |
| STIG/CIS hardening | Security baselines, NTLMv2, SMB signing, auditpol |
| Defender ASR rules | Attack surface reduction, ransomware protection |
| Windows Event Forwarding | Centralized log management, SIEM-like architecture |
| Alert scheduled tasks | Automated incident response triggers |
| Bulk user creation | Automation, scripting at scale |
| RBAC + OU delegation | Least-privilege design, AD ACLs, extended rights |
| DSC configuration | Declarative config management, drift detection |
| Backup/restore scripts | Business continuity, disaster recovery |
| RPO/RTO documentation | Business continuity planning |
| Idempotent scripts | Safe re-runnable automation |
| Validation script | Infrastructure testing, health checks |
| PowerShell module | Code reuse, packaging, API design |
| Vagrant alternative | DevOps tooling, cross-platform IaC |
| CI pipeline | Code quality enforcement, automated testing |
| Pester tests with mocks | Test-driven infrastructure, unit testing |
| Runbooks (6) | Operational documentation, SOPs |
| Architecture diagrams | Mermaid, Draw.io, visual communication |
| Cost analysis | Cloud awareness, financial reasoning |

## License

MIT
