# Test.Web.Dext.Charset.Thai.ps1
# This script tests UTF-8 charset support by creating records with non-ASCII characters.
# Using Unicode escapes to avoid PowerShell 5.1 encoding issues.

$baseUrl = "http://localhost:8080"

# Thai Name:                (Somchai)
$thaiName = "$([char]0x0E2A)$([char]0x0E21)$([char]0x0E0A)$([char]0x0E32)$([char]0x0E22) $([char]0x0E40)$([char]0x0E02)$([char]0x0E47)$([char]0x0E21)$([char]0x0E01)$([char]0x0E25)$([char]0x0E31)$([char]0x0E14) (Somchai)"
$thaiEmail = "somchai@thai-delphi.com"

Write-Host "--- Dext Framework Charset Support Test ---" -ForegroundColor Cyan

# 1. Login to get JWT Token
Write-Host "`n[1] Authenticating..."
$token = $null
try {
    $loginBody = @{
        username = "admin"
        password = "admin"
    } | ConvertTo-Json

    $loginResp = Invoke-RestMethod -Uri "$baseUrl/auth/login" -Method Post -Body $loginBody -ContentType "application/json"
    
    if ($loginResp.token) {
        $token = $loginResp.token
        Write-Host "PASS: Login successful." -ForegroundColor Green
    } else {
        Write-Host "FAIL: Login failed. No token." -ForegroundColor Red
        exit
    }
} catch {
    Write-Host "FAIL: Connection error. Is the server running at $baseUrl?" -ForegroundColor Red
    exit
}

# 2. Create Customer with Thai Characters
Write-Host "`n[2] Creating Customer with Thai Name..."

try {
    $customerBody = @{
        name = $thaiName
        email = $thaiEmail
        totalSpent = 1500.50
    } | ConvertTo-Json

    $headers = @{ 
        "Authorization" = "Bearer $token"
        "Accept" = "text/html" 
    }
    
    # Force UTF-8 bytes for the request body
    $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($customerBody)
    $resp = Invoke-WebRequest -Uri "$baseUrl/customers" -Method Post -Headers $headers -Body $bodyBytes -ContentType "application/json"
    
    $contentType = $resp.Headers["Content-Type"]
    Write-Host "Response Content-Type: $contentType"
    
    # Read response as UTF-8
    $body = [System.Text.Encoding]::UTF8.GetString($resp.RawContentStream.ToArray())
    
    if ($body -match "$([char]0x0E2A)$([char]0x0E21)$([char]0x0E0A)$([char]0x0E32)$([char]0x0E22)") {
        Write-Host "PASS: Thai characters preserved in response." -ForegroundColor Green
    } else {
        Write-Host "FAIL: Thai characters corrupted or missing in response." -ForegroundColor Red
    }
} catch {
    Write-Host "FAIL: Error creating customer. $_" -ForegroundColor Red
}

# 3. Verify in Customer List
Write-Host "`n[3] Verifying Thai characters in Customer List..."
try {
    $headers = @{ "Authorization" = "Bearer $token" }
    $listResp = Invoke-WebRequest -Uri "$baseUrl/customers" -Method Get -Headers $headers
    
    $listBody = [System.Text.Encoding]::UTF8.GetString($listResp.RawContentStream.ToArray())
    
    if ($listBody -match "$([char]0x0E2A)$([char]0x0E21)$([char]0x0E0A)$([char]0x0E32)$([char]0x0E22)") {
        Write-Host "PASS: Thai characters successfully retrieved from list." -ForegroundColor Green
    } else {
        Write-Host "FAIL: Thai characters corrupted in list." -ForegroundColor Red
    }
} catch {
    Write-Host "FAIL: Error fetching customer list. $_" -ForegroundColor Red
}

Write-Host "`nCharset Tests Completed." -ForegroundColor Cyan
