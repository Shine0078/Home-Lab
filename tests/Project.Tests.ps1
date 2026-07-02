BeforeAll {
    $repoRoot = Split-Path $PSScriptRoot -Parent
    $scripts = Get-ChildItem -Path (Join-Path $repoRoot 'scripts') -Filter '*.ps1' -ErrorAction SilentlyContinue
    $hypervScripts = Get-ChildItem -Path (Join-Path $repoRoot 'hyperv') -Filter '*.ps1' -ErrorAction SilentlyContinue
    $dataScripts = Get-ChildItem -Path (Join-Path $repoRoot 'data') -Filter '*.ps1' -ErrorAction SilentlyContinue
    $testScripts = Get-ChildItem -Path (Join-Path $repoRoot 'tests') -Filter '*.ps1' -ErrorAction SilentlyContinue
}

Describe 'Script Syntax Validation' {
    It 'All scripts in scripts/ should parse without syntax errors' {
        foreach ($script in $scripts) {
            $errors = $null
            [System.Management.Automation.Language.Parser]::ParseFile(
                $script.FullName, [ref]$null, [ref]$errors
            )
            $errors | Should -BeNullOrEmpty -Because "$($script.Name) should have no parse errors"
        }
    }

    It 'All scripts in hyperv/ should parse without syntax errors' {
        foreach ($script in $hypervScripts) {
            $errors = $null
            [System.Management.Automation.Language.Parser]::ParseFile(
                $script.FullName, [ref]$null, [ref]$errors
            )
            $errors | Should -BeNullOrEmpty -Because "$($script.Name) should have no parse errors"
        }
    }

    It 'All scripts in data/ should parse without syntax errors' {
        foreach ($script in $dataScripts) {
            $errors = $null
            [System.Management.Automation.Language.Parser]::ParseFile(
                $script.FullName, [ref]$null, [ref]$errors
            )
            $errors | Should -BeNullOrEmpty -Because "$($script.Name) should have no parse errors"
        }
    }

    It 'All scripts in tests/ should parse without syntax errors' {
        foreach ($script in $testScripts) {
            $errors = $null
            [System.Management.Automation.Language.Parser]::ParseFile(
                $script.FullName, [ref]$null, [ref]$errors
            )
            $errors | Should -BeNullOrEmpty -Because "$($script.Name) should have no parse errors"
        }
    }
}

Describe 'Script Help Documentation' {
    It 'All PowerShell scripts should have comment-based help (.SYNOPSIS)' {
        $allScripts = @()
        if ($scripts)      { $allScripts += $scripts }
        if ($hypervScripts) { $allScripts += $hypervScripts }
        if ($dataScripts)   { $allScripts += $dataScripts }
        if ($testScripts)   { $allScripts += $testScripts }

        foreach ($script in $allScripts) {
            $content = Get-Content -Path $script.FullName -Raw
            $content | Should -Match '\.SYNOPSIS' -Because "$($script.Name) should have .SYNOPSIS help"
        }
    }
}

Describe 'Data File Validation' {
    It 'users.csv should exist and contain exactly 50 users' {
        $csvPath = Join-Path $repoRoot 'data\users.csv'
        Test-Path $csvPath | Should -BeTrue -Because 'users.csv must exist for bulk user creation'

        $users = Import-Csv -Path $csvPath
        $users.Count | Should -Be 50 -Because 'exactly 50 users are expected'
    }

    It 'users.csv should have required columns' {
        $csvPath = Join-Path $repoRoot 'data\users.csv'
        $users = Import-Csv -Path $csvPath
        $first = $users[0]
        $first.PSObject.Properties.Name | Should -Contain 'FirstName'
        $first.PSObject.Properties.Name | Should -Contain 'LastName'
        $first.PSObject.Properties.Name | Should -Contain 'Department'
        $first.PSObject.Properties.Name | Should -Contain 'Title'
    }
}

Describe 'Gitignore Validation' {
    It '.gitignore should exist' {
        Test-Path (Join-Path $repoRoot '.gitignore') | Should -BeTrue
    }

    It '.gitignore should exclude output/ directory' {
        $content = Get-Content (Join-Path $repoRoot '.gitignore') -Raw
        $content | Should -Match 'output/'
    }

    It '.gitignore should exclude logs/ directory' {
        $content = Get-Content (Join-Path $repoRoot '.gitignore') -Raw
        $content | Should -Match 'logs/'
    }

    It '.gitignore should exclude credential CSVs but allow data/users.csv' {
        $content = Get-Content (Join-Path $repoRoot '.gitignore') -Raw
        $content | Should -Match '\*\.csv'
        $content | Should -Match '!data/\*\.csv'
    }
}
