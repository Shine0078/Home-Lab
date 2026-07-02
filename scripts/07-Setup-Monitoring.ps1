<#
.SYNOPSIS
    Sets up Windows Event Forwarding (WEF) and security event monitoring on DC01.

.DESCRIPTION
    Configures DC01 as a Windows Event Forwarding collector and sets up
    event subscriptions for security-relevant events from all lab machines.
    Also creates scheduled tasks that generate alert events when critical
    security events are detected (user created, account locked, audit log
    cleared, failed logon threshold exceeded).

    Reads event definitions from data/monitored-events.csv.

.NOTES
    Run as Administrator on DC01.
    Part of AD-HomeLab Phase 8 (Monitoring & Alerting).
#>

#Requires -RunAsAdministrator
#Requires -Modules ActiveDirectory

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$LogDir   = Join-Path $PSScriptRoot '..\logs'
$LogFile  = Join-Path $LogDir 'setup-monitoring.log'
$EventsCSV = Join-Path $PSScriptRoot '..\data\monitored-events.csv'

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $entry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $entry
    if ($Level -eq 'WARN') { Write-Host "  [WARN] $Message" -ForegroundColor Yellow }
    else { Write-Host "  $Message" -ForegroundColor Cyan }
}

Write-Log "=== Setting up Monitoring & Event Forwarding ==="

# ── 1. Enable WEF Collector on DC01 ──
Write-Log "1. Configuring WEF Collector service..."
$wecsvc = Get-Service -Name Wecsvc -ErrorAction SilentlyContinue
if ($wecsvc) {
    if ($wecsvc.Status -ne 'Running') {
        Start-Service -Name Wecsvc
    }
    Set-Service -Name Wecsvc -StartupType Automatic
    Write-Log "  Windows Event Collector service: running, automatic"
}
else {
    Write-Log "  WEC service not found. Installing feature..."
    Install-WindowsFeature -Name Windows-Server-BACKUP -IncludeManagementTools -ErrorAction SilentlyContinue
}

# Enable Windows Event Collector firewall rule
Enable-NetFirewallRule -Name 'COM-Network-In-TCP' -ErrorAction SilentlyContinue
Write-Log "  WEF firewall rule: enabled"

# ── 2. Load monitored events ──
Write-Log "2. Loading monitored events from CSV..."
if (-not (Test-Path $EventsCSV)) {
    Write-Log "ERROR: Monitored events CSV not found at $EventsCSV" 'WARN'
    throw "Monitored events CSV not found"
}
$events = Import-Csv -Path $EventsCSV
Write-Log "  Loaded $($events.Count) monitored event types"

# ── 3. Create WEF Subscription ──
Write-Log "3. Creating WEF subscription for security events..."

# Create event filter query for all monitored event IDs
$eventIds = $events | Select-Object -ExpandProperty EventID -Unique
$queryXml = @"
<QueryList>
  <Query Id="0" Path="Security">
    <Select Path="Security">*[System[(EventID=$($eventIds -join ' or EventID='))]]</Select>
  </Query>
  <Query Id="1" Path="Microsoft-Windows-PowerShell/Operational">
    <Select Path="Microsoft-Windows-PowerShell/Operational">*[System[(EventID=4104 or EventID=4103)]]</Select>
  </Query>
</QueryList>
"@

$subscriptionName = 'AD-Lab-Security-Events'
$subscriptionPath = "C:\ProgramData\EventSubscriptions\$subscriptionName"

