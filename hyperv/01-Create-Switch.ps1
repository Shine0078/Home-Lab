<#
.SYNOPSIS
    Creates the AD-Lab-Switch internal virtual switch for the homelab.

.DESCRIPTION
    Provisions an internal virtual switch named AD-Lab-Switch used by all
    lab VMs (DC01, WIN11-CLIENT01, WIN11-CLIENT02). Idempotent - skips
    creation if the switch already exists.

.NOTES
    Run as Administrator on the Hyper-V host.
    Part of AD-HomeLab Phase 1.
#>

#Requires -RunAsAdministrator
#Requires -Modules Hyper-V

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$SwitchName = 'AD-Lab-Switch'
$LogDir = Join-Path $PSScriptRoot '..\logs'
$LogFile = Join-Path $LogDir 'hyperv-setup.log'

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $entry = "[$timestamp] $Message"
    Add-Content -Path $LogFile -Value $entry
    Write-Host $entry -ForegroundColor Cyan
}

try {
    $existing = Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Log "Virtual switch '$SwitchName' already exists (Type: $($existing.SwitchType)). Skipping."
    }
    else {
        New-VMSwitch -Name $SwitchName -SwitchType Internal | Out-Null
        Write-Log "Created internal virtual switch '$SwitchName'."
    }

    Write-Log "Switch setup complete."
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    throw
}
