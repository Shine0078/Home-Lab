# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
