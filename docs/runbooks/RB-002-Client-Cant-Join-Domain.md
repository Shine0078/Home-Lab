# RB-002: Client Can't Join Domain

## Symptom
WIN11-CLIENT01 or WIN11-CLIENT02 cannot join homelab.local. Error messages include:
- "The domain name could not be found"
- "An attempt to resolve the DNS name of a DC failed"
- "The specified network name is no longer available"

## Diagnosis

### Step 1: Verify DC01 is running
```powershell
# On Hyper-V host:
Get-VM -Name DC01 | Select-Object Name, State
```

### Step 2: Check DNS resolution on the client
```powershell
# On the client VM:
nslookup homelab.local 10.0.0.10
Resolve-DnsName -Name homelab.local -Server 10.0.0.10
```

### Step 3: Check client DNS settings
```powershell
# On the client VM:
Get-DnsClientServerAddress | Select-Object InterfaceAlias, ServerAddresses
```
Expected: `10.0.0.10`

### Step 4: Check network connectivity
```powershell
# On the client VM:
Test-NetConnection -ComputerName 10.0.0.10 -Port 53  # DNS
Test-NetConnection -ComputerName 10.0.0.10 -Port 389 # LDAP
Test-NetConnection -ComputerName 10.0.0.10 -Port 445 # SMB
```

### Step 5: Check firewall on DC01
```powershell
# On DC01:
Get-NetFirewallProfile | Select-Object Name, Enabled
Get-NetFirewallRule -DisplayGroup 'Active Directory Domain Services' | Select-Object Enabled
```

## Resolution

### Fix 1: Set correct DNS on client
```powershell
$adapter = Get-NetAdapter -Physical | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses '10.0.0.10'
```

### Fix 2: Clear DNS cache
```powershell
ipconfig /flushdns
Clear-DnsClientCache
```

### Fix 3: Verify DNS SRV records on DC01
```powershell
# On DC01:
Resolve-DnsName -Name _ldap._tcp.dc._msdcs.homelab.local -Type SRV
```
If missing, restart Netlogon: `Restart-Service Netlogon`

### Fix 4: Check virtual switch connectivity
```powershell
# On Hyper-V host:
Get-VMSwitch -Name AD-Lab-Switch
Get-VMNetworkAdapter -VMName WIN11-CLIENT01 | Select-Object VMName, SwitchName, IPAddresses
```

### Fix 5: Use correct credentials
Domain join credentials format: `HOMELAB\Administrator` (NetBIOS domain name)

## Verification
```powershell
# On the client:
nltest /sc_query:homelab.local
systeminfo | Select-String "Domain"
```

## Prevention
- Always run `scripts/02-Join-Domain.ps1` which includes DNS verification
- Verify DC01 is running before attempting domain join
