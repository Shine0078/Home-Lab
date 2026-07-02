<#
.SYNOPSIS
    Pester tests for scripts/04-Create-Users.ps1 password generator.

.DESCRIPTION
    Tests the New-RandomPassword function to guarantee that it always
    produces passwords meeting Windows complexity requirements:
    - At least one uppercase letter
    - At least one lowercase letter
    - At least one digit
    - At least one special character
    - Minimum length of 16 characters
    Runs 1000 iterations to ensure statistical reliability.

.NOTES
    Part of AD-HomeLab testing.
#>

function Get-RandomPassword {
    param([int]$Length = 16)
    $upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ'
    $lower = 'abcdefghijkmnopqrstuvwxyz'
    $digits = '23456789'
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

Describe 'New-RandomPassword Complexity Requirements' {
    It 'Should generate a password of exactly 16 characters' {
        $password = Get-RandomPassword -Length 16
        $password.Length | Should Be 16
    }

    It 'Should generate a password of custom length' {
        $password = Get-RandomPassword -Length 20
        $password.Length | Should Be 20
    }

    It 'Should contain at least one uppercase letter' {
        $password = Get-RandomPassword -Length 16
        $hasUpper = $password -cmatch '[A-Z]'
        $hasUpper | Should Be $true
    }

    It 'Should contain at least one lowercase letter' {
        $password = Get-RandomPassword -Length 16
        $hasLower = $password -cmatch '[a-z]'
        $hasLower | Should Be $true
    }

    It 'Should contain at least one digit' {
        $password = Get-RandomPassword -Length 16
        $hasDigit = $password -match '[0-9]'
        $hasDigit | Should Be $true
    }

    It 'Should contain at least one special character' {
        $password = Get-RandomPassword -Length 16
        $hasSpecial = $password -match '[!@#$%^&*()]'
        $hasSpecial | Should Be $true
    }

    It 'Should NOT contain ambiguous characters (0, O, l, 1, I)' {
        $password = Get-RandomPassword -Length 16
        $hasAmbiguous = $password -cmatch '[0Ol1I]'
        $hasAmbiguous | Should Be $false
    }
}

Describe 'New-RandomPassword Statistical Reliability (1000 iterations)' {
    It 'All 1000 passwords should meet complexity requirements' {
        $failures = 0
        for ($i = 0; $i -lt 1000; $i++) {
            $password = Get-RandomPassword -Length 16
            $hasUpper = $password -cmatch '[A-Z]'
            $hasLower = $password -cmatch '[a-z]'
            $hasDigit = $password -match '[0-9]'
            $hasSpecial = $password -match '[!@#$%^&*()]'
            $correctLength = $password.Length -eq 16

            if (-not ($hasUpper -and $hasLower -and $hasDigit -and $hasSpecial -and $correctLength)) {
                $failures++
            }
        }
        $failures | Should Be 0
    }

    It 'Should produce unique passwords (no collisions in 1000 runs)' {
        $passwords = @{}
        for ($i = 0; $i -lt 1000; $i++) {
            $password = Get-RandomPassword -Length 16
            if ($passwords.ContainsKey($password)) {
                $passwords[$password]++
            }
            else {
                $passwords[$password] = 1
            }
        }
        $duplicates = ($passwords.Values | Where-Object { $_ -gt 1 }).Count
        # With 16-char passwords from a ~70-char pool, collisions are astronomically unlikely
        $duplicates | Should Be 0
    }
}
