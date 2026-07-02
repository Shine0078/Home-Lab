# Security Monitoring Dashboard

## Overview

This document describes the security monitoring configuration applied by `scripts/07-Setup-Monitoring.ps1`. It covers Windows Event Forwarding (WEF), monitored event types, alerting, and how to view the collected events.

## Architecture

```
┌──────────────┐     WEF (HTTP:5985)     ┌──────────────┐
│ WIN11-       │ ──────────────────────> │              │
│ CLIENT01     │  ForwardedEvents        │              │
├──────────────┤                         │    DC01      │
│ WIN11-       │ ──────────────────────> │  (Collector)  │
│ CLIENT02     │  ForwardedEvents        │              │
└──────────────┘                         │  Forwarded   │
                                         │  Events Log  │
                                         │              │
                                         │  Alert Tasks │
                                         │  (Critical)  │
                                         └──────────────┘
```

## Windows Event Forwarding (WEF)

### Collector: DC01

- **Service**: Windows Event Collector (`Wecsvc`), Automatic startup
- **Firewall rule**: COM-Network-In-TCP (port 5985)
- **Subscription**: `AD-Lab-Security-Events` (SourceInitiated, HTTP transport)
- **Log**: `ForwardedEvents` (view in Event Viewer > Forwarded Events)
- **Heartbeat**: 300 seconds (5 minutes)
- **Content format**: RenderedText

### Forwarders: WIN11-CLIENT01, WIN11-CLIENT02

- **Registry**: `HKLM\SOFTWARE\Policies\Microsoft\Windows\EventLog\EventForwarding\SubscriptionManager`
- **Target**: `http://dc01.homelab.local:5985/wsman/SubscriptionManager/WEC`

## Monitored Events

See `data/monitored-events.csv` for the full list. Key categories:

### Account Management (Event IDs 4720-4743)
| Event ID | Description | Severity |
|----------|-------------|----------|
| 4720 | User account created | High |
| 4726 | User account deleted | Critical |
| 4740 | Account locked out | High |
| 4724 | Password reset | High |
| 4737 | Security group changed | Medium |

### Logon/Logoff (Event IDs 4624-4648)
| Event ID | Description | Severity |
|----------|-------------|----------|
| 4624 | Successful logon | Informational |
| 4625 | Failed logon | High |
| 4648 | Logon with explicit credentials | High |

### Privilege Use & Policy Change
| Event ID | Description | Severity |
|----------|-------------|----------|
| 4672 | Special privileges assigned | High |
| 4719 | Audit policy changed | Critical |
| 4739 | Domain policy changed | Critical |

### Audit & Integrity
| Event ID | Description | Severity |
|----------|-------------|----------|
| 1102 | Audit log cleared | Critical |

## Alerting

Scheduled tasks are created for all **Critical** severity events. When triggered,
they write an event to the Application log with source `AD-Lab-Monitoring` and
event ID 9999.

### Viewing Alerts

```powershell
# View all monitoring alerts
Get-EventLog -LogName Application -Source "AD-Lab-Monitoring" -Newest 50

# View forwarded security events
Get-WinEvent -LogName ForwardedEvents -MaxEvents 50

# View specific event type
Get-WinEvent -FilterHashtable @{LogName='ForwardedEvents'; Id=4720} -MaxEvents 10
```

## PowerShell Script Block Logging

Script block logging (enabled by `06-Harden-Baseline.ps1`) captures all
PowerShell execution in `Microsoft-Windows-PowerShell/Operational` log.
These events are forwarded to DC01 via the WEF subscription.

```powershell
# View PowerShell script blocks executed on lab machines
Get-WinEvent -LogName ForwardedEvents -FilterHashtable @{ProviderName='Microsoft-Windows-PowerShell'} -MaxEvents 20
```

## What this demonstrates

| Component | Skill |
|-----------|-------|
| WEF architecture | Centralized log management, SIEM-like setup |
| Event subscription config | Windows Event Collector service, XML queries |
| Audit policy | Compliance auditing, security baselines |
| Alert scheduled tasks | Automated incident response triggers |
| PowerShell logging | Threat hunting, forensic analysis capability |
| Script block logging | Detecting obfuscated/malicious PowerShell |
