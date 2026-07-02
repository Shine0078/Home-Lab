# RBAC Delegation Matrix

## Overview

This document maps the role-based access control (RBAC) configuration applied by `scripts/11-Setup-RBAC.ps1`. It defines who can do what in which OU, demonstrating least-privilege delegation.

## Security Groups

| Group Name | Scope | Description |
|------------|-------|-------------|
| `GG-IT-Admins` | Global | IT administrators — full control of IT OU |
| `GG-Sales-Users` | Global | Sales department users |
| `GG-Finance-Users` | Global | Finance department users |
| `GG-Ops-Users` | Global | Operations department users |
| `GG-HR-Users` | Global | HR department users |
| `GG-Helpdesk-Operators` | Global | Helpdesk — reset passwords, unlock accounts |
| `DL-Workstations-Admins` | DomainLocal | Local admin on workstation computers |

## Delegation Matrix

### OU=IT

| Trustee | Right | Details |
|---------|-------|--------|
| `GG-IT-Admins` | Full Control | Full management of IT OU and child objects |
| `GG-Helpdesk-Operators` | Reset Password | Can reset passwords for IT users |

### OU=Staff

| Trustee | Right | Details |
|---------|-------|--------|
| `GG-IT-Admins` | Read Only | Can view Staff user accounts |
| `GG-Helpdesk-Operators` | Reset Password | Can reset passwords for Staff users |
| `GG-Helpdesk-Operators` | Unlock Account | Can unlock Staff user accounts |
| `GG-Sales-Users` | Read Only | Can view Staff user accounts |
| `GG-Finance-Users` | Read Only | Can view Staff user accounts |
| `GG-Ops-Users` | Read Only | Can view Staff user accounts |
| `GG-HR-Users` | Read Only | Can view Staff user accounts |

### OU=Workstations

| Trustee | Right | Details |
|---------|-------|--------|
| `GG-IT-Admins` | Read Only | Can view workstation computer accounts |

### OU=Groups

| Trustee | Right | Details |
|---------|-------|--------|
| Domain Admins | Full Control | Default |

## Extended Right GUIDs

| Right | GUID | Description |
|-------|------|-------------|
| Reset Password | `00299570-246d-11d0-a768-00aa006e0529` | Allows password reset without knowing current password |
| Unlock Account | `ccc2dc7d-a6bf-11d2-bb15-00c04f8f0d85` | Allows unlocking of locked-out accounts |

## Group Membership Auto-Population

The script automatically adds users to department groups based on the `Department` attribute:
- Users with `Department=IT` → `GG-IT-Admins`
- Users with `Department=Sales` → `GG-Sales-Users`
- Users with `Department=Finance` → `GG-Finance-Users`
- Users with `Department=Ops` → `GG-Ops-Users`
- Users with `Department=HR` → `GG-HR-Users`

## Verification

```powershell
# View all security groups
Get-ADGroup -Filter * -SearchBase "OU=Groups,DC=homelab,DC=local" | Select-Object Name, GroupScope, Description

# Check delegation on an OU
(Get-Acl "AD:\OU=Staff,DC=homelab,DC=local").Access | Where-Object { $_.IdentityReference -like "*GG-*" }

# Check group membership
Get-ADGroupMember -Identity "GG-IT-Admins"
```

## What this demonstrates

| Component | Skill |
|-----------|-------|
| Security group design | RBAC architecture, group nesting |
| OU delegation | Active Directory ACLs, least-privilege |
| Extended right GUIDs | Deep AD knowledge (password reset, unlock) |
| Auto-population | Dynamic group management via scripting |
| Delegation matrix | Documentation and compliance readiness |
