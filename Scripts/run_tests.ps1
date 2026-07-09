# Dext Tests Automated Runner V2
# This script robustly discovers, builds, and executes unit tests individually.
# Based on the dynamic feedback pattern of run_examples.ps1

$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$DextRoot = Split-Path -Parent $PSScriptRoot

# Force console to UTF-8 (Code Page 65001) for correct character and emoji display
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
if (Get-Command chcp.com -ErrorAction SilentlyContinue) { chcp.com 65001 | Out-Null }

function Invoke-MsBuildWithRetry {
    param([string[]]$Arguments)

    $attempt = 1
    while ($attempt -le 2) {
        $buildOutput = & msbuild @Arguments 2>&1
        $exitCode = $LASTEXITCODE
        if ($exitCode -eq 0) {
            return [PSCustomObject]@{ ExitCode = 0; Output = $buildOutput }
        }

        $buildText = $buildOutput -join [Environment]::NewLine
        if ($attempt -eq 1 -and $buildText -match 'because it is being used by another process') {
            Write-Host '  [RETRY] Temporary file lock detected, retrying once...' -ForegroundColor Yellow
            Start-Sleep -Seconds 1
            $attempt++
            continue
        }

        return [PSCustomObject]@{ ExitCode = $exitCode; Output = $buildOutput }
    }

    return [PSCustomObject]@{ ExitCode = 1; Output = @() }
}

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
    if ($projName -eq 'VclOpenSslTest') {
        Write-Host "[SKIP] Project: $projName (form-based test)" -ForegroundColor DarkYellow
        continue
    }
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

    $buildResult = Invoke-MsBuildWithRetry -Arguments $MSBuildArgs
    if ($buildResult.Output.Count -gt 0) {
        $buildResult.Output | ForEach-Object { Write-Host $_ }
    }

    if ($buildResult.ExitCode -ne 0) {
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
    if ($testName -eq 'VclOpenSslTest') {
        Write-Host "`n[SKIP] Testing: $testName (form-based test)" -ForegroundColor DarkYellow
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

