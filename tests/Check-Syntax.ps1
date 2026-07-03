<#
.SYNOPSIS
    Validates PowerShell script syntax for all scripts in the repo.

.DESCRIPTION
    Parses every .ps1 file in scripts/ and hyperv/ using the PowerShell
    language parser. Reports OK or PARSE ERROR for each file. Exits with
    code 1 if any file has parse errors. Used as a quick local check
    before pushing; the CI pipeline runs PSScriptAnalyzer for deeper
    analysis.

.NOTES
    Part of AD-HomeLab testing.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path $PSScriptRoot -Parent
$paths = @('scripts', 'hyperv')
$hasErrors = $false

foreach ($path in $paths) {
    $dirPath = Join-Path $root $path
    if (-not (Test-Path $dirPath)) { continue }

    $files = Get-ChildItem -Path $dirPath -Filter '*.ps1' -ErrorAction SilentlyContinue
    foreach ($file in $files) {
        $errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$errors)
        if ($errors) {
            Write-Host "PARSE ERROR: $($file.Name)" -ForegroundColor Red
            foreach ($e in $errors) { Write-Host "  $($e.Message)" -ForegroundColor Red }
            $hasErrors = $true
        } else {
            Write-Host "OK: $($file.Name)" -ForegroundColor Green
        }
    }
}

if ($hasErrors) {
    Write-Output ""
    Write-Host "Syntax errors found!" -ForegroundColor Red
    exit 1
} else {
    Write-Output ""
    Write-Host "All scripts passed syntax check." -ForegroundColor Green
}
