<#
.SYNOPSIS
    Applies the DSC configuration to DC01.

.DESCRIPTION
    Compiles the LabDscConfiguration into MOF files and applies them
    via Start-DscConfiguration. Prompts for the DSRM password, generates
    the MOF, and runs the configuration in wait mode with verbose output.

.NOTES
    Run ON DC01 as Administrator.
    Part of AD-HomeLab Phase 7 (DSC).
#>

#Requires -RunAsAdministrator

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$LogDir  = Join-Path $PSScriptRoot '..\logs'
$LogFile = Join-Path $LogDir 'dsc-apply.log'

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $entry = "[$timestamp] $Message"
    Add-Content -Path $LogFile -Value $entry
    Write-Host $entry -ForegroundColor Cyan
}

# Import required DSC resources
Write-Log "Checking DSC resource modules..."
$requiredModules = @('xActiveDirectory', 'xDhcpServer', 'xNetworking', 'xComputerManagement')
foreach ($mod in $requiredModules) {
    $installed = Get-Module -ListAvailable -Name $mod -ErrorAction SilentlyContinue
    if (-not $installed) {
        Write-Log "Installing DSC resource: $mod"
        Install-Module -Name $mod -Force -Scope AllUsers -SkipPublisherCheck
    }
    else {
        Write-Log "DSC resource '$mod' already installed."
    }
}

# Prompt for DSRM password
Write-Log "Prompting for DSRM / domain admin credentials..."
$dsrmPassword = Read-Host -Prompt "Enter DSRM password" -AsSecureString
$credential = New-Object System.Management.Automation.PSCredential('Administrator', $dsrmPassword)

# Dot-source the configuration
. "$PSScriptRoot\LabDscConfiguration.ps1"

# Generate MOF
$MofPath = Join-Path $PSScriptRoot 'MOF'
Write-Log "Compiling DSC configuration -> MOF files at $MofPath"
LabDscConfiguration -NodeName 'localhost' -DomainName 'homelab.local' -DomainAdminPassword $credential -OutputPath $MofPath

# Apply
Write-Log "Applying DSC configuration..."
Start-DscConfiguration -Path $MofPath -Wait -Verbose -Force

Write-Log "=== DSC configuration applied ==="
Write-Log "Verify with: Get-DscConfigurationStatus"
Write-Log "Test drift with: Test-DscConfiguration"
