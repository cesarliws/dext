# Dext Tests Automated Runner V2
# This script robustly discovers, builds, and executes unit tests individually.
# Based on the dynamic feedback pattern of run_examples.ps1

$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$DextRoot = Split-Path -Parent $PSScriptRoot

# Force console to UTF-8 (Code Page 65001) for correct character and emoji display
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
if (Get-Command chcp.com -ErrorAction SilentlyContinue) { chcp.com 65001 | Out-Null }

# 1. Setup Environment from set_env.ps1
$env:DEXT_PROJECT_TYPE = "Tests"
. "$PSScriptRoot\set_env.ps1" Win32 Debug

$TestsOutput = Join-Path $DextRoot "Tests\Output"
if (-not (Test-Path $TestsOutput)) {
    New-Item -ItemType Directory -Path $TestsOutput -Force | Out-Null
}

# 2. Discover Projects
Write-Host "`n[INIT] Discovering test projects..." -ForegroundColor Cyan
$projects = Get-ChildItem -Path (Join-Path $DextRoot "Tests") `
    -Filter "*.dproj" -Recurse | Where-Object { 
        $_.Name -like "*test*" -and `
        $_.FullName -notmatch "__history" -and `
        $_.Name -notlike "*VclOpenSslTest*"
    }

$total = $projects.Count
Write-Host "[INIT] Found $total test projects to process."

# 3. Process Projects
$results = @()
$current = 0

foreach ($proj in $projects) {
    $current++
    $projName = $proj.BaseName
    $projPath = $proj.FullName
    $projDir = $proj.DirectoryName
    
    Write-Host "`n[$current/$total] Processing: $projName" -ForegroundColor White
    
    # 3a. Build
    Write-Host "  [BUILD] Compiling..." -NoNewline
    $msbuildArgs = @(
        "`"$projPath`"",
        "/t:Build",
        "/p:Configuration=$($env:BUILD_CONFIG)",
        "/p:Platform=$($env:PLATFORM)",
        "/p:ProductVersion=$($env:PRODUCT_VERSION)",
        "/p:DCC_ExeOutput=`"$TestsOutput`"",
        "/p:DCC_DcuOutput=`"$env:OUTPUT_PATH`"",
        "/p:DCC_UnitSearchPath=`"$($env:SEARCH_PATH)`"",
        "/p:DCC_BuildAllUnits=true",
        "/v:minimal",
        "/nologo"
    )
    
    $process = Start-Process -FilePath "msbuild" -ArgumentList $msbuildArgs -Wait -NoNewWindow -PassThru
    
    if ($process.ExitCode -ne 0) {
        Write-Host " FAILED" -ForegroundColor Red
        $results += [PSCustomObject]@{ Project = $projName; Status = "Build Failed"; Dir = $projDir }
        continue
    }
    Write-Host " OK" -ForegroundColor Green
    
    # 3b. Execute Test
    $exePath = Join-Path $TestsOutput "$projName.exe"
    if (!(Test-Path $exePath)) {
        Write-Host "  [ERROR] EXE missing after successful build!" -ForegroundColor Red
        $results += [PSCustomObject]@{ Project = $projName; Status = "EXE Not Found"; Dir = $projDir }
        continue
    }
    
    Write-Host "  [RUN] Executing tests..." -ForegroundColor Yellow
    
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $exePath
    $psi.Arguments = "-no-wait"
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $false
    
    $job = [System.Diagnostics.Process]::Start($psi)
    $job.WaitForExit()
    
    if ($job.ExitCode -eq 0) {
        Write-Host "  [PASSED] $projName" -ForegroundColor Green
        $results += [PSCustomObject]@{ Project = $projName; Status = "Passed"; Dir = $projDir }
    } else {
        Write-Host "  [FAILED] $projName (ExitCode: $($job.ExitCode))" -ForegroundColor Red
        $results += [PSCustomObject]@{ Project = $projName; Status = "Test Failed"; Dir = $projDir }
    }
}

# 4. Final Summary
Write-Host "`n" + ("=" * 40)
Write-Host " Dext Unit Tests Summary"
Write-Host ("=" * 40)
$passed = ($results | Where-Object { $_.Status -eq "Passed" }).Count
$failed = $results.Count - $passed

$failColor = if ($failed -gt 0) { "Red" } else { "Gray" }
Write-Host " Projects Passed: $passed" -ForegroundColor Green
Write-Host " Projects Failed: $failed" -ForegroundColor $failColor

if ($failed -gt 0) {
    Write-Host "`n Failed Projects:" -ForegroundColor Red
    $results | Where-Object { $_.Status -ne "Passed" } | ForEach-Object {
        Write-Host "  - $($_.Project) [$($_.Status)]"
    }
    Write-Host "`n" + ("=" * 40)
    exit 1
}

Write-Host "`n ALL TESTS PASSED SUCCESSFULLY!" -ForegroundColor Green
Write-Host ("=" * 40)
exit 0
