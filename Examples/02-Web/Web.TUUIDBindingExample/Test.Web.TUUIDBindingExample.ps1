# TUUID Binding Example Test Script
# Tests all 6 endpoints demonstrating TUUID features

$ErrorActionPreference = "Stop"
$baseUrl = "http://localhost:8080"

Write-Host "Testing Web.TUUIDBindingExample" -ForegroundColor Cyan
Write-Host "===============================" -ForegroundColor Cyan
Write-Host ""

function Invoke-DextRequest {
    param (
        [string]$Uri,
        [string]$Method = "GET",
        [string]$Body = $null
    )
    try {
        $params = @{
            Uri             = $Uri
            Method          = $Method
            UseBasicParsing = $true
            ContentType     = "application/json"
        }
        if ($Body) { $params.Body = $Body }
        
        $resp = Invoke-WebRequest @params
        try { return ($resp.Content | ConvertFrom-Json) } catch { return $resp.Content }
    }
    catch {
        if ($_.Exception.Response.StatusCode -eq 400) {
            return @{ error = "BadRequest"; statusCode = 400 }
        }
        throw "Request to $Uri failed: $($_.Exception.Message)"
    }
}

try {
    #                                                                            
    # TEST 1: Generate UUID v7
    #                                                                            
    Write-Host "1. POST /api/products/generate-v7" -ForegroundColor Yellow
    Write-Host "   Testing UUID v7 generation..."
    $gen = Invoke-DextRequest "$baseUrl/api/products/generate-v7" "POST"
    Write-Host "   [OK] Generated: $($gen.id)" -ForegroundColor Green
    Write-Host "   Name: $($gen.name), Price: $($gen.price)"
    $uuid = $gen.id
    Write-Host ""

    #                                                                            
    # TEST 2: Get by ID (Manual Parsing)
    #                                                                            
    Write-Host "2. GET /api/products/{id} [MANUAL]" -ForegroundColor Yellow
    Write-Host "   Fetching by UUID: $uuid"
    $get = Invoke-DextRequest "$baseUrl/api/products/$uuid"
    if ($get.id -ne $uuid) { throw "ID mismatch in response" }
    Write-Host "   [OK] Found: $($get.name)" -ForegroundColor Green
    Write-Host ""

    #                                                                            
    # TEST 3: Get by ID (Auto-Bound TUUID)
    #                                                                            
    Write-Host "3. GET /api/products/lookup/{id} [AUTO-BOUND]" -ForegroundColor Yellow
    Write-Host "   Testing automatic TUUID binding..."
    $lookup = Invoke-DextRequest "$baseUrl/api/products/lookup/$uuid"
    if ($lookup.id -ne $uuid) { throw "ID mismatch in auto-bound response" }
    Write-Host "   [OK] Found: $($lookup.name)" -ForegroundColor Green
    Write-Host "   Price: $($lookup.price)"
    Write-Host ""

    #                                                                            
    # TEST 4: Create with TUUID in body
    #                                                                            
    Write-Host "4. POST /api/products [BODY BINDING]" -ForegroundColor Yellow
    $newUuid = [guid]::NewGuid().ToString()
    Write-Host "   Creating product with UUID: $newUuid"
    $body = @{ id = $newUuid; name = "Test Product"; price = 59.99 } | ConvertTo-Json
    $created = Invoke-DextRequest "$baseUrl/api/products" "POST" $body
    if ($created.id -ne $newUuid) { throw "Created ID mismatch" }
    Write-Host "   [OK] Created: $($created.name)" -ForegroundColor Green
    Write-Host "   ID: $($created.id)"
    Write-Host ""

    #                                                                            
    # TEST 5: Update with matching IDs
    #                                                                            
    Write-Host "5. PUT /api/products/{id} [MATCHING IDs]" -ForegroundColor Yellow
    Write-Host "   Updating product: $newUuid"
    $updateBody = @{ id = $newUuid; name = "Updated Product"; price = 79.99 } | ConvertTo-Json
    $updated = Invoke-DextRequest "$baseUrl/api/products/$newUuid" "PUT" $updateBody
    if ($updated.name -ne "Updated Product") { throw "Update failed" }
    Write-Host "   [OK] Updated: $($updated.name)" -ForegroundColor Green
    Write-Host "   New Price: $($updated.price)"
    Write-Host ""

    #                                                                            
    # TEST 6: Update with MISMATCHED IDs (expect 400)
    #                                                                            
    Write-Host "6. PUT /api/products/{id} [MISMATCHED IDs]" -ForegroundColor Yellow
    $wrongUuid = [guid]::NewGuid().ToString()
    Write-Host "   URL ID: $newUuid"
    Write-Host "   Body ID: $wrongUuid (different!)"
    $mismatchBody = @{ id = $wrongUuid; name = "Wrong"; price = 0 } | ConvertTo-Json
    $mismatch = Invoke-DextRequest "$baseUrl/api/products/$newUuid" "PUT" $mismatchBody
    if ($mismatch.statusCode -ne 400) { throw "Expected 400 for ID mismatch" }
    Write-Host "   [OK] Correctly rejected with 400 Bad Request" -ForegroundColor Green
    Write-Host ""

    #                                                                            
    # TEST 7: UUID format parsing (no hyphens)
    #                                                                            
    Write-Host "7. GET /api/uuid/formats/{id} [FORMAT TEST]" -ForegroundColor Yellow
    $cleanUuid = $uuid -replace "-", ""
    Write-Host "   Input (no hyphens): $cleanUuid"
    $fmt = Invoke-DextRequest "$baseUrl/api/uuid/formats/$cleanUuid"
    if ($fmt.canonical -ne $uuid) { throw "Canonical format mismatch" }
    Write-Host "   [OK] Canonical: $($fmt.canonical)" -ForegroundColor Green
    Write-Host "   With braces: $($fmt.withBraces)"
    Write-Host ""

    #                                                                            
    # TEST 8: UUID format parsing (with braces)
    #                                                                            
    Write-Host "8. GET /api/uuid/formats/{id} [BRACED FORMAT]" -ForegroundColor Yellow
    $bracedUuid = "{$uuid}"
    Write-Host "   Input (with braces): $bracedUuid"
    $fmt2 = Invoke-DextRequest "$baseUrl/api/uuid/formats/$bracedUuid"
    if ($fmt2.canonical -ne $uuid) { throw "Braced format mismatch" }
    Write-Host "   [OK] Parsed correctly" -ForegroundColor Green
    Write-Host ""

    #                                                                            
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "SUCCESS: ALL TUUID BINDING TESTS PASSED!" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Green
}
catch {
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Red
    Write-Host "TEST FAILED: $_" -ForegroundColor Red
    Write-Host "==========================================" -ForegroundColor Red
    exit 1
}
