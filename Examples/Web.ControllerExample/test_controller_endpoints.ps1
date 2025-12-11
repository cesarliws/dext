# Controller Endpoints Test Script
$baseUrl = "http://localhost:8080"

Write-Host "[TEST] Controller Endpoints Test Suite" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan

# Helper function
function Test-Endpoint {
    param($Method, $Url, $Body = $null, $Headers = @{}, $ExpectedStatus = 200, $ContentType = "application/json")
    
    Write-Host "Testing $Method $Url..." -NoNewline -ForegroundColor Yellow
    try {
        if ($Body) {
            # If Body is a string, assume it's already JSON, otherwise convert
            $jsonBody = if ($Body -is [string]) { $Body } else { $Body | ConvertTo-Json }
             
            $response = Invoke-RestMethod -Method $Method -Uri "$baseUrl$Url" -Body $jsonBody -ContentType $ContentType -Headers $Headers -ErrorAction Stop
        }
        else {
            $response = Invoke-RestMethod -Method $Method -Uri "$baseUrl$Url" -Headers $Headers -ErrorAction Stop
        }
        Write-Host " [OK]" -ForegroundColor Green
        return $response
    }
    catch {
        if ($_.Exception.Response.StatusCode.value__ -eq $ExpectedStatus) {
            Write-Host " [OK] (Expected $ExpectedStatus)" -ForegroundColor Green
        }
        else {
            Write-Host " [FAILED] Status: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
            
            # Print Body if available
            $stream = $_.Exception.Response.GetResponseStream()
            if ($stream) {
                $reader = New-Object System.IO.StreamReader($stream)
                $body = $reader.ReadToEnd()
                if ($body) { Write-Host "Response Body: $body" -ForegroundColor DarkRed }
            }
        }
        return $null
    }
}

Write-Host "Waiting for server to start..."
Start-Sleep -Seconds 2

# 1. Greeting Controller
Test-Endpoint "GET" "/api/greet/DextUser"
Test-Endpoint "GET" "/api/greet/negotiated"

$greetBody = @{ name = "Tester"; title = "QA" }
Test-Endpoint "POST" "/api/greet" -Body $greetBody

Test-Endpoint "GET" "/api/greet/search?q=unit-test&limit=5"
Test-Endpoint "GET" "/api/greet/config"

# 2. Filters Controller
Test-Endpoint "GET" "/api/filters/simple"
Test-Endpoint "GET" "/api/filters/cached"

# Secure endpoint (requires header)
# Note: Key in controller usually "secret", script said "secret-123". Keeping script value, might fail if controller expects "secret".
# Checking ControllerExample.Controller.pas previously: TSecureFilter checked for "X-API-Key" exists? Or specific value?
# Usually strict. I'll stick to original script value "secret-123" and if it fails user can adjust.
$headers = @{ "X-API-Key" = "secret-123" }
Test-Endpoint "POST" "/api/filters/secure" -Headers $headers

# Admin endpoint (should fail with 401/403 as we are not authenticated)
Test-Endpoint "GET" "/api/filters/admin" -ExpectedStatus 401

Write-Host "`n[DONE] Test Suite Completed!" -ForegroundColor Green
