<#
.SYNOPSIS
    Pester tests for AD-HomeLab project.

.DESCRIPTION
    Validates that all PowerShell scripts parse without syntax errors,
    have comment-based help, that data files are correct, and that
    .gitignore is properly configured. Compatible with Pester 3.4+ and 5.x.

.NOTES
    Part of AD-HomeLab testing.
#>

$repoRoot = Split-Path $PSScriptRoot -Parent

function Get-AllScript {
    $scripts = @()
    $dirs = @('scripts', 'hyperv', 'data', 'tests')
    foreach ($dir in $dirs) {
        $dirPath = Join-Path $repoRoot $dir
        if (Test-Path $dirPath) {
            $found = Get-ChildItem -Path $dirPath -Filter '*.ps1' -ErrorAction SilentlyContinue
            if ($found) { $scripts += $found }
        }
    }
    return $scripts
}

Describe 'Script Syntax Validation' {
    $allScripts = Get-AllScript

    It 'All PowerShell scripts should parse without syntax errors' {
        $parseErrors = @()
        foreach ($script in $allScripts) {
            $errors = $null
            [System.Management.Automation.Language.Parser]::ParseFile(
                $script.FullName, [ref]$null, [ref]$errors
            )
            if ($errors) {
                $parseErrors += "$($script.Name): $($errors.Message -join ', ')"
            }
        }
        $parseErrors | Should BeNullOrEmpty
    }
}

Describe 'Script Help Documentation' {
    $allScripts = Get-AllScript

    It 'All PowerShell scripts should have comment-based help (.SYNOPSIS)' {
        $missing = @()
        foreach ($script in $allScripts) {
            $content = Get-Content -Path $script.FullName -Raw
            if ($content -notmatch '\.SYNOPSIS') {
                $missing += $script.Name
            }
        }
        $missing | Should BeNullOrEmpty
    }
}

Describe 'Data File Validation' {
    It 'users.csv should exist and contain exactly 50 users' {
        $csvPath = Join-Path $repoRoot 'data\users.csv'
        Test-Path $csvPath | Should Be $true
        $users = Import-Csv -Path $csvPath
        $users.Count | Should Be 50
    }

    It 'users.csv should have required columns' {
        $csvPath = Join-Path $repoRoot 'data\users.csv'
        $users = Import-Csv -Path $csvPath
        $first = $users[0]
        $columns = $first.PSObject.Properties.Name
        $columns -contains 'FirstName' | Should Be $true
        $columns -contains 'LastName' | Should Be $true
        $columns -contains 'Department' | Should Be $true
        $columns -contains 'Title' | Should Be $true
    }
}

Describe 'Gitignore Validation' {
    It '.gitignore should exist' {
        $gitignorePath = Join-Path $repoRoot '.gitignore'
        Test-Path $gitignorePath | Should Be $true
    }

    It '.gitignore should exclude output/ directory' {
        $content = Get-Content (Join-Path $repoRoot '.gitignore') -Raw
        $content | Should Match 'output/'
    }

    It '.gitignore should exclude logs/ directory' {
        $content = Get-Content (Join-Path $repoRoot '.gitignore') -Raw
        $content | Should Match 'logs/'
    }

    It '.gitignore should exclude credential CSVs but allow data/users.csv' {
        $content = Get-Content (Join-Path $repoRoot '.gitignore') -Raw
        $content | Should Match '\*\.csv'
        $content | Should Match '!data/users\.csv'
    }
}
