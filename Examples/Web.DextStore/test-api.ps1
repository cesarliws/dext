# DextStore API Test Script
# Tests all endpoints of the DextStore API

$baseUrl = "http://localhost:9000"
$token = ""

Write-Host "[TEST] DextStore API Test Suite" -ForegroundColor Cyan
Write-Host "================================`n" -ForegroundColor Cyan

# Test 1: Health Check
Write-Host "1. Testing Health Check..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "$baseUrl/health" -Method Get
    Write-Host "[OK] Health Check: " -ForegroundColor Green -NoNewline
    Write-Host ($response | ConvertTo-Json -Compress)
}
catch {
    Write-Host "[ERROR] Health Check Failed: $_" -ForegroundColor Red
}

Write-Host ""

# Test 2: Login
Write-Host "2. Testing Login..." -ForegroundColor Yellow
try {
    $loginBody = @{
        username = "user"
        password = "password"
    } | ConvertTo-Json

    $response = Invoke-RestMethod -Uri "$baseUrl/api/auth/login" `
        -Method Post `
        -ContentType "application/json" `
        -Body $loginBody
    
    $token = $response.token
    Write-Host "[OK] Login Successful!" -ForegroundColor Green
    Write-Host "   Token: $($token.Substring(0, 20))..." -ForegroundColor Gray
}
catch {
    Write-Host "[ERROR] Login Failed: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Test 3: Get All Products
Write-Host "3. Testing Get All Products..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "$baseUrl/api/products/" -Method Get
    Write-Host "[OK] Products Retrieved: $($response.Count) items" -ForegroundColor Green
    $response | ForEach-Object {
        Write-Host "   - $($_.Name): `$$($_.Price)" -ForegroundColor Gray
    }
}
catch {
    Write-Host "[ERROR] Get Products Failed: $_" -ForegroundColor Red
}

Write-Host ""

# Test 4: Get Product by ID
Write-Host "4. Testing Get Product by ID..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "$baseUrl/api/products/1" -Method Get
    Write-Host "[OK] Product Retrieved: $($response.Name)" -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] Get Product by ID Failed: $_" -ForegroundColor Red
}

Write-Host ""

# Test 5: Create Product (Requires Admin/Auth - Testing logic)
Write-Host "5. Testing Create Product..." -ForegroundColor Yellow
try {
    $productBody = @{
        name        = "New Gaming Headset"
        description = "Surround sound"
        price       = 199.99
        sku         = "GM-HEAD-001"
        stock       = 10
        category    = "Hardware"
    } | ConvertTo-Json

    $headers = @{
        "Authorization" = "Bearer $token"
        "Content-Type"  = "application/json"
    }

    $response = Invoke-RestMethod -Uri "$baseUrl/api/products/" `
        -Method Post `
        -Headers $headers `
        -Body $productBody
    
    Write-Host "[OK] Product Created!" -ForegroundColor Green
    Write-Host "   ID: $($response.id)" -ForegroundColor Gray
    Write-Host "   Name: $($response.name)" -ForegroundColor Gray
}
catch {
    Write-Host "[ERROR] Create Product Failed: $_" -ForegroundColor Red
}

Write-Host ""

# Test 6: Add Item to Cart
Write-Host "6. Testing Add Item to Cart..." -ForegroundColor Yellow
try {
    $cartBody = @{
        productId = 1
        quantity  = 2
    } | ConvertTo-Json

    $headers = @{
        "Authorization" = "Bearer $token"
        "Content-Type"  = "application/json"
    }

    $response = Invoke-RestMethod -Uri "$baseUrl/api/cart/items" `
        -Method Post `
        -Headers $headers `
        -Body $cartBody
    
    Write-Host "[OK] Item Added to Cart!" -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] Add to Cart Failed: $_" -ForegroundColor Red
}

Write-Host ""

# Test 7: Get Cart
Write-Host "7. Testing Get Cart..." -ForegroundColor Yellow
try {
    # Headers without Content-Type for GET
    $headers = @{
        "Authorization" = "Bearer $token"
    }

    $response = Invoke-RestMethod -Uri "$baseUrl/api/cart/" `
        -Method Get `
        -Headers $headers
    
    Write-Host "[OK] Cart Retrieved!" -ForegroundColor Green
    Write-Host "   User: $($response.userId)" -ForegroundColor Gray
    Write-Host "   Total: `$$($response.totalAmount)" -ForegroundColor Gray
    Write-Host "   Items: $($response.items.Count)" -ForegroundColor Gray
}
catch {
    Write-Host "[ERROR] Get Cart Failed: $_" -ForegroundColor Red
}

Write-Host ""

# Test 8: Checkout
Write-Host "8. Testing Checkout..." -ForegroundColor Yellow
try {
    $headers = @{
        "Authorization" = "Bearer $token"
        "Content-Type"  = "application/json"
    }
    
    # Note: Checkout is POST, so Content-Type is fine, but body is optional?
    # Controller doesn't bind body for Checkout, so we can send empty/null.
    # Invoke-RestMethod with POST usually expects body or might send 0-length.

    $response = Invoke-RestMethod -Uri "$baseUrl/api/orders/checkout" `
        -Method Post `
        -Headers $headers
    
    Write-Host "[OK] Order Placed!" -ForegroundColor Green
    Write-Host "   Order ID: $($response.orderId)" -ForegroundColor Gray
    Write-Host "   Total: `$$($response.total)" -ForegroundColor Gray
    Write-Host "   Status: $($response.status)" -ForegroundColor Gray
}
catch {
    Write-Host "[ERROR] Checkout Failed: $_" -ForegroundColor Red
}

Write-Host ""

# Test 9: Get Orders
Write-Host "9. Testing Get Orders..." -ForegroundColor Yellow
try {
    $headers = @{
        "Authorization" = "Bearer $token"
    }

    $response = Invoke-RestMethod -Uri "$baseUrl/api/orders/" `
        -Method Get `
        -Headers $headers
    
    Write-Host "[OK] Orders Retrieved: $($response.Count) orders" -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] Get Orders Failed: $_" -ForegroundColor Red
}

Write-Host ""

# Test 10: Clear Cart (Cleanup)
Write-Host "10. Testing Clear Cart..." -ForegroundColor Yellow
try {
    # Headers WITHOUT Content-Type for DELETE
    $headers = @{
        "Authorization" = "Bearer $token"
    }

    # Add item first so there is something to clear
    $cartBody = @{ productId = 2; quantity = 1 } | ConvertTo-Json
    
    # Headers WITH Content-Type for POST
    $postHeaders = @{
        "Authorization" = "Bearer $token"
        "Content-Type"  = "application/json"
    }
    
    Invoke-RestMethod -Uri "$baseUrl/api/cart/items" -Method Post -Headers $postHeaders -Body $cartBody -ErrorAction SilentlyContinue

    Invoke-RestMethod -Uri "$baseUrl/api/cart/" `
        -Method Delete `
        -Headers $headers
    
    Write-Host "[OK] Cart Cleared!" -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] Clear Cart Failed: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "================================" -ForegroundColor Cyan
Write-Host "[DONE] Test Suite Completed!" -ForegroundColor Green
