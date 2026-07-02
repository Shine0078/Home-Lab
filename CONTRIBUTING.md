# Contributing to AD-HomeLab

Thank you for your interest in contributing! This project is a portfolio/lab environment, but contributions are welcome.

## How to Contribute

### Reporting Issues
1. Check existing issues before creating a new one
2. Include: OS version, PowerShell version, error message, steps to reproduce
3. Attach the relevant log file from `logs/` (sanitize any credentials first)

### Submitting Changes
1. Fork the repository
2. Create a feature branch: `git checkout -b feat/your-feature`
3. Make your changes following the conventions below
4. Run tests: `Invoke-Pester -Path tests/`
5. Run syntax check: `.\tests\Check-Syntax.ps1`
6. Commit with Conventional Commits format
7. Open a Pull Request

### Conventional Commits
```
<type>(<scope>): <summary>

- Bullet point 1
- Bullet point 2
```

Types: `feat`, `fix`, `docs`, `refactor`, `chore`, `test`

### Code Conventions
- All scripts must have comment-based help (`.SYNOPSIS`, `.DESCRIPTION`)
- All scripts must be idempotent (safe to re-run)
- Use `Set-StrictMode -Version Latest` and `$ErrorActionPreference = 'Stop'`
- Log everything to `logs/`
- Use the `ADHomeLab` module for shared functions where possible
- Never commit credentials, CSVs with passwords, or log files

### Testing
- All new scripts must pass `tests\Check-Syntax.ps1`
- Add Pester tests for any new logic
- Mock AD/GPO cmdlets — tests must not require a real domain controller

## Project Structure
See `PROJECT.md` for the full repository layout and design decisions.
