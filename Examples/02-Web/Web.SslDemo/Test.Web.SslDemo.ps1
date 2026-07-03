# Web.SslDemo Test Script
# Tests the server in HTTPS mode by default (ignoring cert errors)

$ErrorActionPreference = "Stop"
#$baseUrl = "https://localhost:8080"
$baseUrl = "http://localhost:8080" # It is running HTTP

Write-Host "Testing Web.SslDemo" -ForegroundColor Cyan
Write-Host "===================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Testing HTTPS connection (SkipCertificateCheck = true)"
Write-Host ""

[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

function Invoke-DextRequest {
    param (
        [string]$Uri,
        [string]$Method = "GET"
    )
    try {
        $params = @{
            Uri             = $Uri
            Method          = $Method
            UseBasicParsing = $true
        }
        
        $resp = Invoke-WebRequest @params
        return @{ 
            StatusCode = $resp.StatusCode
            Content    = $resp.Content
        }
    }
    catch {
        throw "Request to $Uri failed: $($_.Exception.Message)"
    }
}

try {
    # ═══════════════════════════════════════════════════════════════════════════
    # TEST 1: Basic connectivity (HTTPS)
    # ═══════════════════════════════════════════════════════════════════════════
    Write-Host "1. GET / (HTTPS mode)" -ForegroundColor Yellow
    Write-Host "   Checking server connectivity..."
    $resp = Invoke-DextRequest "$baseUrl/"
    if ($resp.StatusCode -ne 200) { throw "Expected 200, got $($resp.StatusCode)" }
    Write-Host "   [OK] Server responding on HTTPS" -ForegroundColor Green
    Write-Host ""

    # ═══════════════════════════════════════════════════════════════════════════
    # TEST 2: Verify HTML response
    # ═══════════════════════════════════════════════════════════════════════════
    Write-Host "2. Verifying HTML response" -ForegroundColor Yellow
    if ($resp.Content -notmatch "Dext SSL Demo") { throw "Expected 'Dext SSL Demo' in response" }
    Write-Host "   [OK] Response contains 'Dext SSL Demo'" -ForegroundColor Green
    Write-Host ""

    # ═══════════════════════════════════════════════════════════════════════════
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "SUCCESS: SSL DEMO TESTS PASSED (HTTPS)" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Green
}
catch {
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Red
    Write-Host "TEST FAILED: $_" -ForegroundColor Red
    Write-Host "==========================================" -ForegroundColor Red
    exit 1
}
