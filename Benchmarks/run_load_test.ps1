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
    Write-Host "Building project..." -ForegroundColor Yellow
    & Powershell -ExecutionPolicy Bypass `
        -File "$PSScriptRoot\..\..\DelphiBuildDPROJ.ps1" `
        -ProjectFile "$PSScriptRoot\Dext.Benchmarks.dproj" `
        -Config Release -Platform Win64
}

# Define test settings
$Port = 8085
$Url = "http://127.0.0.1:$Port/ping"
$Concurrency = 125
$Duration = "10s"

function Run-Server-Test($EngineName, $EngineArg, $TestPort) {
    Write-Host "==============================================================" -ForegroundColor Cyan
    Write-Host " RUNNING LOAD TEST FOR: $EngineName" -ForegroundColor Cyan
    Write-Host "==============================================================" -ForegroundColor Cyan
    
    $TestUrl = "http://127.0.0.1:$TestPort/ping"

    # Force kill any previous process running with the same name
    Get-Process -Name "Dext.Benchmarks" -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 2
    
    # Start the server in the background
    Write-Host "Starting server $EngineName..." -ForegroundColor Gray
    $ServerProcess = Start-Process -FilePath $ExePath -ArgumentList "--server", $EngineArg, $TestPort -NoNewWindow -PassThru
    
    # Give the server a moment to spin up and bind to the port
    Start-Sleep -Seconds 4
    
    # Run the load test
    Write-Host "Firing bombardier ($Concurrency concurrency, $Duration duration)..." -ForegroundColor Yellow
    & $BombardierPath -c $Concurrency -d $Duration $TestUrl
    
    # Shutdown the server cleanly
    Write-Host "Stopping server $EngineName..." -ForegroundColor Gray
    $ServerProcess | Stop-Process -Force
    Start-Sleep -Seconds 2
}

# Run Indy on port 8085
Run-Server-Test "Indy (Blocking Thread Pool)" "-indy" 8085

Write-Host ""
Write-Host ""

# Run Native Server on port 8086
if ($IsLinux -or ($env:OS -ne "Windows_NT")) {
    Run-Server-Test "Linux Epoll (High-Performance Async I/O)" "-epoll" 8086
} else {
    Run-Server-Test "Http.sys (Kernel Mode Driver)" "-httpsys" 8086
}

Write-Host "==============================================================" -ForegroundColor Green
Write-Host " LOAD TESTS COMPLETED" -ForegroundColor Green
Write-Host "==============================================================" -ForegroundColor Green
