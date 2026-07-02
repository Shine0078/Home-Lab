# 05 Documentation Review

The docs were updated to match the codebase after the hardening pass.

## README.md

- The quick start now says “attach installation media and complete OS install” instead of claiming full unattended automation.
- The Hyper-V component summary now describes media staging instead of implying a fully automated install.
- The architecture, status, and documentation index still match the current project shape.

## PROJECT.md

- The overview now reflects that the initial OS install and WinRM enablement are explicit manual steps.
- The phase table now describes `hyperv/04-Attach-ISO.ps1` as staging unattend media instead of pretending it completes the whole install.
- The repository structure now accounts for the new `scripts/00-Teardown-Lab.ps1`.
- A Phase 0 cleanup section was added.
- The troubleshooting section now includes the specific issues uncovered during review:
  - TPM/Secure Boot setup
  - missing DSC dependencies
  - WEF collector feature availability
  - DHCP scope-ID mistakes

## CHANGELOG.md

- The changelog already contained a real release history up to `1.0.0`.
- I added an `Unreleased` entry so the current hardening pass is tracked explicitly.
- The new entry summarizes the most important logic fixes and documentation alignment work.

## What a Reviewer Would Expect

- Clear distinction between automated and manual steps.
- A cleanup path.
- Troubleshooting guidance tied to actual failure modes.
- A changelog that reflects the current work, not just the historical release milestone.

## Net Result

The docs now describe the repo’s current behavior instead of the earlier aspirational version of the project.
