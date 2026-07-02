@{
    RootModule        = 'ADHomeLab.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'a3b7c4d2-e5f6-4a8b-9c1d-0e2f3a4b5c6d'
    Author            = 'AD-HomeLab'
    CompanyName       = 'AD-HomeLab'
    Copyright         = '(c) 2026 AD-HomeLab. MIT license.'
    Description       = 'Shared utility functions for the AD-HomeLab project: logging, password generation, AD helpers, GPO helpers.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('Write-Log', 'New-RandomPassword', 'Test-ADReady', 'Install-FeatureIfMissing', 'Get-ActiveAdapter', 'New-OrGetGPO', 'Set-GPOLinkIfMissing')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    HelpInfoURI       = 'https://github.com/samue/AD-HomeLab'
}
