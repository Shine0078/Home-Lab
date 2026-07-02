# 01 Inventory

Repo-wide file inventory for `AD-HomeLab` as of this audit pass.

## Top Level

| Path | Purpose | Notes |
|---|---|---|
| `README.md` | Landing page and quick start for the lab | Main entry point for new readers |
| `PROJECT.md` | Full project documentation | More detailed than `README.md`; contains architecture, phases, and repo layout |
| `CHANGELOG.md` | Human-readable release history | Should be kept aligned with actual git history |
| `LICENSE` | MIT license text | Standard project license file |
| `CONTRIBUTING.md` | Contributor guidance | Process/documentation only |
| `CODE_OF_CONDUCT.md` | Community guidelines | Process/documentation only |
| `.gitignore` | Git exclusion rules | Explicitly excludes `logs/`, `output/`, and credential-style CSVs |
| `.gitattributes` | Git attribute settings | Repository hygiene / line-ending control |
| `Vagrantfile` | Alternate Vagrant-based lab provisioning entry point | Separate deployment path from the main Hyper-V workflow |

## CI / Automation

| Path | Purpose | Notes |
|---|---|---|
| `.github/workflows/lint.yml` | CI workflow for linting and tests | Runs repo checks in GitHub Actions |

## Data

| Path | Purpose | Notes |
|---|---|---|
| `data/users.csv` | Source dataset for bulk AD user creation | Explicitly allowed by `.gitignore` |
| `data/monitored-events.csv` | Event catalog for monitoring setup | Drives `scripts/07-Setup-Monitoring.ps1` |
| `data/Generate-Users.ps1` | Helper to generate the users CSV | Data preparation utility, not part of the main lab execution chain |

## Documentation

| Path | Purpose | Notes |
|---|---|---|
| `docs/architecture.mmd` | Mermaid architecture diagram source | Referenced by the docs and README |
| `docs/architecture.drawio` | Editable diagram source | Alternative visual source for the same architecture |
| `docs/backup-strategy.md` | Backup and restore strategy | Supports the DR phase and restore script |
| `docs/cost-analysis.md` | Portfolio-style cost comparison | Documentation only |
| `docs/demo-script.md` | Interview / demo walkthrough | Portfolio and presentation support |
| `docs/interview-prep.md` | Interview prep notes | Documentation only |
| `docs/rbac-matrix.md` | RBAC / delegation matrix | Supports `scripts/11-Setup-RBAC.ps1` |
| `docs/security-baseline.md` | Security control mapping | Supports `scripts/06-Harden-Baseline.ps1` |
| `docs/security-dashboard.md` | Monitoring dashboard and WEF notes | Supports `scripts/07-Setup-Monitoring.ps1` |
| `docs/runbooks/RB-001-DC-Wont-Boot.md` | Recovery runbook | Operational support |
| `docs/runbooks/RB-002-Client-Cant-Join-Domain.md` | Recovery runbook | Operational support |
| `docs/runbooks/RB-003-GPO-Not-Applying.md` | Recovery runbook | Operational support |
| `docs/runbooks/RB-004-DHCP-Lease-Issues.md` | Recovery runbook | Operational support |
| `docs/runbooks/RB-005-User-Locked-Out.md` | Recovery runbook | Operational support |
| `docs/runbooks/RB-006-Backup-Restore.md` | Recovery runbook | Operational support |

## DSC

| Path | Purpose | Notes |
|---|---|---|
| `dsc/README.md` | DSC usage notes | Alternative declarative path |
| `dsc/LabDscConfiguration.ps1` | DSC configuration for DC01 | Not the default execution path |
| `dsc/Start-DscRun.ps1` | Compiles and applies the DSC config | Wrapper around the DSC configuration |

## Hyper-V Provisioning

| Path | Purpose | Notes |
|---|---|---|
| `hyperv/README.md` | Hyper-V-specific setup guide | Companion docs for the phase-1 scripts |
| `hyperv/01-Create-Switch.ps1` | Creates the internal vSwitch | Host-side network foundation |
| `hyperv/02-Provision-DC01.ps1` | Creates the DC01 VM | Creates the domain controller VM shell |
| `hyperv/03-Provision-Clients.ps1` | Creates the two Windows 11 client VMs | Creates client VM shells |
| `hyperv/04-Attach-ISO.ps1` | Attaches installation media and starts installs | Automation helper for the OS install stage |
| `hyperv/Provision-All.ps1` | Orchestrates the Hyper-V phase | Sequential wrapper over the phase-1 scripts |
| `hyperv/unattend/unattend_Server2022.xml` | Unattended install answer file for Server 2022 | Provisioning support artifact |
| `hyperv/unattend/unattend_Win11.xml` | Unattended install answer file for Windows 11 | Provisioning support artifact |

