# RB-004: DHCP Lease Issues

## Symptom
Client VMs are not getting IP addresses from DHCP, or getting APIPA (169.254.x.x) addresses.

## Diagnosis

### Step 1: Check DHCP service on DC01
```powershell
# On DC01:
Get-Service DHCPServer | Select-Object Name, Status, StartType
```

### Step 2: Check DHCP scope
```powershell
# On DC01:
Get-DhcpServerv4Scope
Get-DhcpServerv4ScopeStatistics
```

### Step 3: Check DHCP authorization
```powershell
# On DC01:
Get-DhcpServerInDC | Where-Object { $_.IPAddress -eq '10.0.0.10' }
```

### Step 4: Check client IP configuration
```powershell
# On the client:
ipconfig /all
Get-NetIPAddress -AddressFamily IPv4
```

### Step 5: Check for IP conflicts
```powershell
# On DC01:
Get-DhcpServerv4Lease -ScopeId 10.0.0.0
```

## Resolution

### Fix 1: Authorize DHCP in AD
```powershell
# On DC01:
Add-DhcpServerInDC -IPAddress 10.0.0.10 -DnsName 'DC01.homelab.local'
Restart-Service DHCPServer -Force
```

### Fix 2: Recreate scope if missing
```powershell
Add-DhcpServerv4Scope -Name 'AD-Lab-Scope' -StartRange '10.0.0.100' -EndRange '10.0.0.200' -SubnetMask '255.255.255.0' -State Active
Set-DhcpServerv4OptionValue -ScopeId '10.0.0.0' -DnsServer '10.0.0.10' -Router '10.0.0.1'
```

### Fix 3: Release and renew on client
```powershell
# On the client:
ipconfig /release
ipconfig /renew
```

### Fix 4: Check firewall on DC01
```powershell
# DHCP uses UDP ports 67 (server) and 68 (client)
Get-NetFirewallRule -DisplayGroup 'DHCP Server' | Select-Object Enabled
```

## Verification
```powershell
# On the client:
ipconfig /all
# Should show IP in 10.0.0.100-200 range, DHCP server 10.0.0.10, DNS 10.0.0.10
```

## Prevention
- The `01-Setup-DC.ps1` script handles DHCP authorization and scope creation
- Re-run the script if DHCP state is inconsistent (it's idempotent)
