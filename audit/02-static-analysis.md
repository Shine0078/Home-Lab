# 02 Static Analysis

I ran `PSScriptAnalyzer` across every repository `.ps1` file using a local copy of the module because the machine’s `PowerShellGet` install was broken.

## Before

Initial analyzer output contained real errors and a large number of warnings:

- `scripts/04-Create-Users.ps1`, `scripts/09-Restore-Lab.ps1`, `vagrant/bootstrap-dc.ps1`, and `vagrant/bootstrap-client.ps1` used `ConvertTo-SecureString -AsPlainText -Force`
- `scripts/06-Harden-Baseline.ps1` used `Set-ItemProperty -Type`, which is not valid for those registry writes
- `scripts/07-Setup-Monitoring.ps1` had placeholder logon-triggered alert tasks and a wrong WEF feature installation path
- `scripts/01-Setup-DC.ps1` used the host IP as the DHCP scope option target instead of the scope network
- `scripts/02-Join-Domain.ps1` used a logon-based resume task that was brittle after reboot
- `scripts/03-Configure-GPOs.ps1` used a broken reachability test pattern
- `tests/04-Create-Users.Password.Tests.ps1` used `Invoke-Expression` to load test helpers
- Almost every script emitted `PSUseBOMForUnicodeEncodedFile` and `PSAvoidUsingWriteHost`

## After

The repo is now analyzer-clean for Error and Warning severity.

Key fixes:

- Replaced plaintext secure-string conversions with manual `SecureString` builders
- Fixed the DHCP scope ID and client resume trigger logic
- Reworked monitoring to use an actual event-triggered scheduled-task XML flow
- Corrected firewall policy registry values and GPO restore manifest parsing
- Replaced repo-wide `Write-Host` logging helpers with output-stream logging
- Normalized all PowerShell files to UTF-8 with BOM
- Removed `Invoke-Expression` from test scaffolding

## Notes

- `dsc/LabDscConfiguration.ps1` still depends on DSC resource modules at runtime, but that no longer produces analyzer errors.
- The analyzer itself is now part of the repo evidence trail under `.tools/PSScriptAnalyzer/`.
