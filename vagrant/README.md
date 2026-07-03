# Vagrant Alternative

## Overview

This folder contains an alternative deployment method using [Vagrant](https://www.vagrantup.com/) with the Hyper-V provider. Vagrant provides a declarative way to provision VMs and is widely recognized in the DevOps community.

## When to use Vagrant vs raw Hyper-V scripts

| Approach | Best for | Trade-off |
|----------|----------|-----------|
| **Vagrant** (Vagrantfile) | Quick spin-up/teardown, DevOps familiarity | Requires Vagrant install + pre-built boxes |
| **Raw Hyper-V** (`hyperv/`) | Full control, no external dependencies | More manual, requires ISO handling |

## Prerequisites

- [Vagrant](https://developer.hashicorp.com/vagrant/downloads) installed
- Vagrant Hyper-V provider (included on Windows)
- Windows boxes from Vagrant Cloud (auto-downloaded on first run)

## Usage

Set a unique lab Administrator password before running Vagrant. The value is read from the environment and is not stored in git.

```powershell
$env:AD_HOMELAB_ADMIN_PASSWORD = 'Use-A-Unique-Lab-Password!'
```

```bash
# Start all VMs
vagrant up

# Start a single VM
vagrant up dc01
vagrant up win11-client01

# SSH/WinRM into a VM
vagrant winrm dc01

# Destroy all VMs
vagrant destroy -f

# Destroy a single VM
vagrant destroy win11-client01 -f
```

## Configuration

Edit the `Vagrantfile` to change:
- VM memory/CPU allocations
- Network configuration (static IPs, DHCP)
- Vagrant box names
- Provisioning scripts

## Provisioning Scripts

| Script | Purpose |
|--------|---------|
| `bootstrap-dc.ps1` | Installs AD DS, DNS, DHCP, promotes to forest |
| `bootstrap-client.ps1` | Sets DNS, renames, joins domain |

These are simplified versions of the scripts in `scripts/`. Credentials are passed from `AD_HOMELAB_ADMIN_PASSWORD`; in production, use a proper secrets manager such as Azure Key Vault, HashiCorp Vault, or Windows Credential Manager.
