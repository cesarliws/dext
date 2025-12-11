# Filters Test Script
$baseUrl = "http://localhost:8080"
$token = ""

Write-Host "[TEST] Filters Test Suite" -ForegroundColor Cyan
Write-Host "=========================" -ForegroundColor Cyan

# Helper function
function Test-Endpoint {
    param($Method = "GET", $Url, $Body = $null, $Headers = @{}, $ExpectedStatus = 200, $Description = "")
    
    $displayUrl = if ($Description) { "$Description ($Url)" } else { $Url }
    Write-Host "Testing $displayUrl..." -NoNewline -ForegroundColor Yellow
    
    try {
        if ($Body) {
            $jsonBody = if ($Body -is [string]) { $Body } else { $Body | ConvertTo-Json }
            $response = Invoke-RestMethod -Method $Method -Uri $Url -Body $jsonBody -ContentType "application/json" -Headers $Headers -ErrorAction Stop
        }
        else {
            $response = Invoke-RestMethod -Method $Method -Uri $Url -Headers $Headers -ErrorAction Stop
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

# 1. Simple Endpoint
Test-Endpoint "GET" "$baseUrl/api/filters/simple" -Description "Simple Endpoint"

# 2. Cached Endpoint
Test-Endpoint "GET" "$baseUrl/api/filters/cached" -Description "Cached Endpoint"

# 3. Secure Endpoint (Header Validation)
Test-Endpoint "POST" "$baseUrl/api/filters/secure" -Method "POST" -Headers @{ "X-API-Key" = "secret" } -Description "Secure Endpoint (Valid Key)"

# 3.1 Secure Endpoint (Missing Key)
Test-Endpoint "POST" "$baseUrl/api/filters/secure" -Method "POST" -ExpectedStatus 401 -Description "Secure Endpoint (Missing Key)"

# 4. Auth
$loginResponse = Test-Endpoint "POST" "$baseUrl/api/auth/login" -Body @{ username = "admin"; password = "admin" } -Description "Login"
if ($loginResponse) {
    $token = $loginResponse.token
    Write-Host "Token obtained." -ForegroundColor Gray
}
else {
    Write-Host "Login Failed. Aborting." -ForegroundColor Red
    exit
}

$GlobalHeaders = @{ "Authorization" = "Bearer $token" }

# 5. Admin Endpoint
Test-Endpoint "GET" "$baseUrl/api/filters/admin" -Headers $GlobalHeaders -Description "Admin Endpoint"

# 6. Protected Endpoint
Test-Endpoint "GET" "$baseUrl/api/filters/protected" -Headers $GlobalHeaders -Description "Protected Endpoint"

Write-Host "`n[DONE] Test Suite Completed!" -ForegroundColor Green
