# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Added `apps/mobile-web/`, an Expo React Native dashboard for web, iOS, and Android
- Added dashboard screens for lab overview, phases, scripts, validation checks, security controls, runbooks, and the app security model
- Added GUI data validation and CI coverage for TypeScript and dashboard data integrity
- Added dashboard documentation in `apps/mobile-web/README.md` and root README/PROJECT references
- Added `scripts/00-Teardown-Lab.ps1` for safe lab cleanup of users, groups, GPOs, and monitoring tasks
- Added troubleshooting notes and dependency guidance to the project documentation

### Fixed
- Corrected the DHCP scope ID in `scripts/01-Setup-DC.ps1` so scope options target `10.0.0.0/24` instead of the host IP
- Fixed client reboot resume logic in `scripts/02-Join-Domain.ps1` to use a startup trigger rather than logon timing
- Reworked monitoring setup so WEF and alert tasks are event-triggered rather than placeholder logon tasks
- Fixed GPO restore logic to read the backup manifest’s original display name instead of the backup folder name
- Removed committed reusable lab passwords from Vagrant and unattend templates in favor of runtime password input
- Replaced invalid `Write-Output -ForegroundColor` calls with appropriate console output calls

### Changed
- Aligned README/PROJECT language with the actual manual OS-installation step
- Documented the dashboard as read-only by design; privileged lab execution remains local unless a secured backend agent is added

## [1.0.0] - 2026-07-02

### Added — Phase 7: DSC
- DSC configuration (`dsc/LabDscConfiguration.ps1`) declaring desired state for DC01 using xActiveDirectory, xDhcpServer, xNetworking resources
- DSC runner (`dsc/Start-DscRun.ps1`) with auto-install of resource modules

### Added — Phase 8: Security Hardening & Monitoring
- Security hardening script (`scripts/06-Harden-Baseline.ps1`) with 19 STIG/CIS-inspired controls
- Monitoring script (`scripts/07-Setup-Monitoring.ps1`) with WEF collector, event subscription, alert tasks
- Monitored events dataset (`data/monitored-events.csv`) with 32 security event IDs
- Security baseline documentation (`docs/security-baseline.md`) with control-to-standard mapping
- Security dashboard documentation (`docs/security-dashboard.md`) with WEF architecture

### Added — Phase 9: Disaster Recovery
- Backup script (`scripts/08-Backup-Lab.ps1`) for GPOs, AD users, groups, DNS, OUs, policy, VM checkpoints
- Restore script (`scripts/09-Restore-Lab.ps1`) with idempotent restore from timestamped backup
- Backup strategy documentation (`docs/backup-strategy.md`) with RPO/RTO and 4 recovery scenarios

### Added — Phase 10: Advanced GPOs & RBAC
- 6 advanced GPOs (`scripts/10-Advanced-GPOs.ps1`): ASR, screen lock, legal banner, account hardening, firewall, service disable
- RBAC script (`scripts/11-Setup-RBAC.ps1`) with 7 security groups and OU-level ACL delegation
- RBAC matrix documentation (`docs/rbac-matrix.md`)

### Added — Infrastructure
- PowerShell module (`modules/ADHomeLab/`) with 7 shared functions
- Vagrant alternative (`Vagrantfile` + `vagrant/`) with Hyper-V provider
- Unattend XML files for automated OS installation (Server 2022 + Win11)
- ISO attach script (`hyperv/04-Attach-ISO.ps1`) for push-button deployment
- GPO exports directory (`config/gpo-exports/`)

### Added — Testing
- Pester tests with AD/GPO mocks (`tests/04-Create-Users.Tests.ps1`, `tests/03-Configure-GPOs.Tests.ps1`)
- Password complexity statistical tests (1000 iterations, `tests/04-Create-Users.Password.Tests.ps1`)
- Expanded Pester tests covering data/ and tests/ directories

### Added — Documentation
- Mermaid architecture diagram (`docs/architecture.mmd`)
- Draw.io architecture source (`docs/architecture.drawio`)
- Demo script for interviews (`docs/demo-script.md`)
- Interview prep with 20+ Q&A (`docs/interview-prep.md`)
- Cost analysis comparing on-prem, Azure, AWS (`docs/cost-analysis.md`)
- 6 operational runbooks (`docs/runbooks/RB-001` through `RB-006`)
- CONTRIBUTING.md and CODE_OF_CONDUCT.md
- README badges (CI, license, PowerShell, Pester) and Quick Start section

### Changed
- CI workflow now runs Pester tests after lint
- README updated with badges, quick start, architecture diagram, doc index
- PROJECT.md expanded with phases 7-10, new repo structure, 30-entry skills table

## [0.2.0] - 2026-07-02

### Fixed
- Fixed `param()` block ordering in `hyperv/03-Provision-Clients.ps1` (must be first executable statement)
- Fixed VHD path computation logic in `hyperv/02-Provision-DC01.ps1` (redundant fallback that was always true)
- Added DHCP role installation, scope creation (10.0.0.100-200), and AD authorization to `01-Setup-DC.ps1`
- Fixed static IP configuration to properly remove existing IPs/gateway before setting new ones
- Made `-TargetHost` mandatory in `02-Join-Domain.ps1` to prevent both clients getting the same name
- Replaced invalid `-Options PasswordWithProtectedComputer` with `JoinWithNewName` in domain join
- Removed invalid `-ResetLockoutCount` parameter from `Set-ADDefaultDomainPasswordPolicy`
- Fixed GPO link detection in `03-Configure-GPOs.ps1` (iterating GpoLinks collection instead of broken pipeline)
- Fixed `Invoke-GPUpdate` call (removed invalid `-Force`, added reachability check and Invoke-Command fallback)
- Rewrote `New-RandomPassword` to guarantee complexity requirements (upper, lower, digit, special)
- Added Secure Boot and TPM configuration for Windows 11 client VMs
- Fixed output path in `data/Generate-Users.ps1` (was resolving to wrong directory)
- Added `.SYNOPSIS` help to `tests/Check-Syntax.ps1`

### Added
- DHCP scope configuration (10.0.0.100-200/24) with DNS and router options
- USB storage client-side validation via remote registry check in validation script
- GPO application verification via gpresult on client
- GPO link status check in validation script
- DNS resolution pre-check before domain join
- Pester test job in CI workflow (runs after lint passes)
- Pester tests for data/ and tests/ script syntax
- Pester test for users.csv data file (row count, column validation)
- DHCP troubleshooting section in PROJECT.md
- TPM/Secure Boot troubleshooting in PROJECT.md

### Changed
- CI workflow now triggers on both `main` and `master` branches
- .gitignore uses explicit `!data/users.csv` instead of wildcard pattern
- Scheduled tasks now use SYSTEM principal with Administrator user filter
- SamAccountName sanitized (invalid chars stripped, truncated to 20 chars)
- Validation user count filters by OU=Staff|OU=IT instead of excluding CN=Users

## [0.1.0] - 2026-07-02

### Added
- Initial project structure and repository setup
- Hyper-V VM provisioning scripts (DC01, WIN11-CLIENT01, WIN11-CLIENT02)
- Internal virtual switch configuration
- .gitignore, .gitattributes, LICENSE
- CI workflow for PSScriptAnalyzer linting
- Pester test scaffolding
