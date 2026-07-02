# AD-HomeLab

A fully scripted, portfolio-grade Active Directory home lab built on Hyper-V with Windows Server 2022 and Windows 11 Pro clients.

## Quick Start

See [PROJECT.md](PROJECT.md) for full documentation, prerequisites, and step-by-step instructions.

## What's Inside

| Component | Description |
|-----------|-------------|
| `hyperv/` | Hyper-V VM provisioning scripts (switch, DC, clients) |
| `scripts/` | Domain setup, join, GPO, user creation, validation |
| `data/` | User CSV dataset (50 accounts across 5 departments) |
| `tests/` | Pester tests for script validation |
| `.github/workflows/` | CI: PSScriptAnalyzer linting |

## Status

- **Hypervisor**: Hyper-V (Windows 11 host)
- **Domain**: homelab.local
- **VMs**: DC01, WIN11-CLIENT01, WIN11-CLIENT02
- **GPOs**: USB storage restriction, password policy enforcement
- **Users**: 50 bulk-created AD accounts via PowerShell

## License

MIT
