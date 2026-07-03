# AD-HomeLab Dashboard

Cross-platform Expo dashboard for browsing AD-HomeLab status, build phases, scripts, validation checks, security controls, and runbooks from web, iOS, or Android.

## Supported Platforms

| Platform | Command | Notes |
|----------|---------|-------|
| Web | `npm run web` | Runs in a browser through Expo web |
| Android | `npm run android` | Requires Android Studio emulator or a device with Expo Go |
| iOS | `npm run ios` | Requires macOS with Xcode simulator or a device with Expo Go |

## Quick Start

```powershell
cd apps/mobile-web
npm install
npm run web
```

Run checks before committing dashboard changes:

```powershell
npm test
```

`npm test` runs TypeScript checking and `scripts/validate-data.mjs`, which validates dashboard data IDs, referenced repo paths, and unsafe static-data patterns.

## What The App Includes

| Screen | Purpose |
|--------|---------|
| Dashboard | Lab summary, topology, next step, quick commands, safety model |
| Phases | Ordered build and operations phases with commands and expected outcomes |
| Scripts | Script catalog with run location, purpose, safety notes, and elevation requirements |
| Validation | Acceptance checks for AD, GPO, users, clients, monitoring, and DR |
| Security | Hardening and monitoring controls with evidence references |
| Runbooks | Mobile-friendly summaries of the six operational runbooks |
| About | Platform usage and security boundary |

## Security Model

This dashboard is intentionally read-only. It does not execute PowerShell, open WinRM sessions, store lab credentials, or make privileged changes from mobile or web.

Privileged tasks remain local to the Hyper-V host, DC01, or client VMs where Windows authentication, elevation prompts, PowerShell execution policy, transcript logging, and operator judgment apply.

A future backend can be added, but it should require authenticated users, explicit authorization, command allowlists, audit logging, request signing, and a constrained Windows agent. Until that exists, the app is a command reference and runbook console only.

## Data Source

The app uses static TypeScript data in `src/data/labData.ts`. Keep this file aligned with repository scripts and docs when adding new automation.

When adding new scripts or runbooks:

1. Add the repository artifact first.
2. Add the dashboard entry to `src/data/labData.ts`.
3. Run `npm test` from `apps/mobile-web`.
4. Confirm `scripts/validate-data.mjs` reports all referenced paths as present.

## Build Notes

- Expo SDK 51 is used for one codebase across web, Android, and iOS.
- The UI avoids native-only dependencies so the web target stays simple.
- The committed `package-lock.json` keeps installs repeatable in CI.
