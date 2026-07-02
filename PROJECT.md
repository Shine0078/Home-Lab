# AD-HomeLab — Project Documentation

## Overview

This project provisions a complete Active Directory environment on a single Hyper-V host for learning, testing, and portfolio demonstration. It automates VM creation, domain controller setup, client domain joins, GPO enforcement, and bulk user creation using idempotent PowerShell scripts.

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
│  │  │ AD DS      │  │           │  │          ││   │
│  │  │ DNS        │  │ Domain    │  │ Domain   ││   │
│  │  │ DHCP       │  │ Joined    │  │ Joined   ││   │
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
| 2 | `scripts/01-Setup-DC.ps1` | DC01 | Configure domain controller |
| 3 | `scripts/02-Join-Domain.ps1` | Each client | Join to homelab.local |
| 4 | `scripts/03-Configure-GPOs.ps1` | DC01 | Create and link GPOs |
| 5 | `scripts/04-Create-Users.ps1` | DC01 | Bulk create 50 users |
| 6 | `scripts/05-Validate-Lab.ps1` | DC01 | Run full validation |

## Script Details

### Phase 1 — Hyper-V Provisioning

| Script | Description |
|--------|-------------|
| `hyperv/01-Create-Switch.ps1` | Creates AD-Lab-Switch (internal) |
| `hyperv/02-Provision-DC01.ps1` | Creates DC01 VM (4GB, 2 CPU, 60GB) |
| `hyperv/03-Provision-Clients.ps1` | Creates WIN11-CLIENT01/02 (4GB, 2 CPU, 40GB) |
| `hyperv/Provision-All.ps1` | Runs all three in sequence |

### Phase 2 — Domain Controller Setup

`scripts/01-Setup-DC.ps1` performs:
- Static IP configuration (10.0.0.10/24)
- Computer rename to DC01
- AD DS + DNS role installation
- New forest promotion (homelab.local)
- OU creation (Staff, IT, Workstations)
- DNS forwarder configuration (8.8.8.8, 1.1.1.1)

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
- OU structure exists
- Both clients domain-joined
- Password policy enforced
- GPOs created and linked
- User count >= 50

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

## Repository Structure

```
AD-HomeLab/
├── .github/workflows/    # CI: PSScriptAnalyzer linting
├── data/                 # User CSV dataset
├── docs/screenshots/     # Placeholder for screenshots
├── hyperv/               # Hyper-V provisioning scripts
├── logs/                 # Runtime logs (gitignored)
├── output/               # Credential reports (gitignored)
├── scripts/              # Domain config, GPO, users, validation
├── tests/                # Pester tests
├── .gitignore
├── .gitattributes
├── CHANGELOG.md
├── LICENSE
├── PROJECT.md            # This file
└── README.md
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

## What This Demonstrates

This project maps directly to real-world sysadmin and infrastructure skills:

| Component | Skill Demonstrated |
|-----------|-------------------|
| Hyper-V provisioning | Infrastructure-as-Code, VM lifecycle management |
| Static IP + DNS | Network configuration, DNS architecture |
| AD DS promotion | Domain controller deployment, forest design |
| OU structure | Organizational unit design, delegation model |
| GPO creation + linking | Group Policy management, security hardening |
| USB restriction | Endpoint security, registry-based policy |
| Password policy | Account security, compliance controls |
| Bulk user creation | Automation, scripting at scale |
| Idempotent scripts | Safe re-runnable automation |
| Validation script | Infrastructure testing, health checks |
| CI pipeline | Code quality enforcement |
| Pester tests | Automated testing for PowerShell |

## License

MIT
