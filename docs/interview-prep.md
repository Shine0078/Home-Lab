# Interview Prep — AD/Sysadmin Technical Questions

## Active Directory Concepts

### Q: What is the difference between a domain, forest, and tree?
- **Domain**: A logical grouping of network objects (users, computers) sharing a central directory (AD). Example: `homelab.local`.
- **Tree**: A hierarchical arrangement of domains sharing a contiguous namespace. Example: `us.homelab.local` and `eu.homelab.local`.
- **Forest**: A collection of one or more trees that share a common schema, configuration, and global catalog. Trusts between trees in a forest are transitive.

### Q: What is the SYSVOL folder?
SYSVOL is a shared directory on all domain controllers that stores:
- Group Policy templates (GPT)
- Logon scripts
- Replicated via FRS (older) or DFSR (modern)
- Path: `C:\Windows\SYSVOL`

### Q: What is the difference between Global, Universal, and Domain Local groups?
- **Global**: Members from the same domain only. Used for user accounts. Can be granted permissions in any domain in the forest.
- **Universal**: Members from any domain in the forest. Good for cross-domain access. Stored in the Global Catalog.
- **Domain Local**: Members from any domain, but only granted permissions within the same domain. Used for resource access.

### Q: What is a Fine-Grained Password Policy (FGPP)?
FGPP allows different password settings for different users or groups within the same domain. The Default Domain Policy applies to all users; FGPP overrides it for specific groups. Configured via `New-ADFineGrainedPasswordPolicy`.

### Q: What is the KCC (Knowledge Consistency Checker)?
The KCC is a built-in process that runs on every DC. It automatically generates and maintains the replication topology between domain controllers. It runs every 15 minutes by default.

## Group Policy

### Q: How does GPO processing order work?
1. Local policy
2. Site-linked GPOs
3. Domain-linked GPOs
4. OU-linked GPOs (parent to child)
5. Child OU GPOs override parent OU GPOs (unless Enforced/NoOverride is set)

### Q: What is the difference between GPO Preferences and GPO Settings?
- **Settings**: Enforced — the setting is applied and cannot be changed by the user (e.g., a registry key is set and locked).
- **Preferences**: Desired — the setting is applied but the user can change it afterward (e.g., drive mapping, registry key set but not locked).

### Q: How do you troubleshoot a GPO not applying?
1. `gpupdate /force` on the client
2. `gpresult /r` to see applied GPOs
3. `gpresult /h report.html` for detailed HTML report
4. Check if the computer/user is in the correct OU
5. Check GPO link status and security filtering
6. Check WMI filter
7. Look for Event ID 1058/1006 (SYSVOL access issues)

## DNS in AD

### Q: Why does AD require DNS?
AD uses DNS for service location (SRV records). When a client needs to find a domain controller, it queries DNS for `_ldap._tcp.dc._msdcs.domain.com`. Without DNS, clients cannot locate DCs, logon fails, and replication breaks.

### Q: What are SRV records?
Service Resource Records map a service name to a host name and port. AD registers SRV records for:
- `_ldap._tcp` — LDAP service
- `_kerberos._tcp` — Kerberos authentication
- `_gc._tcp` — Global Catalog
- `_ldap._tcp.pdc._msdcs` — PDC emulator

### Q: What is a conditional forwarder?
A DNS server configured to forward queries for a specific domain to a specific server. Example: forward all `corp.example.com` queries to 10.0.0.5.

## Security

### Q: What is PrintNightmare and how do you mitigate it?
PrintNightmare (CVE-2021-34527) is a remote code execution vulnerability in the Print Spooler service. Mitigation:
1. Disable Print Spooler on DCs (`Set-Service Spooler -StartupType Disabled`)
2. Restrict print driver installation via GPO
3. Install security updates

### Q: What is LmCompatibilityLevel?
Controls which LAN Manager authentication protocols are allowed:
- 0: Send LM and NTLM responses (insecure)
- 1: Send LM and NTLM; use NTLMv2 if negotiated
- 2: Send NTLM only
- 3-5: Send NTLMv2 only (5 = refuse LM/NTLMv1, most secure)

### Q: What is SMB signing and why is it important?
SMB signing adds a cryptographic signature to each SMB packet, ensuring:
- **Integrity**: Packet wasn't modified in transit
- **Authentication**: Sender is who they claim to be
- Prevents SMB relay attacks (where an attacker forwards SMB authentication to another server)

## PowerShell

### Q: What is the difference between $ErrorActionPreference and -ErrorAction?
- `$ErrorActionPreference`: Global default for how errors are handled. Set at script scope.
- `-ErrorAction`: Per-cmdlet override. Takes precedence over the global preference.

### Q: What is #Requires?
`#Requires` specifies prerequisites that must be met before a script runs:
- `#Requires -RunAsAdministrator`
- `#Requires -Version 5.1`
- `#Requires -Modules ActiveDirectory,GroupPolicy`
- `#Requires -PSEdition Desktop`

### Q: How do you make a PowerShell script idempotent?
Check state before acting:
```powershell
if (-not (Get-ADUser -Filter "SamAccountName -eq 'jdoe'")) {
    New-ADUser -SamAccountName 'jdoe' ...
}
```
Use `-ErrorAction SilentlyContinue` on "get" operations to avoid errors if the object doesn't exist.

## Disaster Recovery

### Q: What is the difference between a backup and a snapshot?
- **Backup**: Copies data to a separate location. Survives if the original is deleted. Good for long-term retention.
- **Snapshot**: Point-in-time VM state. Tied to the original storage. Lost if the VM or datastore is deleted. Not a backup.

### Q: What is an authoritative restore?
An authoritative restore marks specific AD objects as the authoritative version, causing them to replicate to all other DCs. Used when objects are accidentally deleted. Performed by:
1. Restart DC in DSRM
2. Restore from backup (`ntdsutil`)
3. Mark objects as authoritative (`ntdsutil authoritative restore`)
4. Reboot normally

## Networking

### Q: What is the difference between an internal and external virtual switch?
- **Internal**: VMs can talk to each other and the host, but not the external network. Good for isolated labs.
- **External**: VMs can talk to the external network through the host's physical NIC.
- **Private**: VMs can only talk to each other, not the host or external network.

### Q: What port does WinRM use?
- HTTP: 5985 (default)
- HTTPS: 5986 (requires certificate)
