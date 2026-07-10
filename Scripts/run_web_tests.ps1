# Dext Web Unit Tests Runner
# This script builds and executes Dext.Web.UnitTests.dproj only.

$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$DextRoot = Split-Path -Parent $PSScriptRoot

# Force console to UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
if (Get-Command chcp.com -ErrorAction SilentlyContinue) { chcp.com 65001 | Out-Null }

function Invoke-MsBuildWithRetry {
    param([string[]]$Arguments)

    $attempt = 1
    while ($attempt -le 4) {
        $buildOutput = & msbuild @Arguments 2>&1
        $exitCode = $LASTEXITCODE
        if ($exitCode -eq 0) {
            return [PSCustomObject]@{ ExitCode = 0; Output = $buildOutput }
        }

        $buildText = $buildOutput -join [Environment]::NewLine
        $lockDetected = ($buildText -match 'because it is being used by another process') -or
                        (($buildText -match 'UnauthorizedAccessException') -and ($buildText -match 'tmp[0-9A-Fa-f]+\.tmp'))
        if ($lockDetected -and $attempt -lt 4) {
            Write-Host '  [RETRY] Temporary file lock detected, retrying...' -ForegroundColor Yellow
            Start-Sleep -Seconds 2
            $attempt++
            continue
        }

        return [PSCustomObject]@{ ExitCode = $exitCode; Output = $buildOutput }
    }

    return [PSCustomObject]@{ ExitCode = 1; Output = @() }
}

# 1. Setup Environment
$env:DEXT_PROJECT_TYPE = 'Tests'
. "$PSScriptRoot\set_env.ps1" -Platform Win32 -Config Debug -UseSourcePath:$false

$TestsOutput = Join-Path $DextRoot 'Tests\Output'
if (-not (Test-Path $TestsOutput)) {
    New-Item -ItemType Directory -Path $TestsOutput -Force | Out-Null
}

$projName = 'Dext.Web.UnitTests'
$projPath = Join-Path $DextRoot "Tests\Web\$projName.dproj"

Write-Host "`n[INIT] Processing: $projName" -ForegroundColor White

# 2. Build
Write-Host '  [BUILD] Compiling...' -NoNewline
$msbuildArgs = @(
    "`"$projPath`"",
    '/t:Build',
    "/p:Configuration=$($env:BUILD_CONFIG)",
    "/p:Platform=$($env:PLATFORM)",
    '/p:VerInfo_Keys=',
    '/p:VerInfo_Locale=',
    "/p:DCC_ExeOutput=`"$TestsOutput`"",
    "/p:DCC_DcuOutput=`"$env:OUTPUT_PATH`"",
    "/p:DCC_UnitSearchPath=`"$($env:SEARCH_PATH)`"",
    '/p:DCC_BuildAllUnits=true',
    '/p:DCC_MapFile=3',
    '/v:minimal',
    '/nologo'
)

$buildResult = Invoke-MsBuildWithRetry -Arguments $msbuildArgs
if ($buildResult.Output.Count -gt 0) {
    $buildResult.Output | ForEach-Object { Write-Host $_ }
}

if ($buildResult.ExitCode -ne 0) {
    Write-Host ' FAILED' -ForegroundColor Red
    exit 1
}
Write-Host ' OK' -ForegroundColor Green

# 3. Execute
$exePath = Join-Path $TestsOutput "$projName.exe"
if (!(Test-Path $exePath)) {
    Write-Host '  [ERROR] EXE missing after successful build!' -ForegroundColor Red
    exit 1
}

Write-Host '  [RUN] Executing tests...' -ForegroundColor Yellow

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $exePath
$psi.Arguments = '-no-wait'
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $false

$job = [System.Diagnostics.Process]::Start($psi)
$job.WaitForExit()

if ($job.ExitCode -eq 0) {
    Write-Host "  [PASSED] $projName" -ForegroundColor Green
    exit 0
} else {
    Write-Host "  [FAILED] $projName (ExitCode: $($job.ExitCode))" -ForegroundColor Red
    exit 1
}
