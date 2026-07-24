# Web.SslDemo Test Script
# Tests the server in HTTPS mode by default (ignoring cert errors)

$ErrorActionPreference = "Stop"
$baseUrl = "https://localhost:8080"

Write-Host "Testing Web.SslDemo" -ForegroundColor Cyan
Write-Host "===================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Testing HTTPS connection (SkipCertificateCheck = true)"
Write-Host ""

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

function Invoke-DextRequest {
    param (
        [string]$Uri,
        [string]$Method = "GET"
    )
    try {
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            $resp = Invoke-WebRequest -Uri $Uri -Method $Method -SkipCertificateCheck -UseBasicParsing
            return @{ 
                StatusCode = $resp.StatusCode
                Content    = $resp.Content
            }
        }
        else {
            $req = [System.Net.HttpWebRequest]::Create($Uri)
            $req.Method = $Method
            $req.ServerCertificateValidationCallback = { $true }
            
            $resp = $req.GetResponse()
            $stream = $resp.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($stream)
            $content = $reader.ReadToEnd()
            $reader.Close()
            $resp.Close()
            
            return @{ 
                StatusCode = [int]$resp.StatusCode
                Content    = $content
            }
        }
    }
    catch {
        throw "Request to $Uri failed: $($_.Exception.Message)"
    }
}

try {
    #                                                                            
    # TEST 1: Basic connectivity (HTTPS)
    #                                                                            
    Write-Host "1. GET / (HTTPS mode)" -ForegroundColor Yellow
    Write-Host "   Checking server connectivity..."
    $resp = Invoke-DextRequest "$baseUrl/"
    if ($resp.StatusCode -ne 200) { throw "Expected 200, got $($resp.StatusCode)" }
    Write-Host "   [OK] Server responding on HTTPS" -ForegroundColor Green
    Write-Host ""

    #                                                                            
    # TEST 2: Verify HTML response
    #                                                                            
    Write-Host "2. Verifying HTML response" -ForegroundColor Yellow
    if ($resp.Content -notmatch "Dext SSL Demo") { throw "Expected 'Dext SSL Demo' in response" }
    Write-Host "   [OK] Response contains 'Dext SSL Demo'" -ForegroundColor Green
    Write-Host ""

    #                                                                            
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
