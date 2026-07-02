<#
.SYNOPSIS
    Generates the users.csv data file for bulk user creation.

.DESCRIPTION
    Creates a realistic dataset of 50 AD user accounts spread across
    five departments: IT, Sales, Finance, Ops, HR. Run once to generate
    data/users.csv, then use scripts/04-Create-Users.ps1 to import.
    Idempotent: regenerates the file each run with new random picks.

.NOTES
    Part of AD-HomeLab Phase 5.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Departments = @(
    @{ Name = 'IT';      Titles = @('Systems Administrator','Network Engineer','Help Desk Technician','IT Manager','DevOps Engineer') }
    @{ Name = 'Sales';   Titles = @('Sales Representative','Account Executive','Sales Manager','Business Development Rep') }
    @{ Name = 'Finance'; Titles = @('Financial Analyst','Accountant','Controller','Payroll Specialist') }
    @{ Name = 'Ops';     Titles = @('Operations Manager','Logistics Coordinator','Facilities Specialist','Fleet Manager') }
    @{ Name = 'HR';      Titles = @('HR Generalist','Recruiter','Benefits Administrator','Training Specialist') }
)

$FirstNames = @(
    'James','Mary','Robert','Patricia','John','Jennifer','Michael','Linda',
    'David','Elizabeth','William','Barbara','Richard','Susan','Joseph','Jessica',
    'Thomas','Sarah','Charles','Karen','Christopher','Lisa','Daniel','Nancy',
    'Matthew','Betty','Anthony','Margaret','Mark','Sandra','Donald','Ashley',
    'Steven','Kimberly','Paul','Emily','Andrew','Donna','Joshua','Michelle',
    'Kenneth','Dorothy','Kevin','Carol','Brian','Amanda','George','Melissa',
    'Timothy','Deborah'
)

$LastNames = @(
    'Smith','Johnson','Williams','Brown','Jones','Garcia','Miller','Davis',
    'Rodriguez','Martinez','Hernandez','Lopez','Gonzalez','Wilson','Anderson',
    'Thomas','Taylor','Moore','Jackson','Martin','Lee','Perez','Thompson',
    'White','Harris','Sanchez','Clark','Ramirez','Lewis','Robinson',
    'Walker','Young','Allen','King','Wright','Scott','Torres','Nguyen',
    'Hill','Flores','Green','Adams','Nelson','Baker','Hall','Rivera',
    'Campbell','Mitchell','Carter','Roberts'
)

$Users = @()
$usedNames = @{}

for ($i = 0; $i -lt 50; $i++) {
    do {
        $first = $FirstNames | Get-Random
        $last  = $LastNames | Get-Random
        $key   = "$first.$last"
    } while ($usedNames.ContainsKey($key))
    $usedNames[$key] = $true

    $dept  = $Departments | Get-Random
    $title = $dept.Titles | Get-Random

    $Users += [PSCustomObject]@{
        FirstName  = $first
        LastName   = $last
        Department = $dept.Name
        Title      = $title
    }
}

$OutputPath = Join-Path $PSScriptRoot 'users.csv'
$Users | Export-Csv -Path $OutputPath -NoTypeInformation -Force
Write-Host "Generated $($Users.Count) users -> $OutputPath"
