# Web Features Test Script
$baseUrl = "http://localhost:8080"
$token = ""

Write-Host "[TEST] Web Features Test Suite" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan

# Helper function
function Test-Endpoint {
    param($Method = "GET", $Url, $Body = $null, $Headers = @{}, $ExpectedStatus = 200, $Description = "")
    
    $displayUrl = if ($Description) { "$Description ($Url)" } else { $Url }
    Write-Host "Testing $displayUrl..." -NoNewline -ForegroundColor Yellow
    
    try {
        if ($Body) {
            $response = Invoke-RestMethod -Method $Method -Uri $Url -Body ($Body | ConvertTo-Json) -ContentType "application/json" -Headers $Headers -ErrorAction Stop
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

# 0. Authentication
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

# 1. Content Negotiation
Test-Endpoint "GET" "$baseUrl/api/greet/negotiated" -Headers $GlobalHeaders -Description "Content Negotiation (JSON Default)"

$JsonHeaders = $GlobalHeaders.Clone()
$JsonHeaders["Accept"] = "application/json"
Test-Endpoint "GET" "$baseUrl/api/greet/negotiated" -Headers $JsonHeaders -Description "Content Negotiation (Explicit JSON)"

# 2. API Versioning - Query String
Test-Endpoint "GET" "$baseUrl/api/versioned?api-version=1.0" -Headers $GlobalHeaders -Description "Versioning V1 (Query)"
Test-Endpoint "GET" "$baseUrl/api/versioned?api-version=2.0" -Headers $GlobalHeaders -Description "Versioning V2 (Query)"

# 3. API Versioning - Header
$V1Headers = $GlobalHeaders.Clone()
$V1Headers["X-Version"] = "1.0"
Test-Endpoint "GET" "$baseUrl/api/versioned" -Headers $V1Headers -Description "Versioning V1 (Header)"

$V2Headers = $GlobalHeaders.Clone()
$V2Headers["X-Version"] = "2.0"
Test-Endpoint "GET" "$baseUrl/api/versioned" -Headers $V2Headers -Description "Versioning V2 (Header)"

# 4. Error Cases
Test-Endpoint "GET" "$baseUrl/api/versioned?api-version=9.0" -Headers $GlobalHeaders -ExpectedStatus 404 -Description "Invalid Version (9.0)"

Write-Host "`n[DONE] Test Suite Completed!" -ForegroundColor Green
