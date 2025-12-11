# MinimalEndpoints API Test Script
$baseUrl = "http://localhost:8080"

Write-Host "[TEST] MinimalEndpoints API Test Suite" -ForegroundColor Cyan
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
            $response = Invoke-RestMethod -Method $Method -Uri "$baseUrl$Url" -Headers $Headers -ErrorAction Stop -ContentType $ContentType
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

# 1. User Endpoints
Test-Endpoint "GET" "/api/users/123"
Test-Endpoint "GET" "/api/users/456/name"

$userBody = @{ name = "John Doe"; email = "john@example.com"; age = 30 }
Test-Endpoint "POST" "/api/users" -Body $userBody

$updateBody = @{ name = "Jane Smith"; email = "jane@example.com" }
Test-Endpoint "PUT" "/api/users/789" -Body $updateBody

Test-Endpoint "DELETE" "/api/users/999"

# 2. General Endpoints
Test-Endpoint "GET" "/api/posts/hello-world"

# 3. Health Check
$health = Test-Endpoint "GET" "/api/health"
if ($health) {
    Write-Host "Health Check Details:" -ForegroundColor Cyan
    $health | ConvertTo-Json -Depth 5 | Write-Host -ForegroundColor Gray
}

# 4. Features
Test-Endpoint "GET" "/api/cached"
Test-Endpoint "GET" "/api/error" -ExpectedStatus 500

# 5. Static Files & Context
Test-Endpoint "GET" "/index.html" -ContentType "text/html"
Test-Endpoint "GET" "/api/request-context"

Write-Host "`n[DONE] Test Suite Completed!" -ForegroundColor Green
