<#
.SYNOPSIS
    Provisions the DC01 Domain Controller VM in Hyper-V.

.DESCRIPTION
    Creates a Generation 2 VM named DC01 with 4GB RAM, 2 vCPU, and a
    60GB dynamic VHDX. Attaches to AD-Lab-Switch. The VM is created
    without an OS -- you must manually attach the Server 2022 ISO and
    complete OS installation via OOBE.

.NOTES
    Run as Administrator on the Hyper-V host.
    Part of AD-HomeLab Phase 1.
#>

#Requires -RunAsAdministrator
#Requires -Modules Hyper-V

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$VMName     = 'DC01'
$SwitchName = 'AD-Lab-Switch'
$RAM        = 4GB
$CPU        = 2
$VHDXSize   = 60GB
$LogDir     = Join-Path $PSScriptRoot '..\logs'
$LogFile    = Join-Path $LogDir 'hyperv-setup.log'

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $entry = "[$timestamp] $Message"
    Add-Content -Path $LogFile -Value $entry
    Write-Output $entry -ForegroundColor Cyan
}

try {
    $existing = Get-VM -Name $VMName -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Log "VM '$VMName' already exists (State: $($existing.State)). Skipping."
        return
    }

    $vmHost = Get-VMHost
    $VHDPath = Join-Path $vmHost.DefaultVirtualHardDiskPath "$VMName.vhdx"

    New-VM -Name $VMName `
        -Generation 2 `
        -MemoryStartupBytes $RAM `
        -SwitchName $SwitchName `
        -NewVHDPath $VHDPath `
        -NewVHDSizeBytes $VHDXSize `
        | Out-Null

    Set-VM -Name $VMName `
        -ProcessorCount $CPU `
        -DynamicMemory `
        -MemoryStartupBytes $RAM `
        -MemoryMinimumBytes 512MB `
        -MemoryMaximumBytes 8GB `
        -AutomaticCheckpointsEnabled $false

    Enable-VMIntegrationService -VMName $VMName -Name 'Guest Service Interface'

    Write-Log "Created VM '$VMName': 4GB RAM, 2 vCPU, 60GB VHDX (dynamic)"
    Write-Log "VHDX: $VHDPath"
    Write-Log "Next step: Attach Windows Server 2022 ISO and install OS."
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    throw
}
