# Dext Tests Automated Runner
# This script robustly discovers, builds, and verifies all unit tests.

$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$DextRoot = Split-Path -Parent $PSScriptRoot

# Forçar o console a usar UTF-8 (Code Page 65001) para exibir caracteres especiais e emojis corretamente
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
if (Get-Command chcp.com -ErrorAction SilentlyContinue) { chcp.com 65001 | Out-Null }

# 1. Setup Environment from set_env.ps1
$env:DEXT_PROJECT_TYPE = 'Tests'
. "$PSScriptRoot\set_env.ps1" -Platform Win32 -Config Debug -UseSourcePath:$false


$TestsOutput = Join-Path $DextRoot 'Tests\Output'
if (-not (Test-Path $TestsOutput)) {
    New-Item -ItemType Directory -Path $TestsOutput -Force | Out-Null
}

$SuccessCount = 0
$FailCount = 0
$FailedTests = @()

# --- STEP 1: BUILD ---
Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host 'Step 1: Building All Tests (Discovery)' -ForegroundColor Cyan
Write-Host '==========================================' -ForegroundColor Cyan

$TestProjects = Get-ChildItem -Path (Join-Path $DextRoot 'Tests') -Filter '*.dproj' -Recurse | Where-Object { $_.Name -like '*test*' }

foreach ($proj in $TestProjects) {
    $projName = $proj.BaseName
    Write-Host "[BUILD] Project: $projName" -ForegroundColor Yellow

    $MSBuildArgs = @(
        $proj.FullName,
        '/t:Build',
        '/p:Config=Debug',
        '/p:Platform=Win32',
        "/p:DCC_ExeOutput=`"$TestsOutput`"",
        "/p:DCC_DcuOutput=`"$env:OUTPUT_PATH`"",
        '/v:minimal',
        '/nologo'
    )

    $buildOutput = & msbuild @MSBuildArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        $buildText = $buildOutput -join [Environment]::NewLine
        if ($buildText -match 'because it is being used by another process') {
            Write-Host '  [RETRY] Temporary file lock detected, retrying once...' -ForegroundColor Yellow
            Start-Sleep -Seconds 3
            $buildOutput = & msbuild @MSBuildArgs 2>&1
        }
    }

    if ($buildOutput.Count -gt 0) {
        $buildOutput | ForEach-Object { Write-Host $_ }
    }

    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [ERROR] Build failed for $projName" -ForegroundColor Red
    }
}

# --- STEP 2: RUN ---
$Tests = Get-ChildItem -Path $TestsOutput -Filter '*.exe'
Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "Step 2: Running $($Tests.Count) Tests" -ForegroundColor Cyan
Write-Host '==========================================' -ForegroundColor Cyan

foreach ($test in $Tests) {
    $testName = $test.BaseName
    if ($testName -eq 'VclOpenSslTest' -or $testName -eq 'Test.Dext.UI') {
        Write-Host "`n[SKIP] Testing: $testName (form-based/GUI test)" -ForegroundColor DarkYellow
        continue
    }
    Write-Host "`n------------------------------------------"
    Write-Host "[RUN] Testing: $testName" -ForegroundColor Yellow
    Write-Host '------------------------------------------'

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $test.FullName
    $psi.Arguments = '-no-wait'
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $false

    $job = [System.Diagnostics.Process]::Start($psi)
    $job.WaitForExit()

    if ($job.ExitCode -eq 0) {
        Write-Host "[PASSED] $testName" -ForegroundColor Green
        $SuccessCount++
    } else {
        Write-Host "[FAILED] $testName - Exit code: $($job.ExitCode)" -ForegroundColor Red
        $FailedTests += $testName
        $FailCount++
    }
}

# --- SUMMARY ---
Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host 'Test Summary' -ForegroundColor Cyan
Write-Host '==========================================' -ForegroundColor Cyan
Write-Host "  Tests Passed:   $SuccessCount" -ForegroundColor Green
Write-Host "  Tests Failed:   $FailCount" -ForegroundColor $(if ($FailCount -gt 0) { 'Red' } else { 'Green' })

if ($FailedTests.Count -gt 0) {
    Write-Host "`nFailed Tests:" -ForegroundColor Red
    foreach ($p in $FailedTests) { Write-Host "  - $p" -ForegroundColor Red }
    Write-Host "`nTESTS COMPLETED WITH FAILURES" -ForegroundColor Red
    exit 1
}

Write-Host "`nALL TESTS PASSED!" -ForegroundColor Green
exit 0
