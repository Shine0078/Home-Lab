# 03 Logic Review

This pass checked whether each script’s behavior matched its stated purpose, not just whether it parsed.

## Findings and Fixes

- `scripts/01-Setup-DC.ps1`
  - The DHCP scope options were being written against the host IP as the scope ID.
  - Fixed to use `10.0.0.0` so the scope applies to `10.0.0.0/24`.

- `scripts/02-Join-Domain.ps1`
  - The reboot resume task was tied to logon timing and could miss the correct window.
  - Fixed to use an `AtStartup` trigger with `SYSTEM`, which is much more reliable for resuming after the rename reboot.

- `scripts/03-Configure-GPOs.ps1`
  - The client reachability check was using `$?` in a way that could report success even when the ping returned `$false`.
  - Fixed to use the boolean result of `Test-Connection -Quiet` directly.

- `scripts/04-Create-Users.ps1`
  - `SamAccountName` was sanitized after the UPN was built, which could leave the UPN out of sync with the final account name.
  - Fixed by sanitizing first and building the UPN afterward.
  - The password helper now builds a `SecureString` without plaintext conversion.

- `scripts/06-Harden-Baseline.ps1`
  - Registry writes used the wrong cmdlet pattern and would fail at runtime.
  - Fixed with a dedicated registry helper using `New-ItemProperty`.
  - Audit policy calls now invoke `auditpol.exe` directly instead of `Invoke-Expression`.

- `scripts/07-Setup-Monitoring.ps1`
  - The original script created logon-triggered placeholders instead of event-driven alerts.
  - Fixed by creating event-triggered task XML and a real WEF subscription flow.
  - The WEC feature path was corrected to the collector feature instead of backup tooling.

- `scripts/08-Backup-Lab.ps1`
  - Hyper-V host detection was fragile.
  - Fixed to detect the `vmms` service, which is a better signal that the machine is actually a Hyper-V host.

- `scripts/09-Restore-Lab.ps1`
  - Restore logic used the backup folder name instead of the manifest’s original GPO display name.
  - Fixed by parsing the manifest and using the original display name from the backup metadata.

- `scripts/10-Advanced-GPOs.ps1`
  - Firewall policy registry values were written to nested subkeys that do not match the expected policy layout.
  - Fixed to write the correct profile values directly under the profile keys.
  - The domain root DN is now derived from the configured domain name instead of being duplicated as a hardcoded literal.

- `scripts/11-Setup-RBAC.ps1`
  - Empty catch blocks hid errors and made group delegation hard to troubleshoot.
  - Replaced with warning logs.
  - Added `ShouldProcess` semantics to the helper functions that mutate AD state.

- `hyperv/03-Provision-Clients.ps1`
  - Windows 11 client provisioning claimed TPM support but only enabled Secure Boot/encryption state.
  - Fixed to enable a vTPM with `Set-VMKeyProtector` and `Enable-VMTPM`.

- `hyperv/04-Attach-ISO.ps1`
  - The script originally claimed full unattended OS automation even though the workflow was not honest about the remaining manual step.
  - Updated the documentation and log output to state that OOBE still needs human completion unless the media is rebuilt externally.

- `tests/Check-Syntax.ps1`
  - The parser output was leaking into the console.
  - Fixed by discarding the AST output.

- `scripts/00-Teardown-Lab.ps1`
  - Added a missing cleanup path so the repo now has a documented teardown story.

## Validation

- `tests/Check-Syntax.ps1` passes.
- `tests/Project.Tests.ps1` passes.
- The analyzer is clean after the fixes.

## Residual Human Decision

- Full unattended OS installation still depends on external ISO authoring tooling or a different deployment approach.
- That limitation is now documented rather than hidden.
