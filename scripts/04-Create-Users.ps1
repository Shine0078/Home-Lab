<#
.SYNOPSIS
    Creates 50 AD user accounts from a CSV file.

.DESCRIPTION
    Reads data/users.csv and creates user accounts in Active Directory.
    Users are placed in OU=Staff by default; IT department users go to
    OU=IT. Generates random 16-char passwords that meet complexity
    requirements (upper, lower, digit, special) and outputs credentials
    to output/user-credentials.csv. Idempotent -- skips existing users.

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
    Write-Output $entry -ForegroundColor Cyan
}

function Get-RandomPassword {
    <#
    Generates a random password that meets Windows complexity requirements:
    - At least one uppercase letter
    - At least one lowercase letter
    - At least one digit
    - At least one special character
    - Minimum 16 characters total
    #>
    param([int]$Length = 16)

    $upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ'
    $lower = 'abcdefghijkmnopqrstuvwxyz'
    $digits = '23456789'
    $special = '!@#$%^&*()'

    # Start with one character from each required set
    $password = @(
        $upper[(Get-Random -Maximum $upper.Length)]
        $lower[(Get-Random -Maximum $lower.Length)]
        $digits[(Get-Random -Maximum $digits.Length)]
        $special[(Get-Random -Maximum $special.Length)]
    )

    # Fill the rest with a mix of all character classes
    $allChars = $upper + $lower + $digits + $special
    for ($i = 4; $i -lt $Length; $i++) {
        $password += $allChars[(Get-Random -Maximum $allChars.Length)]
    }

    # Shuffle the password so the guaranteed chars aren't always first
    $shuffled = $password | Get-Random -Count $password.Length
    return -join $shuffled
}

function ConvertTo-SecurePassword {
    param([Parameter(Mandatory = $true)][string]$Text)

    $secure = New-Object System.Security.SecureString
    foreach ($char in $Text.ToCharArray()) {
        $secure.AppendChar($char)
    }
    $secure.MakeReadOnly()
    return $secure
}

# â”€â”€ Read CSV â”€â”€
if (-not (Test-Path $CSVPath)) {
    Write-Log "ERROR: CSV not found at $CSVPath. Run data/Generate-Users.ps1 first."
    throw "Users CSV not found at $CSVPath"
}

$users = Import-Csv -Path $CSVPath
Write-Log "Loaded $($users.Count) users from $CSVPath"

# â”€â”€ Create Users â”€â”€
$credentials = [System.Collections.ArrayList]::new()
$created = 0
$skipped = 0
$failed = 0

foreach ($user in $users) {
    $samAccount = "$($user.FirstName.ToLower()).$($user.LastName.ToLower())"
    # Sanitize SamAccountName (remove any invalid characters, truncate to 20)
    $samAccount = $samAccount -replace '[^a-zA-Z0-9._-]', ''
    if ($samAccount.Length -gt 20) { $samAccount = $samAccount.Substring(0, 20) }
    $upn        = "$samAccount@$DomainName"
    $displayName = "$($user.FirstName) $($user.LastName)"

    # Check if user already exists
    $existing = Get-ADUser -Filter "SamAccountName -eq '$samAccount'" -ErrorAction SilentlyContinue
    if ($existing) {
        $skipped++
        Write-Log "Skipped (exists): $samAccount"
        continue
    }

    # Determine OU
    $ouPath = if ($user.Department -eq 'IT') {
        "OU=IT,$DomainDN"
    } else {
        "OU=Staff,$DomainDN"
    }

    $password = Get-RandomPassword -Length 16
    $securePassword = ConvertTo-SecurePassword -Text $password

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

        [void]$credentials.Add([PSCustomObject]@{
            Username   = $samAccount
            Password   = $password
            UPN        = $upn
            FullName   = $displayName
            Department = $user.Department
            Title      = $user.Title
        })

        $created++
        Write-Log "Created: $samAccount ($displayName) -> $ouPath"
    }
    catch {
        $failed++
        Write-Log "ERROR creating ${samAccount}: $($_.Exception.Message)"
    }
}

# â”€â”€ Output Credentials â”€â”€
if ($credentials.Count -gt 0) {
    $credentials | Export-Csv -Path $OutputCSV -NoTypeInformation -Force
    Write-Log "Credentials exported to $OutputCSV ($($credentials.Count) records)"
} else {
    Write-Log "No new users created. Credentials file not updated."
}

Write-Log "=== User creation complete ==="
Write-Log "Created: $created | Skipped (existing): $skipped | Failed: $failed | Total in CSV: $($users.Count)"
