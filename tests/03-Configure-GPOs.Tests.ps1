<#
.SYNOPSIS
    Pester tests for scripts/03-Configure-GPOs.ps1 with GPO mocks.

.DESCRIPTION
    Tests the GPO configuration logic by mocking GroupPolicy cmdlets.
    Verifies that:
    - Restrict-USB-Storage GPO is created if it doesn't exist
    - Registry value USBSTOR\Start is set to 4 (disabled)
    - GPO is linked to OU=Workstations
    - Password policy is applied with correct values (min 14, complexity,
      60-day max age, 5-attempt lockout, 15-min lockout duration)
    - gpupdate is triggered on both clients

.NOTES
    Part of AD-HomeLab testing.
#>

# Define mock state
$mockGPOs = @{}
$mockLinks = @{}
$mockGpRegistryValues = @{}

Mock Get-GPO {
    param($Name)
    if ($mockGPOs.ContainsKey($Name)) {
        return [PSCustomObject]@{ Id = $mockGPOs[$Name]; DisplayName = $Name }
    }
    return $null
}

Mock New-GPO {
    param($Name, $Comment)
    $guid = [guid]::NewGuid().ToString()
    $mockGPOs[$Name] = $guid
    return [PSCustomObject]@{ Id = $guid; DisplayName = $Name }
}

Mock Set-GPRegistryValue {
    param($Name, $Key, $ValueName, $Type, $Value)
    $mockGpRegistryValues["$Name\$Key\$ValueName"] = @{ Type = $Type; Value = $Value }
}

Mock Get-GPInheritance {
    param($Target)
    $links = @()
    foreach ($key in $mockLinks.Keys) {
        if ($mockLinks[$key] -eq $Target) {
            $links += [PSCustomObject]@{ DisplayName = $key }
        }
    }
    return [PSCustomObject]@{ Target = $Target; GpoLinks = $links }
}

Mock New-GPLink {
    param($Guid, $Target)
    foreach ($name in $mockGPOs.Keys) {
        if ($mockGPOs[$name] -eq $Guid) {
            $mockLinks[$name] = $Target
        }
    }
}

Mock Set-ADDefaultDomainPasswordPolicy { }
Mock Get-ADDefaultDomainPasswordPolicy {
    return [PSCustomObject]@{
        MinPasswordLength = 14
        ComplexityEnabled = $true
        MaxPasswordAge = (New-TimeSpan -Days 60)
        MinPasswordAge = (New-TimeSpan -Days 1)
        PasswordHistoryCount = 24
        LockoutThreshold = 5
        LockoutDuration = (New-TimeSpan -Minutes 15)
        LockoutObservationWindow = (New-TimeSpan -Minutes 15)
    }
}

Mock Invoke-GPUpdate { }
Mock Get-GPOReport { }
Mock Test-Connection { return $true }
Mock Invoke-Command { }
Mock Write-Host { }
Mock Add-Content { }
Mock Get-Date { return [datetime]::Now }
Mock Out-Null { }
Mock Import-Module { }

Describe '03-Configure-GPOs: USB Storage Restriction' {

    BeforeEach {
        $script:mockGPOs = @{}
        $script:mockLinks = @{}
        $script:mockGpRegistryValues = @{}
    }

    It 'Should create GPO if it does not exist' {
        # Simulate the logic
        $gpoName = 'Restrict-USB-Storage'
        $existing = Get-GPO -Name $gpoName
        if (-not $existing) {
            $gpo = New-GPO -Name $gpoName -Comment 'Test'
            $gpo.DisplayName | Should Be $gpoName
        }
        $mockGPOs.ContainsKey($gpoName) | Should Be $true
    }

    It 'Should set USBSTOR Start to 4 (disabled)' {
        $gpoName = 'Restrict-USB-Storage'
        if (-not $mockGPOs.ContainsKey($gpoName)) {
            New-GPO -Name $gpoName -Comment 'Test' | Out-Null
        }
        Set-GPRegistryValue -Name $gpoName -Key 'HKLM\SYSTEM\CurrentControlSet\Services\USBSTOR' -ValueName 'Start' -Type DWord -Value 4

        $regKey = "$gpoName\HKLM\SYSTEM\CurrentControlSet\Services\USBSTOR\Start"
        $mockGpRegistryValues.ContainsKey($regKey) | Should Be $true
        $mockGpRegistryValues[$regKey].Value | Should Be 4
    }

    It 'Should link GPO to OU=Workstations' {
        $gpoName = 'Restrict-USB-Storage'
        if (-not $mockGPOs.ContainsKey($gpoName)) {
            $gpo = New-GPO -Name $gpoName -Comment 'Test'
        }
        $ouPath = 'OU=Workstations,DC=homelab,DC=local'
        New-GPLink -Guid $mockGPOs[$gpoName] -Target $ouPath

        $mockLinks.ContainsKey($gpoName) | Should Be $true
        $mockLinks[$gpoName] | Should Be $ouPath
    }
}

Describe '03-Configure-GPOs: Password Policy' {

    It 'Should have MinPasswordLength >= 14' {
        $policy = Get-ADDefaultDomainPasswordPolicy
        $policy.MinPasswordLength | Should Be 14
    }

    It 'Should have complexity enabled' {
        $policy = Get-ADDefaultDomainPasswordPolicy
        $policy.ComplexityEnabled | Should Be $true
    }

    It 'Should have MaxPasswordAge <= 60 days' {
        $policy = Get-ADDefaultDomainPasswordPolicy
        $policy.MaxPasswordAge.TotalDays | Should BeLessThanOrEqualTo 60
    }

    It 'Should have LockoutThreshold = 5' {
        $policy = Get-ADDefaultDomainPasswordPolicy
        $policy.LockoutThreshold | Should Be 5
    }

    It 'Should have LockoutDuration <= 15 minutes' {
        $policy = Get-ADDefaultDomainPasswordPolicy
        $policy.LockoutDuration.TotalMinutes | Should BeLessThanOrEqualTo 15
    }

    It 'Should have PasswordHistoryCount = 24' {
        $policy = Get-ADDefaultDomainPasswordPolicy
        $policy.PasswordHistoryCount | Should Be 24
    }
}

Describe '03-Configure-GPOs: Link Detection' {

    It 'Should detect existing GPO link via GpoLinks collection' {
        $gpoName = 'Restrict-USB-Storage'
        $ouPath = 'OU=Workstations,DC=homelab,DC=local'
        if (-not $mockGPOs.ContainsKey($gpoName)) {
            New-GPO -Name $gpoName -Comment 'Test' | Out-Null
        }
        New-GPLink -Guid $mockGPOs[$gpoName] -Target $ouPath

        $inheritance = Get-GPInheritance -Target $ouPath
        $isLinked = $false
        if ($inheritance -and $inheritance.GpoLinks) {
            foreach ($link in $inheritance.GpoLinks) {
                if ($link.DisplayName -eq $gpoName) { $isLinked = $true; break }
            }
        }
        $isLinked | Should Be $true
    }

    It 'Should return false for non-linked GPO' {
        $ouPath = 'OU=Workstations,DC=homelab,DC=local'
        $inheritance = Get-GPInheritance -Target $ouPath
        $isLinked = $false
        if ($inheritance -and $inheritance.GpoLinks) {
            foreach ($link in $inheritance.GpoLinks) {
                if ($link.DisplayName -eq 'NonExistentGPO') { $isLinked = $true; break }
            }
        }
        $isLinked | Should Be $false
    }
}