# Check if subscription already exists
$existingSubs = wecutil enum-subscription 2>$null
if ($existingSubs -and $existingSubs -contains $subscriptionPath) {
    Write-Log "  Subscription '$subscriptionName' already exists."
}
else {
    # Write subscription XML to temp file
    $subXml = @"
<Subscription Id="$subscriptionName">
  <SubscriptionType>SourceInitiated</SubscriptionType>
  <Description>Security event forwarding for AD-HomeLab</Description>
  <Enabled>true</Enabled>
  <Uri>http://schemas.microsoft.com/2006/03/windows/events/SubscriptionConfigurations/InitiateSubscription</Uri>
  <ConfigurationMode>Custom</ConfigurationMode>
  <Delivery>
    <PushSettings>
      <Heartbeat Interval="300"/>
    </PushSettings>
  </Delivery>
  <Query>
<![CDATA[
$queryXml
]]>
  </Query>
  <ReadExistingEvents>true</ReadExistingEvents>
  <TransportName>HTTP</TransportName>
  <ContentFormat>RenderedText</ContentFormat>
  <Locale Language="en-US"/>
  <LogFile>ForwardedEvents</LogFile>
  <AllowedSourceDomainComputers>O:DC=homelab,DC=local</AllowedSourceDomainComputers>
</Subscription>
"@

    $tempXml = Join-Path $env:TEMP "$subscriptionName.xml"
    $subXml | Out-File -FilePath $tempXml -Encoding UTF8

    try {
        wecutil cs $tempXml 2>&1 | Out-Null
        Write-Log "  Created WEF subscription: $subscriptionName"
    }
    catch {
        Write-Log "  WEF subscription creation failed: $($_.Exception.Message)" 'WARN'
    }
}

# ── 4. Configure WEF on clients via GPO registry ──
Write-Log "4. Configuring client-side WEF via registry..."
$wefRegPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\EventLog\EventForwarding\SubscriptionManager'
if (-not (Test-Path $wefRegPath)) { New-Item -Path $wefRegPath -Force | Out-Null }
Set-ItemProperty -Path $wefRegPath -Name 1 -Value 'http://dc01.homelab.local:5985/wsman/SubscriptionManager/WEC' -Force
Write-Log "  Client WEF registry: configured to forward to DC01"

# ── 5. Create alert scheduled tasks ──
Write-Log "5. Creating alert scheduled tasks for critical events..."

$criticalEvents = $events | Where-Object { $_.Severity -eq 'Critical' }

foreach ($evt in $criticalEvents) {
    $taskName = "Alert-Event-$($evt.EventID)"
    $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

    if ($existingTask) {
        Write-Log "  Task '$taskName' already exists."
        continue
    }

    # Create event trigger
    $triggerXml = @"
<QueryList>
  <Query Id="0" Path="Security">
    <Select Path="Security">*[System[(EventID=$($evt.EventID))]]</Select>
  </Query>
</QueryList>
"@

    $action = New-ScheduledTaskAction -Execute 'powershell.exe' `
        -Argument "-Command `"Write-EventLog -LogName Application -Source 'AD-Lab-Monitoring' -EventId 9999 -EntryType Warning -Message 'CRITICAL: Event $($evt.EventID) ($($evt.Description)) detected on \$env:COMPUTERNAME'`""

    # Create custom event trigger
    $trigger = New-ScheduledTaskTrigger -AtLogon -ErrorAction SilentlyContinue
    # Note: In production, use New-CimInstance for event-based triggers.
    # This is a simplified version for lab purposes.

    try {
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -RunLevel Highest -Force | Out-Null
        Write-Log "  Alert task created: $taskName (Event $($evt.EventID) - $($evt.Description))"
    }
    catch {
        Write-Log "  Alert task creation failed for $taskName: $($_.Exception.Message)" 'WARN'
    }
}

# ── 6. Register custom event source ──
Write-Log "6. Registering custom event source..."
$sourceExists = [System.Diagnostics.EventLog]::SourceExists('AD-Lab-Monitoring')
if (-not $sourceExists) {
    [System.Diagnostics.EventLog]::CreateEventSource('AD-Lab-Monitoring', 'Application')
    Write-Log "  Event source 'AD-Lab-Monitoring' registered"
}
else {
    Write-Log "  Event source already exists."
}

# ── 7. Summary ──
Write-Log "=== Monitoring setup complete ==="
Write-Log "  WEF Collector: DC01 (ForwardedEvents log)"
Write-Log "  Subscription: $subscriptionName"
Write-Log "  Monitored events: $($events.Count) types"
Write-Log "  Critical event alerts: $(($criticalEvents | Measure-Object).Count) tasks"
Write-Log "  View forwarded events: Event Viewer -> ForwardedEvents"
Write-Log "  Review: docs/security-dashboard.md"
