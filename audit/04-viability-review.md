# 04 Viability Review

This pass focused on whether a stranger could clone the repo and actually use it with the README and PROJECT guidance.

## What Was Blocking Real Use

- The docs overstated the automation level of the ISO attach workflow.
- There was no teardown path for cleaning up lab-specific AD objects and monitoring tasks.
- The repo did not clearly call out the DSC module dependencies or the collector feature needed for monitoring.
- Some validation and syntax helpers were too noisy to trust as smoke tests.

## What I Added Or Fixed

- Added [`scripts/00-Teardown-Lab.ps1`](../scripts/00-Teardown-Lab.ps1) for safe lab cleanup.
- Updated [`README.md`](../README.md) and [`PROJECT.md`](../PROJECT.md) to say the OS install still has a manual step.
- Added troubleshooting notes for DHCP scope creation, WEF, DSC dependencies, and Windows 11 VM setup.
- Kept the validation script as the authoritative post-change health check and made its output cleaner.
- Left the unattended-install limitation documented instead of pretending the repo fully solves it.

## Real-World Usage Flow Now

1. Read the prerequisites and install Hyper-V.
2. Provision the VMs.
3. Install the OSs manually and enable WinRM.
4. Run the DC, join, GPO, user, hardening, monitoring, backup, and RBAC scripts.
5. Validate the lab with the built-in checks.
6. Use the teardown script when the lab needs to be reset.

## Remaining Gaps

- Full unattended OS media creation still depends on an external ISO-authoring tool or a different build process.
- The teardown script intentionally stops short of deleting the forest or VMs so the operator can choose the right decommission path.
- Cloud/ISO licensing and sourcing remain a human decision.

## Net Assessment

The repo is now viable as a reproducible lab project, provided the operator accepts one explicit manual installation step and the documented dependencies.
