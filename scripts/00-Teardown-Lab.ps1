<#
.SYNOPSIS
    Removes the lab-specific AD objects, GPOs, and monitoring artifacts.

.DESCRIPTION
    Safe teardown for the lab portion of AD-HomeLab. Removes:
      - Lab-created users from data/users.csv
      - Lab-specific security groups and the OU=Groups container
      - Lab-specific GPOs
      - Monitoring alert scheduled tasks and custom event source

    This script does not remove the AD forest, DHCP role, or Hyper-V VMs.
    Run with -WhatIf first if you want to preview the changes.

.NOTES
    Run as Administrator on DC01.
#>

#Requires -RunAsAdministrator
#Requires -Modules ActiveDirectory, GroupPolicy

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [switch]$SkipUsers,
    [switch]$SkipGroups,
    [switch]$SkipGPOs,
    [switch]$SkipMonitoring
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path $PSScriptRoot -Parent
$LogDir   = Join-Path $RepoRoot 'logs'
$LogFile  = Join-Path $LogDir 'teardown-lab.log'
$UsersCsv = Join-Path $RepoRoot 'data\users.csv'

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $entry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $entry
    Write-Output $entry
}

$labUsers = @()
if (Test-Path $UsersCsv) {
    $labUsers = Import-Csv -Path $UsersCsv | ForEach-Object {
        "$($_.FirstName.ToLower()).$($_.LastName.ToLower())"
    }
}

$labGroups = @(
    'GG-IT-Admins',
    'GG-Sales-Users',
    'GG-Finance-Users',
    'GG-Ops-Users',
    'GG-HR-Users',
    'GG-Helpdesk-Operators',
    'DL-Workstations-Admins'
)

$labGpos = @(
    'Restrict-USB-Storage',
    'Block-AppData-Executables',
    'Screen-Lock-Timeout',
    'Legal-Warning-Banner',
    'Local-Account-Hardening',
    'Windows-Firewall-Hardening',
    'Disable-Unnecessary-Services'
)

Write-Log '=== AD-HomeLab Teardown ==='

if (-not $SkipMonitoring) {
    Write-Log 'Removing monitoring tasks and event source...'
    foreach ($task in (Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -like 'Alert-Event-*' -or $_.TaskName -like 'AD-HomeLab-Resume-*' })) {
        if ($PSCmdlet.ShouldProcess($task.TaskName, 'Remove scheduled task')) {
            Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false -ErrorAction SilentlyContinue
        }
    }

    if ([System.Diagnostics.EventLog]::SourceExists('AD-Lab-Monitoring')) {
        Write-Log 'Custom event source remains registered; manual removal requires registry cleanup and is intentionally skipped.' 'WARN'
    }
}

if (-not $SkipGPOs) {
    Write-Log 'Removing lab GPOs...'
    foreach ($gpoName in $labGpos) {
        $gpo = Get-GPO -Name $gpoName -ErrorAction SilentlyContinue
        if ($gpo -and $PSCmdlet.ShouldProcess($gpoName, 'Remove GPO')) {
            Remove-GPO -Name $gpoName -Confirm:$false -ErrorAction SilentlyContinue
        }
    }
}

if (-not $SkipGroups) {
    Write-Log 'Removing lab groups and OU=Groups...'
    foreach ($groupName in $labGroups) {
        $group = Get-ADGroup -Identity $groupName -ErrorAction SilentlyContinue
        if ($group -and $PSCmdlet.ShouldProcess($groupName, 'Remove AD group')) {
            Remove-ADGroup -Identity $groupName -Confirm:$false -ErrorAction SilentlyContinue
        }
    }

    $groupsOU = Get-ADOrganizationalUnit -Filter "Name -eq 'Groups'" -ErrorAction SilentlyContinue
    if ($groupsOU -and $PSCmdlet.ShouldProcess($groupsOU.DistinguishedName, 'Remove OU=Groups')) {
        Remove-ADOrganizationalUnit -Identity $groupsOU.DistinguishedName -Recursive -Confirm:$false -ErrorAction SilentlyContinue
    }
}

if (-not $SkipUsers) {
    Write-Log 'Removing lab users from Staff and IT OUs...'
    foreach ($sam in $labUsers) {
        $user = Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue
        if ($user -and $PSCmdlet.ShouldProcess($sam, 'Remove AD user')) {
            Remove-ADUser -Identity $user.DistinguishedName -Confirm:$false -ErrorAction SilentlyContinue
        }
    }
}

Write-Log '=== Teardown complete ==='
