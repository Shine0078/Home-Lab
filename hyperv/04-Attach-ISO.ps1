<#
.SYNOPSIS
    Attaches ISOs and unattend staging media to all lab VMs.

.DESCRIPTION
    For each VM (DC01, WIN11-CLIENT01, WIN11-CLIENT02), this script:
      1. Stages autounattend.xml on a temporary FAT-formatted VHDX
      2. Attaches the appropriate OS ISO to the VM
      3. Sets the VM boot order to boot from DVD first
      4. Starts the VM
    The initial OOBE / setup screens still require human completion unless
    you rebuild the media with an external ISO authoring tool.

.PARAMETER ServerISO
    Path to the Windows Server 2022 ISO file.

.PARAMETER Win11ISO
    Path to the Windows 11 Pro ISO file.

.PARAMETER VMName
    Specific VM to provision. If omitted, provisions all three.

.PARAMETER AdminPassword
    Local Administrator password to inject into generated unattend media.
    If omitted, the script prompts securely. Windows Setup requires the
    password inside the temporary unattend VHDX, but no password is stored
    in the repository.

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
    [string]$VMName,

    [securestring]$AdminPassword
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
    [CmdletBinding(SupportsShouldProcess = $true)]
    <#
    Creates a VHD (used as a virtual floppy) containing autounattend.xml.
    Hyper-V Gen2 VMs don't support floppy drives, so we use a small VHD
    mounted as a drive letter, copy the file, then attach it as a DVD
    alternative. An alternative approach is to inject into the ISO.
    #>
    param(
        [string]$UnattendPath,
        [string]$OutputPath,
        [string]$Name,
        [string]$AdminPasswordPlain
    )

    if ($PSCmdlet.ShouldProcess($OutputPath, 'Create unattend staging volume')) {
        # Create a 4MB VHD
        $safeName = $Name -replace '[^a-zA-Z0-9_-]', '_'
        $vhdPath = Join-Path $OutputPath "$safeName-autounattend.vhdx"
        if (Test-Path $vhdPath) {
            Remove-Item -Path $vhdPath -Force -ErrorAction SilentlyContinue
        }
        New-VHD -Path $vhdPath -SizeBytes 4MB -Dynamic -ErrorAction SilentlyContinue | Out-Null

        # Mount, format as FAT32, copy file, dismount
        $mount = Mount-VHD -Path $vhdPath -PassThru
        $disk = $mount | Get-Disk
        $partition = $disk | Initialize-Disk -PartitionStyle GPT -PassThru | New-Partition -UseMaximumSize -AssignDriveLetter
        Format-Volume -DriveLetter $partition.DriveLetter -FileSystem FAT32 -NewFileSystemLabel 'UNATTEND' -Force | Out-Null

        $unattendContent = Get-Content -Path $UnattendPath -Raw
        if ($unattendContent -notmatch '__ADMIN_PASSWORD__') {
            throw "Unattend template does not contain __ADMIN_PASSWORD__ token: $UnattendPath"
        }

        $destPath = "$($partition.DriveLetter):\autounattend.xml"
        $unattendContent.Replace('__ADMIN_PASSWORD__', $AdminPasswordPlain) |
            Set-Content -Path $destPath -Encoding UTF8 -Force

        Dismount-VHD -Path $vhdPath
        return $vhdPath
    }
}

function Set-VMISOAttachment {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]$Name,
        [string]$ISOPath,
        [string]$UnattendFile,
        [string]$AdminPasswordPlain
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
    $vhdPath = New-UnattendVFD -UnattendPath $UnattendFile -OutputPath $unattendDir -Name $Name -AdminPasswordPlain $AdminPasswordPlain

    if ($PSCmdlet.ShouldProcess($Name, 'Attach installation media and start VM')) {
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
}

# â”€â”€ Validate ISOs â”€â”€
if (-not (Test-Path $ServerISO)) { throw "Server ISO not found: $ServerISO" }
if (-not (Test-Path $Win11ISO))  { throw "Win11 ISO not found: $Win11ISO" }

if (-not $AdminPassword) {
    $AdminPassword = Read-Host -Prompt 'Enter local Administrator password for generated unattend media' -AsSecureString
}

$adminPasswordBstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($AdminPassword)
try {
    $adminPasswordPlain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($adminPasswordBstr)
}
finally {
    if ($adminPasswordBstr -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($adminPasswordBstr)
    }
}

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
    Set-VMISOAttachment -Name $config.Name -ISOPath $config.ISO -UnattendFile $unattendPath -AdminPasswordPlain $adminPasswordPlain
}

Write-Log "=== ISO attachment complete ==="
Write-Log "OS installation still requires manual completion at the OOBE stage."
Write-Log "Verify WinRM: Test-WSMan -ComputerName <VM-IP>"
