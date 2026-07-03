<#
.SYNOPSIS
    Provisions the two Windows 11 client VMs in Hyper-V.

.DESCRIPTION
    Creates WIN11-CLIENT01 and WIN11-CLIENT02 as Generation 2 VMs with
    4GB RAM, 2 vCPU, and 40GB dynamic VHDX each. Both attach to AD-Lab-Switch.
    Configures Secure Boot and TPM (required by Windows 11). VMs are created
    without an OS -- manual ISO boot + OOBE required.

.PARAMETER VMName
    Specific VM name to create. If omitted, creates both clients.

.NOTES
    Run as Administrator on the Hyper-V host.
    Part of AD-HomeLab Phase 1.
#>

#Requires -RunAsAdministrator
#Requires -Modules Hyper-V

param(
    [ValidateSet('WIN11-CLIENT01', 'WIN11-CLIENT02')]
    [string]$VMName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$SwitchName = 'AD-Lab-Switch'
$RAM        = 4GB
$CPU        = 2
$VHDXSize   = 40GB
$LogDir     = Join-Path $PSScriptRoot '..\logs'
$LogFile    = Join-Path $LogDir 'hyperv-setup.log'

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $entry = "[$timestamp] $Message"
    Add-Content -Path $LogFile -Value $entry
    Write-Host $entry -ForegroundColor Cyan
}

function New-ClientVM {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([string]$Name)

    $existing = Get-VM -Name $Name -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Log "VM '$Name' already exists (State: $($existing.State)). Skipping."
        return
    }

    $vmHost = Get-VMHost
    $vhdPath = Join-Path $vmHost.DefaultVirtualHardDiskPath "$Name.vhdx"

    if ($PSCmdlet.ShouldProcess($Name, 'Create Hyper-V client VM')) {
        New-VM -Name $Name `
            -Generation 2 `
            -MemoryStartupBytes $RAM `
            -SwitchName $SwitchName `
            -NewVHDPath $vhdPath `
            -NewVHDSizeBytes $VHDXSize `
            | Out-Null

        Set-VM -Name $Name `
            -ProcessorCount $CPU `
            -DynamicMemory `
            -MemoryStartupBytes $RAM `
            -MemoryMinimumBytes 1GB `
            -MemoryMaximumBytes 8GB `
            -AutomaticCheckpointsEnabled $false

        # Windows 11 requires Secure Boot and a vTPM.
        Set-VMFirmware -VMName $Name -EnableSecureBoot On -SecureBootTemplate MicrosoftWindows
        Set-VMKeyProtector -VMName $Name -NewLocalKeyProtector
        Enable-VMTPM -VMName $Name

        # Enable Guest Services for file copy via integration services
        Enable-VMIntegrationService -VMName $Name -Name 'Guest Service Interface'

        Write-Log "Created VM '$Name': 4GB RAM, 2 vCPU, 40GB VHDX (dynamic)"
        Write-Log "  Secure Boot: Enabled (MicrosoftWindows template)"
        Write-Log "  VHDX: $vhdPath"
    }
}

try {
    if ($VMName) {
        New-ClientVM -Name $VMName
    }
    else {
        @('WIN11-CLIENT01', 'WIN11-CLIENT02') | ForEach-Object {
            New-ClientVM -Name $_
        }
    }

    Write-Log "Client provisioning complete. Next step: Attach Windows 11 ISO and install OS on each."
}
catch {
    Write-Log "ERROR: $($_.Exception.Message)"
    throw
}