## PowerShell Module

| Path | Purpose | Notes |
|---|---|---|
| `modules/ADHomeLab/ADHomeLab.psd1` | Module manifest | Exports shared helper functions |
| `modules/ADHomeLab/ADHomeLab.psm1` | Shared helper functions | Logging, password generation, AD/GPO helpers |

## Main Lab Scripts

| Path | Purpose | Notes |
|---|---|---|
| `scripts/01-Setup-DC.ps1` | Domain controller bootstrap | Configures IP, roles, forest, OU structure, DHCP, DNS |
| `scripts/02-Join-Domain.ps1` | Client domain join | Renames the client, points DNS at DC01, joins the domain |
| `scripts/03-Configure-GPOs.ps1` | Baseline GPO configuration | Creates USB restriction and password policy enforcement |
| `scripts/04-Create-Users.ps1` | Bulk AD user creation | Reads `data/users.csv` and creates 50 accounts |
| `scripts/05-Validate-Lab.ps1` | Lab validation checks | Verifies the expected domain/GPO/user state |
| `scripts/06-Harden-Baseline.ps1` | Security hardening baseline | Applies security and audit settings on DC01 |
| `scripts/07-Setup-Monitoring.ps1` | WEF and monitoring setup | Configures event collection and alerts |
| `scripts/08-Backup-Lab.ps1` | Backup/export workflow | Exports GPOs, AD data, DNS, OU structure, and checkpoints |
| `scripts/09-Restore-Lab.ps1` | Restore workflow | Restores from a backup directory |
| `scripts/10-Advanced-GPOs.ps1` | Advanced GPO hardening | Adds additional policy controls beyond the baseline |
| `scripts/11-Setup-RBAC.ps1` | RBAC and delegation setup | Creates groups and OU delegation rules |

## Tests

| Path | Purpose | Notes |
|---|---|---|
| `tests/Check-Syntax.ps1` | Quick syntax pass over script files | Lightweight local smoke check |
| `tests/Project.Tests.ps1` | Repo-level validation tests | Checks syntax, help text, `.gitignore`, and dataset shape |
| `tests/03-Configure-GPOs.Tests.ps1` | Logic/unit coverage for GPO script | Uses mocks rather than live AD/GPO |
| `tests/04-Create-Users.Tests.ps1` | Logic/unit coverage for user creation | Uses mocks and sample data |
| `tests/04-Create-Users.Password.Tests.ps1` | Password generator coverage | Repeated password-complexity checks |

## Vagrant

| Path | Purpose | Notes |
|---|---|---|
| `vagrant/README.md` | Alternate provisioning guide | Describes the Vagrant-based workflow |
| `vagrant/bootstrap-dc.ps1` | Vagrant DC bootstrap script | Simplified alternate to the main DC setup script |
| `vagrant/bootstrap-client.ps1` | Vagrant client bootstrap script | Simplified alternate to the main client join script |

## Observations

- `dsc/` and `vagrant/` are alternate deployment paths, not part of the default Hyper-V/script chain in `README.md`.
- `data/Generate-Users.ps1` is a helper utility rather than a phase script; it is not invoked by the main workflow.
- `docs/cost-analysis.md`, `docs/demo-script.md`, and `docs/interview-prep.md` are portfolio support assets rather than operational inputs.
- `config/gpo-exports/.gitkeep` is a placeholder to keep an otherwise-empty export directory in Git.
- `logs/` and `output/` are runtime directories, intentionally ignored by Git.

## Potentially Orphaned Or Under-Used Items

- `dsc/` and `vagrant/` look externally useful but are not wired into the main quick-start path.
- `docs/architecture.drawio` duplicates the architecture concept already captured in `docs/architecture.mmd`; it is useful as an editable source, but not referenced by automation.
- `data/Generate-Users.ps1` is a support helper, but no main script calls it directly.
- `hyperv/04-Attach-ISO.ps1` and the `hyperv/unattend/*.xml` files are supporting artifacts for phase 1; their value depends on the installer flow being correct.
