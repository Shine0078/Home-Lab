<#
.SYNOPSIS
    Creates 50 AD user accounts from a CSV file.

.DESCRIPTION
    Reads data/users.csv and creates user accounts in Active Directory.
    Users are placed in OU=Staff by default; IT department users go to
    OU=IT. Generates random 16-char passwords and outputs credentials
    to output/user-credentials.csv. Idempotent — skips existing users.

.NOTES
    Run as Administrator on DC01.
    Part of AD-HomeLab Phase 5.
#>

#Requires -RunAsAdministrator
#Requires -Modules ActiveDirectory

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$DomainName = 'homelab.local'
$DomainDN   = "DC=homelab,DC=local"
$CSVPath    = Join-Path $PSScriptRoot '..\data\users.csv'
$OutputDir  = Join-Path $PSScriptRoot '..\output'
$OutputCSV  = Join-Path $OutputDir 'user-credentials.csv'
$LogDir     = Join-Path $PSScriptRoot '..\logs'
$LogFile    = Join-Path $LogDir 'create-users.log'

if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null }
if (-not (Test-Path $LogDir))    { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $entry = "[$timestamp] $Message"
    Add-Content -Path $LogFile -Value $entry
    Write-Host $entry -ForegroundColor Cyan
}

function New-RandomPassword {
    param([int]$Length = 16)
    $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*'
    $password = -join ((0..($Length-1)) | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
    return $password
}

# ── Read CSV ──
if (-not (Test-Path $CSVPath)) {
    Write-Log "ERROR: CSV not found at $CSVPath. Run data/Generate-Users.ps1 first."
    throw "Users CSV not found."
}

$users = Import-Csv -Path $CSVPath
Write-Log "Loaded $($users.Count) users from $CSVPath"

# ── Create Users ──
$credentials = @()
$created = 0
$skipped = 0

foreach ($user in $users) {
    $samAccount = "$($user.FirstName.ToLower()).$($user.LastName.ToLower())"
    $upn        = "$samAccount@$DomainName"
    $displayName = "$($user.FirstName) $($user.LastName)"

    # Check if user already exists
    $existing = Get-ADUser -Filter "SamAccountName -eq '$samAccount'" -ErrorAction SilentlyContinue
    if ($existing) {
        $skipped++
        continue
    }

    # Determine OU
    $ouPath = if ($user.Department -eq 'IT') {
        "OU=IT,$DomainDN"
    } else {
        "OU=Staff,$DomainDN"
    }

    $password = New-RandomPassword -Length 16
    $securePassword = ConvertTo-SecureString $password -AsPlainText -Force

    try {
        New-ADUser `
            -SamAccountName $samAccount `
            -UserPrincipalName $upn `
            -Name $displayName `
            -GivenName $user.FirstName `
            -Surname $user.LastName `
            -DisplayName $displayName `
            -Title $user.Title `
            -Department $user.Department `
            -Path $ouPath `
            -AccountPassword $securePassword `
            -ChangePasswordAtLogon $true `
            -Enabled $true `
            -PasswordNeverExpires $false `
            -ErrorAction Stop

        $credentials += [PSCustomObject]@{
            Username = $samAccount
            Password = $password
            UPN      = $upn
            FullName = $displayName
            Department = $user.Department
            Title    = $user.Title
        }

        $created++
        Write-Log "Created: $samAccount ($displayName) -> $ouPath"
    }
    catch {
        Write-Log "ERROR creating ${samAccount}: $($_.Exception.Message)"
    }
}

# ── Output Credentials ──
$credentials | Export-Csv -Path $OutputCSV -NoTypeInformation
Write-Log "Credentials exported to $OutputCSV"

Write-Log "=== User creation complete ==="
Write-Log "Created: $created | Skipped (existing): $skipped | Total in CSV: $($users.Count)"
