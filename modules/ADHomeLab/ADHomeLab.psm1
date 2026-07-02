<#
.SYNOPSIS
    AD-HomeLab PowerShell module with shared utility functions.

.DESCRIPTION
    Provides reusable functions used across all AD-HomeLab scripts:
      - Write-Log: timestamped logging to file and console
      - New-RandomPassword: complexity-guaranteed password generation
      - Test-ADReady: check if AD is available
      - Install-FeatureIfMissing: idempotent Windows feature install
      - Get-ActiveAdapter: get the first active physical network adapter
      - New-OrGetGPO: create GPO if missing, return existing if present
      - Set-GPOLinkIfMissing: link GPO to OU if not already linked

.NOTES
    Version: 1.0.0
    Author: AD-HomeLab
#>

Set-StrictMode -Version Latest

function Write-Log {
    <#
    .SYNOPSIS
        Writes a timestamped message to a log file and console.
    .DESCRIPTION
        Formats messages as [timestamp] [level] message and appends to
        the specified log file. Also outputs to console with color coding.
    .PARAMETER Message
        The message to log.
    .PARAMETER LogFile
        Path to the log file.
    .PARAMETER Level
        Severity level: INFO, WARN, ERROR, PASS, FAIL. Default: INFO.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $true)]
        [string]$LogFile,

        [string]$Level = 'INFO'
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $entry = "[$timestamp] [$Level] $Message"
    if (Test-Path (Split-Path $LogFile -Parent)) {
        Add-Content -Path $LogFile -Value $entry
    }
    switch ($Level) {
        'PASS'  { Write-Host "  [PASS] $Message" -ForegroundColor Green }
        'FAIL'  { Write-Host "  [FAIL] $Message" -ForegroundColor Red }
        'WARN'  { Write-Host "  [WARN] $Message" -ForegroundColor Yellow }
        'ERROR' { Write-Host "  [ERROR] $Message" -ForegroundColor Red }
        default { Write-Host "  $Message" -ForegroundColor Cyan }
    }
}

function New-RandomPassword {
    <#
    .SYNOPSIS
        Generates a random password meeting Windows complexity requirements.
    .DESCRIPTION
        Guarantees at least one uppercase, lowercase, digit, and special
        character. Excludes ambiguous characters (0, O, l, 1, I).
    .PARAMETER Length
        Desired password length. Default: 16. Minimum: 4.
    #>
    param([int]$Length = 16)

    if ($Length -lt 4) { $Length = 4 }

    $upper   = 'ABCDEFGHJKLMNPQRSTUVWXYZ'
    $lower   = 'abcdefghijkmnopqrstuvwxyz'
    $digits  = '23456789'
    $special = '!@#$%^&*()'

    $password = @(
        $upper[(Get-Random -Maximum $upper.Length)]
        $lower[(Get-Random -Maximum $lower.Length)]
        $digits[(Get-Random -Maximum $digits.Length)]
        $special[(Get-Random -Maximum $special.Length)]
    )

    $allChars = $upper + $lower + $digits + $special
    for ($i = 4; $i -lt $Length; $i++) {
        $password += $allChars[(Get-Random -Maximum $allChars.Length)]
    }

    $shuffled = $password | Get-Random -Count $password.Length
    return -join $shuffled
}

function Test-ADReady {
    <#
    .SYNOPSIS
        Checks if Active Directory is available on this machine.
    .DESCRIPTION
        Returns true if Get-ADDomain succeeds, false otherwise.
        Used to determine if the DC has been promoted.
    #>
    try {
        $null = Get-ADDomain -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

function Install-FeatureIfMissing {
    <#
    .SYNOPSIS
        Installs a Windows Server feature if not already installed.
    .DESCRIPTION
        Idempotent wrapper around Get-WindowsFeature and Install-WindowsFeature.
        Handles cases where Get-WindowsFeature returns null (non-Server editions).
    .PARAMETER FeatureName
        The name of the Windows feature to install.
    .PARAMETER LogFile
        Path to log file for status messages.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$FeatureName,

        [string]$LogFile
    )
    $feature = Get-WindowsFeature -Name $FeatureName -ErrorAction SilentlyContinue
    if (-not $feature) {
        if ($LogFile) { Write-Log -Message "Feature '$FeatureName' not found on this edition. Skipping." -LogFile $LogFile -Level 'WARN' }
        return
    }
    if (-not $feature.Installed) {
        Install-WindowsFeature -Name $FeatureName -IncludeManagementTools | Out-Null
        if ($LogFile) { Write-Log -Message "$FeatureName installed." -LogFile $LogFile }
    }
    else {
        if ($LogFile) { Write-Log -Message "$FeatureName already installed." -LogFile $LogFile }
    }
}

function Get-ActiveAdapter {
    <#
    .SYNOPSIS
        Gets the first active physical network adapter.
    .DESCRIPTION
        Returns the first NetAdapter with Status=Up. Throws if none found.
    #>
    $adapter = Get-NetAdapter -Physical | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
    if (-not $adapter) {
        throw "No active network adapter found."
    }
    return $adapter
}

function New-OrGetGPO {
    <#
    .SYNOPSIS
        Creates a GPO if it does not exist, returns existing if it does.
    .PARAMETER Name
        GPO display name.
    .PARAMETER Comment
        GPO comment (only used on creation).
    .PARAMETER LogFile
        Path to log file.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [string]$Comment,

        [string]$LogFile
    )
    $existing = Get-GPO -Name $Name -ErrorAction SilentlyContinue
    if (-not $existing) {
        $gpo = New-GPO -Name $Name -Comment $Comment
        if ($LogFile) { Write-Log -Message "Created GPO: $Name (ID: $($gpo.Id))" -LogFile $LogFile }
        return $gpo
    }
    if ($LogFile) { Write-Log -Message "GPO '$Name' already exists. Updating..." -LogFile $LogFile }
    return $existing
}

function Set-GPOLinkIfMissing {
    <#
    .SYNOPSIS
        Links a GPO to an OU if not already linked.
    .PARAMETER GPOName
        Display name of the GPO to link.
    .PARAMETER TargetOU
        Distinguished name of the target OU.
    .PARAMETER LogFile
        Path to log file.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$GPOName,

        [Parameter(Mandatory = $true)]
        [string]$TargetOU,

        [string]$LogFile
    )
    $inheritance = Get-GPInheritance -Target $TargetOU -ErrorAction SilentlyContinue
    $isLinked = $false
    if ($inheritance -and $inheritance.GpoLinks) {
        foreach ($link in $inheritance.GpoLinks) {
            if ($link.DisplayName -eq $GPOName) { $isLinked = $true; break }
        }
    }
    if (-not $isLinked) {
        $gpo = Get-GPO -Name $GPOName
        New-GPLink -Guid $gpo.Id -Target $TargetOU -LinkEnabled Yes | Out-Null
        if ($LogFile) { Write-Log -Message "Linked '$GPOName' to $TargetOU" -LogFile $LogFile }
    }
    else {
        if ($LogFile) { Write-Log -Message "GPO already linked to $TargetOU" -LogFile $LogFile }
    }
}

Export-ModuleMember -Function Write-Log, New-RandomPassword, Test-ADReady, Install-FeatureIfMissing, Get-ActiveAdapter, New-OrGetGPO, Set-GPOLinkIfMissing
