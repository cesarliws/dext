# ControllerExample API Test Script
$baseUrl = "http://localhost:8080"
$token = ""

Write-Host "[TEST] ControllerExample API Test Suite" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan

# Helper function
function Test-Endpoint {
    param($Method, $Url, $Body = $null, $Headers = @{}, $ExpectedStatus = 200)
    
    Write-Host "Testing $Method $Url..." -NoNewline -ForegroundColor Yellow
    try {
        if ($Body) {
            $response = Invoke-RestMethod -Method $Method -Uri "$baseUrl$Url" -Body ($Body | ConvertTo-Json) -ContentType "application/json" -Headers $Headers -ErrorAction Stop
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

# 1. Health Check
$health = Test-Endpoint "GET" "/health"
if ($health) {
    Write-Host "Health Check Details:" -ForegroundColor Cyan
    $health | ConvertTo-Json -Depth 5 | Write-Host -ForegroundColor Gray
}

# 2. Auth Controller (Get Token First)
$loginResponse = Test-Endpoint "POST" "/api/auth/login" -Body @{ username = "admin"; password = "admin" }
if ($loginResponse) {
    $token = $loginResponse.token
    Write-Host "Token obtained: $($token.Substring(0, 10))..." -ForegroundColor Gray
}

Test-Endpoint "POST" "/api/auth/login" -Body @{ username = "wrong"; password = "user" } -ExpectedStatus 401

# 3. Greeting Controller (Use Token)
Test-Endpoint "GET" "/api/greet/World" -Headers @{"Authorization" = "Bearer $token" }
Test-Endpoint "GET" "/api/greet/negotiated" -Headers @{"Authorization" = "Bearer $token" }
Test-Endpoint "GET" "/api/greet/negotiated" -Headers @{"Accept" = "application/json"; "Authorization" = "Bearer $token" } 
Test-Endpoint "POST" "/api/greet" -Body @{ Name = "Dext"; Title = "Framework" } -Headers @{"Authorization" = "Bearer $token" }
Test-Endpoint "GET" "/api/greet/search?q=test&limit=10" -Headers @{"Authorization" = "Bearer $token" }
Test-Endpoint "GET" "/api/greet/config" -Headers @{"Authorization" = "Bearer $token" }

# 4. Filters Controller
Test-Endpoint "GET" "/api/filters/simple"
Test-Endpoint "GET" "/api/filters/cached"

# Secure Endpoint (Header Check)
Test-Endpoint "POST" "/api/filters/secure" -ExpectedStatus 400 # Missing header
Test-Endpoint "POST" "/api/filters/secure" -Headers @{"X-API-Key" = "secret" } 

# Protected Endpoint (Auth Header Check)
Test-Endpoint "GET" "/api/filters/protected" -ExpectedStatus 400 # Custom logic checks header not just jwt? 
# Wait, ProtectedEndpoint has [RequireHeader('Authorization', ...)]
Test-Endpoint "GET" "/api/filters/protected" -Headers @{"Authorization" = "Bearer $token" }

# Admin Endpoint (Role Check)
Test-Endpoint "GET" "/api/filters/admin" -ExpectedStatus 401 # No Auth
Test-Endpoint "GET" "/api/filters/admin" -Headers @{"Authorization" = "Bearer $token" } 

# 5. API Versioning
# Query String
Test-Endpoint "GET" "/api/versioned?api-version=1.0"
Test-Endpoint "GET" "/api/versioned?api-version=2.0"

# Header
Test-Endpoint "GET" "/api/versioned" -Headers @{"X-Version" = "1.0" }
Test-Endpoint "GET" "/api/versioned" -Headers @{"X-Version" = "2.0" }


Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "[DONE] Test Suite Completed!" -ForegroundColor Green
