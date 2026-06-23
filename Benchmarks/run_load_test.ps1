# run_load_test.ps1 - Stress test Dext HTTP servers with bombardier
#
# Usage:
#   .\run_load_test.ps1

$ErrorActionPreference = "Stop"

$BombardierPath = "C:\dev\tools\bombardier-windows-amd64.exe"
if (-not (Test-Path $BombardierPath)) {
    Write-Error "Bombardier executable not found at: $BombardierPath"
}

$ExePath = Join-Path $PSScriptRoot "Dext.Benchmarks.exe"
if (-not (Test-Path $ExePath)) {
    Write-Host "Dext.Benchmarks.exe not found. Building project..." -ForegroundColor Yellow
    & Powershell -ExecutionPolicy Bypass -File "$PSScriptRoot\..\..\DelphiBuildDPROJ.ps1" -ProjectFile "$PSScriptRoot\Dext.Benchmarks.dproj" -Config Debug -Platform Win32
}

# Define test settings
$Port = 8085
$Url = "http://127.0.0.1:$Port/ping"
$Concurrency = 125
$Duration = "10s"

function Run-Server-Test($EngineName, $EngineArg) {
    Write-Host "==============================================================" -ForegroundColor Cyan
    Write-Host " RUNNING LOAD TEST FOR: $EngineName" -ForegroundColor Cyan
    Write-Host "==============================================================" -ForegroundColor Cyan
    
    # Force kill any previous process running on the port or with the same name
    Get-Process -Name "Dext.Benchmarks" -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 1
    
    # Start the server in the background
    Write-Host "Starting server $EngineName..." -ForegroundColor Gray
    $ServerProcess = Start-Process -FilePath $ExePath -ArgumentList "--server", $EngineArg -NoNewWindow -PassThru
    
    # Give the server a moment to spin up and bind to the port
    Start-Sleep -Seconds 4
    
    # Run the load test
    Write-Host "Firing bombardier ($Concurrency concurrency, $Duration duration)..." -ForegroundColor Yellow
    & $BombardierPath -c $Concurrency -d $Duration $Url
    
    # Shutdown the server cleanly
    Write-Host "Stopping server $EngineName..." -ForegroundColor Gray
    $ServerProcess | Stop-Process -Force
    Start-Sleep -Seconds 1
}

# Run Indy
Run-Server-Test "Indy (Blocking Thread Pool)" "-indy"

Write-Host ""
Write-Host ""

# Run HttpSys
Run-Server-Test "Http.sys (Kernel Mode Driver)" "-httpsys"

Write-Host "==============================================================" -ForegroundColor Green
Write-Host " LOAD TESTS COMPLETED" -ForegroundColor Green
Write-Host "==============================================================" -ForegroundColor Green
