# Demo Script — AD-HomeLab Interview Walkthrough

## Purpose

This document is a 5-minute narrative walkthrough for demonstrating the AD-HomeLab project in an interview. It highlights what was built, why each component matters, and the skills it demonstrates.

## Talking Points (5 minutes)

### 1. Opening (30 seconds)

> "I built a fully scripted Active Directory lab on Hyper-V — one Windows Server 2022 domain controller and two Windows 11 Pro clients, all in the homelab.local domain. Everything is automated with PowerShell, from VM provisioning to security hardening to user creation. The whole repo has CI with PSScriptAnalyzer, Pester tests, and full documentation."

### 2. VM Provisioning (1 minute)

> "Phase 1 creates an internal virtual switch and three Gen2 VMs. The client VMs get Secure Boot and TPM configured automatically — Windows 11 won't install without those. I also wrote unattend.xml files so the OS installation is fully automated. No manual OOBE clicks needed."

**Key skills**: Hyper-V API, PowerShell automation, UEFI/GPT partitioning, Windows 11 requirements

### 3. Domain Controller + DHCP (1 minute)

> "The DC script sets a static IP, installs AD DS, DNS, and DHCP, promotes to a new forest, creates the OU structure, and configures a DHCP scope with DNS and gateway options. It's fully idempotent — if you run it twice, it detects existing state and skips. It even uses scheduled tasks to resume automatically after reboots."

**Key skills**: AD forest promotion, DHCP scope management, idempotent scripting, reboot handling

### 4. GPOs + Security (1 minute)

> "I created 8 GPOs total — USB storage restriction via registry preference, password policy (14-char minimum, complexity, 5-attempt lockout), plus advanced policies like AppData executable blocking, screen lock timeout, legal warning banner, and Windows Firewall hardening. The security hardening script applies STIG/CIS-inspired controls: NTLMv2-only, SMB signing, Print Spooler disabled (PrintNightmare mitigation), 12 audit categories, and 7 Defender ASR rules."

**Key skills**: Group Policy management, registry-based policies, STIG/CIS hardening, security baselines

### 5. RBAC + Monitoring (1 minute)

> "I set up role-based access control with 7 security groups and delegated permissions on OUs — helpdesk can reset passwords but not create users, IT admins have full control of the IT OU. I also configured Windows Event Forwarding so all security events from clients flow to the DC, with alert scheduled tasks for critical events like audit log clearing or account deletion."

**Key skills**: AD delegation, least-privilege design, WEF architecture, security monitoring

### 6. DSC + CI/CD (30 seconds)

> "As an alternative to the imperative scripts, I wrote a DSC configuration that declares the same desired state declaratively. The repo has GitHub Actions CI running PSScriptAnalyzer on every push, plus Pester tests that mock the AD cmdlets to verify the user creation and GPO logic without needing a real domain controller."

**Key skills**: Desired State Configuration, declarative config management, CI/CD, test-driven infrastructure

### 7. Backup + DR (30 seconds)

> "I wrote backup and restore scripts that export GPOs, AD users, group memberships, DNS records, and password policy. The backup strategy doc defines RPO and RTO targets with 4 recovery scenarios — from a single GPO deletion to full environment loss."

**Key skills**: Business continuity, disaster recovery, RPO/RTO planning

## Expected Interview Questions

### Q: "Why not just use GUI tools like ADUC?"
> "GUI tools don't scale. If you need to create 500 users, you can't click through a wizard 500 times. Scripting ensures consistency, reproducibility, and auditability — you can version-control your infrastructure."

### Q: "What's the difference between your imperative scripts and DSC?"
> "Imperative scripts say 'do this, then do that.' DSC says 'the system should look like this.' DSC detects drift — if someone manually changes a setting, Test-DscConfiguration will flag it. Imperative is great for one-time setup; DSC is for ongoing enforcement."

### Q: "How would you extend this for a real enterprise?"
> "Add a secondary DC for redundancy, use fine-grained password policies instead of the default domain policy, integrate with Microsoft Entra ID for hybrid, add a PKI for certificate-based authentication, and use a real SIEM like Sentinel instead of WEF + scheduled tasks."

### Q: "What was the hardest bug to fix?"
> "The GPO link detection was using a pipeline that always returned null because Get-GPInheritance's GpoLinks property needed to be iterated, not piped through Where-Object. The script was silently skipping the link check and creating duplicate links."

### Q: "How do you handle secrets in this lab?"
> "The lab uses hardcoded credentials in the Vagrant provisioner for simplicity, but the main scripts prompt for credentials via Get-Credential. The .gitignore excludes all output/ and *.csv files, so credential reports never get committed. In production, I'd use Azure Key Vault or Windows Credential Manager."

## Tips for the Demo

1. **Have the repo open on GitHub** — let them browse while you talk
2. **Show the CI badge** passing (green checkmark)
3. **Open the Mermaid diagram** — it renders natively on GitHub
4. **Open PROJECT.md** — point at the "What This Demonstrates" table
5. **If they want to see code**, open `03-Configure-GPOs.ps1` — it has the most depth
6. **Don't apologize** for the eval licenses — explain it's a conscious choice for a lab
