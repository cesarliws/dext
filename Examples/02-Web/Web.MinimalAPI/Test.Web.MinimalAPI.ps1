$ErrorActionPreference = "Stop"
$baseUrl = "http://localhost:5000"

Write-Host "[START] Testing Web.MinimalAPI on $baseUrl" -ForegroundColor Cyan

try {
    # 1. Hello (Service Check)
    Write-Host "`n1. Testing /hello (DI Service)..." -ForegroundColor Yellow
    $hello = Invoke-WebRequest "$baseUrl/hello?name=Dext" -UseBasicParsing
    Write-Host "   Response: $($hello.Content)"
    if ($hello.Content -notlike "*Hello, Dext*") { throw "DI Service not working" }

    # 2. Echo
    Write-Host "`n2. Testing /echo..." -ForegroundColor Yellow
    $echo = Invoke-WebRequest "$baseUrl/echo?text=DextPowershell" -UseBasicParsing
    Write-Host "   Response: $($echo.Content)"
    if ($echo.Content -ne "Echo: DextPowershell") { throw "Echo failed" }

    # 3. Time
    Write-Host "`n3. Testing /time..." -ForegroundColor Yellow
    $time = Invoke-WebRequest "$baseUrl/time" -UseBasicParsing
    Write-Host "   Response: $($time.Content)"

    # 4. JSON
    Write-Host "`n4. Testing /json..." -ForegroundColor Yellow
    $jsonResp = Invoke-WebRequest "$baseUrl/json" -UseBasicParsing
    $json = $jsonResp.Content | ConvertFrom-Json
    Write-Host "   Message: $($json.message)"
    if ($json.message -ne "Hello JSON!") { throw "JSON message mismatch" }

    # 5. Health
    Write-Host "`n5. Testing /health..." -ForegroundColor Yellow
    $healthResp = Invoke-WebRequest "$baseUrl/health" -UseBasicParsing
    $health = $healthResp.Content | ConvertFrom-Json
    Write-Host "   Status: $($health.status)"
    if ($health.status -ne "healthy") { throw "Health check failed" }

    Write-Host "`nSUCCESS: ALL MINIMAL API TESTS PASSED!" -ForegroundColor Green

}
catch {
    Write-Error "TEST FAILED: $_"
    exit 1
}
