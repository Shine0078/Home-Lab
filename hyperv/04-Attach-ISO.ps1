<#
.SYNOPSIS
    Attaches ISOs and unattend files to all lab VMs and starts automated OS installation.

.DESCRIPTION
    For each VM (DC01, WIN11-CLIENT01, WIN11-CLIENT02), this script:
      1. Creates a FAT-formatted VFD (virtual floppy) containing autounattend.xml
      2. Attaches the VFD and the appropriate OS ISO to the VM
      3. Sets the VM boot order to boot from DVD first
      4. Starts the VM
    This eliminates the manual OOBE step. After OS installation completes
    and WinRM is reachable, run scripts/01-Setup-DC.ps1 etc.

.PARAMETER ServerISO
    Path to the Windows Server 2022 ISO file.

.PARAMETER Win11ISO
    Path to the Windows 11 Pro ISO file.

.PARAMETER VMName
    Specific VM to provision. If omitted, provisions all three.

.NOTES
    Run as Administrator on the Hyper-V host.
    Part of AD-HomeLab Phase 1 (Automated ISO Provisioning).
#>

#Requires -RunAsAdministrator
#Requires -Modules Hyper-V

param(
    [Parameter(Mandatory = $true)]
    [string]$ServerISO,

    [Parameter(Mandatory = $true)]
    [string]$Win11ISO,

    [ValidateSet('DC01', 'WIN11-CLIENT01', 'WIN11-CLIENT02')]
    [string]$VMName
)

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

function New-UnattendVFD {
    <#
    Creates a VHD (used as a virtual floppy) containing autounattend.xml.
    Hyper-V Gen2 VMs don't support floppy drives, so we use a small VHD
    mounted as a drive letter, copy the file, then attach it as a DVD
    alternative. An alternative approach is to inject into the ISO.
    #>
    param(
        [string]$UnattendPath,
        [string]$OutputPath
    )

    # Create a 4MB VHD
    $vhdPath = Join-Path $OutputPath 'autounattend.vhd'
    New-VHD -Path $vhdPath -SizeBytes 4MB -Dynamic -ErrorAction SilentlyContinue | Out-Null

    # Mount, format as FAT32, copy file, dismount
    $mount = Mount-VHD -Path $vhdPath -PassThru
    $disk = $mount | Get-Disk
    $partition = $disk | Initialize-Disk -PartitionStyle GPT -PassThru | New-Partition -UseMaximumSize -AssignDriveLetter
    Format-Volume -DriveLetter $partition.DriveLetter -FileSystem FAT32 -NewFileSystemLabel 'UNATTEND' -Force | Out-Null

    $destPath = "$($partition.DriveLetter):\autounattend.xml"
    Copy-Item -Path $UnattendPath -Destination $destPath -Force

    Dismount-VHD -Path $vhdPath
    return $vhdPath
}

function Set-VMISOAttachment {
    param(
        [string]$Name,
        [string]$ISOPath,
        [string]$UnattendFile
    )

    $vm = Get-VM -Name $Name -ErrorAction SilentlyContinue
    if (-not $vm) {
        Write-Log "VM '$Name' not found. Skipping."
        return
    }

    # Verify ISO exists
    if (-not (Test-Path $ISOPath)) {
        Write-Log "ERROR: ISO not found at $ISOPath"
        return
    }

    # Create unattend VHD
    $unattendDir = Join-Path $PSScriptRoot 'unattend'
    $vhdPath = New-UnattendVFD -UnattendPath $UnattendFile -OutputPath $unattendDir

    # Remove existing DVD drives
    $dvdDrives = Get-VMDvdDrive -VMName $Name -ErrorAction SilentlyContinue
    if ($dvdDrives) {
        $dvdDrives | Remove-VMDvdDrive -ErrorAction SilentlyContinue
    }

    # Attach ISO as DVD
    Add-VMDvdDrive -VMName $Name -Path $ISOPath
    Write-Log "Attached ISO to ${Name}: $ISOPath"

    # Attach unattend VHD
    Add-VMHardDiskDrive -VMName $Name -Path $vhdPath -ControllerType SCSI -ErrorAction SilentlyContinue
    Write-Log "Attached unattend VHD to ${Name}"

    # Set boot order: DVD first
    $dvdDrive = Get-VMDvdDrive -VMName $Name | Select-Object -First 1
    if ($dvdDrive) {
        Set-VMFirmware -VMName $Name -FirstBootDevice $dvdDrive
        Write-Log "Set boot order: DVD first for ${Name}"
    }

    # Start VM
    if ($vm.State -ne 'Running') {
        Start-VM -VMName $Name
        Write-Log "Started VM: ${Name}"
    }
    else {
        Write-Log "VM ${Name} already running."
    }
}

# ── Validate ISOs ──
if (-not (Test-Path $ServerISO)) { throw "Server ISO not found: $ServerISO" }
if (-not (Test-Path $Win11ISO))  { throw "Win11 ISO not found: $Win11ISO" }

Write-Log "=== ISO Attachment ==="
Write-Log "Server ISO: $ServerISO"
Write-Log "Win11 ISO: $Win11ISO"

$vmConfigs = @(
    @{ Name = 'DC01';           ISO = $ServerISO; Unattend = 'unattend_Server2022.xml' }
    @{ Name = 'WIN11-CLIENT01'; ISO = $Win11ISO;  Unattend = 'unattend_Win11.xml' }
    @{ Name = 'WIN11-CLIENT02'; ISO = $Win11ISO;  Unattend = 'unattend_Win11.xml' }
)

foreach ($config in $vmConfigs) {
    if ($VMName -and $config.Name -ne $VMName) { continue }
    $unattendPath = Join-Path $PSScriptRoot "unattend\$($config.Unattend)"
    Set-VMISOAttachment -Name $config.Name -ISOPath $config.ISO -UnattendFile $unattendPath
}

Write-Log "=== ISO attachment complete ==="
Write-Log "OS installation will proceed automatically. Wait 10-15 min per VM."
Write-Log "Verify WinRM: Test-WSMan -ComputerName <VM-IP>"
