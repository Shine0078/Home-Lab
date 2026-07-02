BeforeAll {
    $scripts = Get-ChildItem -Path "$PSScriptRoot\..\scripts" -Filter '*.ps1' -ErrorAction SilentlyContinue
    $hypervScripts = Get-ChildItem -Path "$PSScriptRoot\..\hyperv" -Filter '*.ps1' -ErrorAction SilentlyContinue
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
}

Describe 'Script Help Documentation' {
    It 'All scripts should have comment-based help (.SYNOPSIS)' {
        $allScripts = @()
        if ($scripts)     { $allScripts += $scripts }
        if ($hypervScripts) { $allScripts += $hypervScripts }

        foreach ($script in $allScripts) {
            $content = Get-Content -Path $script.FullName -Raw
            $content | Should -Match '\.SYNOPSIS' -Because "$($script.Name) should have .SYNOPSIS help"
        }
    }
}

Describe 'Gitignore Validation' {
    It '.gitignore should exist' {
        Test-Path "$PSScriptRoot\..\.gitignore" | Should -BeTrue
    }

    It '.gitignore should exclude output/ directory' {
        $content = Get-Content "$PSScriptRoot\..\.gitignore" -Raw
        $content | Should -Match 'output/'
    }

    It '.gitignore should exclude logs/ directory' {
        $content = Get-Content "$PSScriptRoot\..\.gitignore" -Raw
        $content | Should -Match 'logs/'
    }
}
