### Tests for DextFood API (PowerShell Version)
$HostUrl = "http://localhost:9000"

Write-Host "`n[TEST] Testing DextFood API..." -ForegroundColor Cyan
Write-Host "================================`n"

# Helper function to print response
function Show-Response($Name, $Response) {
    Write-Host "   [PASS] $Name" -ForegroundColor Green
    $Response | ConvertTo-Json -Depth 10 | Write-Host
    Write-Host "--------------------------------"
}

# 1. Health Check
try {
    $Response = Invoke-RestMethod -Uri "$HostUrl/health" -Method Get -ErrorAction Stop
    Show-Response "Health Check" $Response
}
catch {
    Write-Host "   [FAIL] Health Check Failed: $_" -ForegroundColor Red
}

# 2. Create Order
try {
    $Response = Invoke-RestMethod -Uri "$HostUrl/api/orders?total=150.00" -Method Post -ErrorAction Stop
    Show-Response "Create Order" $Response
}
catch {
    if ($_.Exception.Response.StatusCode -eq 404) {
        Write-Host "   [WARN] Create Order (Post): Endpoint not found (404)" -ForegroundColor Yellow
    }
    else {
        Write-Host "   [FAIL] Create Order Failed: $_" -ForegroundColor Red
    }
}

# 3. Get High Value Orders
try {
    $Orders = Invoke-RestMethod -Uri "$HostUrl/api/orders/high-value" -Method Get
    Show-Response "High Value Orders" $Orders
}
catch {
    Write-Host "   [FAIL] Get High Value Orders Failed: $_" -ForegroundColor Red
}

# 4. Get Super Orders (The one with the issue)
Write-Host "[TEST] Testing Super Orders (Debugging Serializer)..." -ForegroundColor Cyan
try {
    $SuperOrders = Invoke-RestMethod -Uri "$HostUrl/api/super-orders" -Method Get
    Show-Response "Super Orders Body" $SuperOrders
}
catch {
    Write-Host "   [FAIL] Get Super Orders Failed: $_" -ForegroundColor Red
}

Write-Host "`n* All tests completed." -ForegroundColor Green
