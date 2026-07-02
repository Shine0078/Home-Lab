# 00 Summary

This audit pass found and fixed the following issues across `AD-HomeLab`:

## Broken or Risky Behavior

- DHCP scope options were written against the wrong scope ID.
- Client reboot resume handling was brittle after rename/reboot operations.
- The user creation and restore scripts used insecure plaintext conversion patterns.
- The hardening script used invalid registry write patterns.
- Monitoring used placeholder logon-triggered tasks instead of event-driven alerts.
- GPO restore logic used the backup folder name instead of the backup manifest metadata.
- Windows 11 VM provisioning did not actually enable vTPM correctly.
- The syntax helper leaked parser objects to the console.

## What Was Fixed

- Corrected the DHCP scope ID and related troubleshooting guidance.
- Hardened the secure-string handling in user creation, restore, and Vagrant bootstrap scripts.
- Reworked monitoring and WEF setup so the collector and alerts are event-driven.
- Fixed the firewall/GPO restore logic and the client VM TPM configuration.
- Added a teardown script for safe lab cleanup.
- Normalized the PowerShell formatting and made the repo analyzer-clean.
- Updated the README, PROJECT guide, and CHANGELOG to reflect reality.

## What Was Added

- [`scripts/00-Teardown-Lab.ps1`](../scripts/00-Teardown-Lab.ps1)
- [`audit/01-inventory.md`](./01-inventory.md)
- [`audit/02-static-analysis.md`](./02-static-analysis.md)
- [`audit/03-logic-review.md`](./03-logic-review.md)
- [`audit/04-viability-review.md`](./04-viability-review.md)
- [`audit/05-documentation-review.md`](./05-documentation-review.md)

## Still Requiring Human Decision

- Full unattended ISO authoring is still external to the repo.
- Licensing/source-of-truth for Windows Server and Windows 11 ISO media remains up to the operator.
- Whether to decommission the forest or the Hyper-V VMs after teardown remains a separate operational choice.

## Validation

- `tests/Check-Syntax.ps1` passes.
- `tests/Project.Tests.ps1` passes.
- `PSScriptAnalyzer` is clean at Error and Warning severity.

## Final Take

The repo now tells a coherent operational story, and the scripts are much closer to what a real operator would expect to run successfully end-to-end.
