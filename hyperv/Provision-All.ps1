<#
.SYNOPSIS
    Provisions all lab VMs and the virtual switch in one pass.

.DESCRIPTION
    Runs the full Phase 1 Hyper-V setup: creates AD-Lab-Switch, DC01,
    WIN11-CLIENT01, and WIN11-CLIENT02. Each sub-step is idempotent.
    VMs are created without an OS — manual ISO installation required.

.NOTES
    Run as Administrator on the Hyper-V host.
    Part of AD-HomeLab Phase 1.
#>

#Requires -RunAsAdministrator
#Requires -Modules Hyper-V

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$LogDir  = Join-Path $PSScriptRoot '..\logs'
$LogFile = Join-Path $LogDir 'hyperv-setup.log'

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $entry = "[$timestamp] $Message"
    Add-Content -Path $LogFile -Value $entry
    Write-Host $entry -ForegroundColor Cyan
}

Write-Log "=== AD-HomeLab Hyper-V Setup ==="

Write-Log "--- Step 1: Virtual Switch ---"
& "$PSScriptRoot\01-Create-Switch.ps1"

Write-Log "--- Step 2: DC01 ---"
& "$PSScriptRoot\02-Provision-DC01.ps1"

Write-Log "--- Step 3: Client VMs ---"
& "$PSScriptRoot\03-Provision-Clients.ps1"

Write-Log "=== All VMs provisioned ==="
Write-Log "MANUAL STEP: Mount Windows Server 2022 ISO on DC01, Windows 11 ISO on both clients."
Write-Log "MANUAL STEP: Complete OS installation and OOBE on all three VMs."
Write-Log "Resume automation once WinRM/PSRemoting is reachable on all VMs."
