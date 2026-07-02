$root = Split-Path $PSScriptRoot -Parent
$paths = @('scripts', 'hyperv')
foreach ($path in $paths) {
    $files = Get-ChildItem -Path (Join-Path $root $path) -Filter '*.ps1' -ErrorAction SilentlyContinue
    foreach ($file in $files) {
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$errors)
        if ($errors) {
            Write-Host "PARSE ERROR: $($file.Name)" -ForegroundColor Red
            foreach ($e in $errors) { Write-Host "  $($e.Message)" -ForegroundColor Red }
        } else {
            Write-Host "OK: $($file.Name)" -ForegroundColor Green
        }
    }
}
