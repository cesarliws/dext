# Smart Properties Demo Test Script
# Tests Smart Properties query and Model Binding

$ErrorActionPreference = "Stop"
$baseUrl = "http://localhost:5000"

Write-Host "Testing Web.SmartPropsDemo" -ForegroundColor Cyan
Write-Host "==========================" -ForegroundColor Cyan
Write-Host ""

function Invoke-DextRequest {
    param (
        [string]$Uri,
        [string]$Method = "GET",
        [string]$Body = $null
    )
    # Print Request Info
    Write-Host "   [REQUEST]: $Method $Uri" -ForegroundColor Gray
    if ($Body) { Write-Host "   [BODY]: $Body" -ForegroundColor Gray }
    
    try {
        $params = @{
            Uri             = $Uri
            Method          = $Method
            UseBasicParsing = $true
            ContentType     = "application/json"
        }
        if ($Body) { $params.Body = $Body }
        
        $resp = Invoke-WebRequest @params
        
        # Print Response Info
        Write-Host "   [RESPONSE]: $($resp.StatusCode)" -ForegroundColor Gray
        $content = $resp.Content
        Write-Host "   [CONTENT]: $content" -ForegroundColor Gray
        
        try { return ($content | ConvertFrom-Json) } catch { return $content }
    }
    catch {
        $resp = $_.Exception.Response
        if ($resp) {
            $errBody = ""
            if ($resp.Content -and ($resp.Content.PSObject.Methods.Name -contains "ReadAsStringAsync")) {
                $errBody = $resp.Content.ReadAsStringAsync().GetAwaiter().GetResult()
            }
            elseif ($resp.PSObject.Methods.Name -contains "GetResponseStream") {
                $reader = New-Object System.IO.StreamReader($resp.GetResponseStream())
                $errBody = $reader.ReadToEnd()
            }
            Write-Host "   [ERROR BODY]: $errBody" -ForegroundColor Red
        }
        throw "Request to $Uri failed: $($_.Exception.Message)"
    }
}

try {
    #                                                                            
    # TEST 1: List products (Smart Property filter: Price > 100)
    #                                                                            
    Write-Host "1. GET /products" -ForegroundColor Yellow
    Write-Host "   Testing Smart Property query: Price > 100..."
    $products = Invoke-DextRequest "$baseUrl/products"
    
    # Should return Gaming Laptop (1999.99) and Discontinued Phone (499.00)
    # Should NOT return Wireless Mouse (29.99) because Price < 100
    if ($products.Count -lt 1) { throw "Expected at least 1 product with Price > 100" }
    Write-Host "   [OK] Found $($products.Count) product(s) with Price > 100" -ForegroundColor Green
    foreach ($p in $products) {
        Write-Host "   - $($p.Name): `$$($p.Price)"
    }
    Write-Host ""

    #                                                                            
    # TEST 2: Verify Smart Property filter excludes low-price items
    #                                                                            
    Write-Host "2. Verifying filter logic" -ForegroundColor Yellow
    $hasLowPrice = $products | Where-Object { $_.Price -le 100 }
    if ($hasLowPrice) { throw "Filter failed: found product with Price <= 100" }
    Write-Host "   [OK] No products with Price <= 100 in results" -ForegroundColor Green
    Write-Host ""

    #                                                                            
    # TEST 3: Create new product via Model Binding
    #                                                                            
    Write-Host "3. POST /products" -ForegroundColor Yellow
    Write-Host "   Testing Model Binding: JSON body -> TProduct entity..."
    $newProduct = @{
        Name     = "Smart Watch"
        Price    = 299.99
        IsActive = $true
    } | ConvertTo-Json
    $created = Invoke-DextRequest "$baseUrl/products" "POST" $newProduct
    if (-not $created.Id) { throw "Expected 'Id' in created product" }
    Write-Host "   [OK] Created with ID: $($created.Id)" -ForegroundColor Green
    Write-Host "   Name: $($created.Name), Price: $($created.Price)"
    Write-Host ""

    #                                                                            
    # TEST 4: Verify new product appears in list (Price > 100)
    #                                                                            
    Write-Host "4. GET /products (verify new product)" -ForegroundColor Yellow
    $updatedList = Invoke-DextRequest "$baseUrl/products"
    $found = $updatedList | Where-Object { $_.Name -eq "Smart Watch" }
    if (-not $found) { throw "New product 'Smart Watch' not found in list" }
    Write-Host "   [OK] 'Smart Watch' found in filtered results" -ForegroundColor Green
    Write-Host ""

    #                                                                            
    # TEST 5: Create low-price product (should NOT appear in filtered list)
    #                                                                            
    Write-Host "5. POST /products (low price)" -ForegroundColor Yellow
    Write-Host "   Creating product with Price < 100 (should be filtered out)..."
    $lowPriceProduct = @{
        Name     = "USB Cable"
        Price    = 9.99
        IsActive = $true
    } | ConvertTo-Json
    $lowCreated = Invoke-DextRequest "$baseUrl/products" "POST" $lowPriceProduct
    Write-Host "   [OK] Created 'USB Cable' with ID: $($lowCreated.Id)" -ForegroundColor Green
    Write-Host ""

    #                                                                            
    # TEST 6: Verify low-price product is filtered out
    #                                                                            
    Write-Host "6. GET /products (verify filter excludes low price)" -ForegroundColor Yellow
    $finalList = Invoke-DextRequest "$baseUrl/products"
    $foundLow = $finalList | Where-Object { $_.Name -eq "USB Cable" }
    if ($foundLow) { throw "Filter failed: 'USB Cable' should not appear (Price < 100)" }
    Write-Host "   [OK] 'USB Cable' correctly excluded from results" -ForegroundColor Green
    Write-Host ""

    #                                                                            
    Write-Host "==========================================" -ForegroundColor Green
    Write-Host "SUCCESS: ALL SMART PROPERTIES TESTS PASSED!" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Green
}
catch {
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Red
    Write-Host "TEST FAILED: $_" -ForegroundColor Red
    Write-Host "==========================================" -ForegroundColor Red
    exit 1
}
