# DSC Configuration (Desired State Configuration)

## Overview

This folder contains a declarative DSC configuration that achieves the same
end state as the imperative `scripts/01-Setup-DC.ps1`. DSC is the industry
standard for Windows configuration management and demonstrates a different
paradigm: you declare **what** the system should look like, not **how** to
get there.

## When to use DSC vs imperative scripts

| Approach | Best for | Trade-off |
|----------|----------|-----------|
| **DSC** (this folder) | Production environments, drift detection, CI/CD pipelines | Requires DSC resource modules installed; slower first run |
| **Imperative** (`scripts/`) | Quick lab setup, debugging, learning | No external dependencies; no drift detection |

## Files

| File | Description |
|------|-------------|
| `LabDscConfiguration.ps1` | DSC configuration declaring desired state for DC01 |
| `Start-DscRun.ps1` | Runner: installs resources, compiles MOF, applies config |

## Usage

```powershell
# ON DC01, as Administrator:
cd C:\Path\To\AD-HomeLab\dsc
.\Start-DscRun.ps1
```

## Prerequisites

- Windows Server 2022
- PowerShell 5.1+
- DSC resources (auto-installed by Start-DscRun.ps1):
  - `xActiveDirectory`
  - `xDhcpServer`
  - `xNetworking`
  - `xComputerManagement`

## Verifying and testing drift

```powershell
# Check last configuration status
Get-DscConfigurationStatus

# Test if the system has drifted from desired state
Test-DscConfiguration -Detailed
```

## What this demonstrates

- **Declarative config management** — the same paradigm as Ansible, Chef, Puppet
- **Idempotency** — DSC applies only what's needed, safe to re-run
- **Drift detection** — `Test-DscConfiguration` detects manual changes
- **Dependency ordering** — `DependsOn` ensures correct execution order
