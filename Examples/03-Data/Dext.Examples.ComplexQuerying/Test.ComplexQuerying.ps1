# Test Script for Dext.Examples.ComplexQuerying

$BaseUrl = "http://localhost:8080"

Write-Host "[*] Starting Complex Querying Demo Tests..." -ForegroundColor Cyan

try {
    # 1. Seed sample data
    Write-Host "[1] Seeding sample data..." -NoNewline
    $SeedResponse = Invoke-RestMethod -Uri "$BaseUrl/api/seed" -Method Post
    Write-Host " OK" -ForegroundColor Green

    # 2. List all orders
    Write-Host "[2] Listing all orders..." -NoNewline
    $Orders = Invoke-RestMethod -Uri "$BaseUrl/api/orders" -Method Get
    Write-Host " OK ($($Orders.Count) orders)" -ForegroundColor Green

    # 3. Get order by ID
    Write-Host "[3] Getting order by ID..." -NoNewline
    $Order = Invoke-RestMethod -Uri "$BaseUrl/api/orders/1" -Method Get
    Write-Host " OK" -ForegroundColor Green
    Write-Host "    -> Order Details: $($Order | ConvertTo-Json -Depth 2 -Compress)" -ForegroundColor Gray

    # 4. Filter by status
    Write-Host "[4] Filtering by status (pending)..." -NoNewline
    $PendingOrders = Invoke-RestMethod -Uri "$BaseUrl/api/orders/status/pending" -Method Get
    Write-Host " OK ($($PendingOrders.Count) pending)" -ForegroundColor Green

    # 5. Sales report
    Write-Host "[5] Getting sales report..." -NoNewline
    $SalesReport = Invoke-RestMethod -Uri "$BaseUrl/api/reports/sales" -Method Get
    Write-Host " OK ($($SalesReport.Count) status groups)" -ForegroundColor Green

    # 6. Top customers
    Write-Host "[6] Getting top customers..." -NoNewline
    $TopCustomers = Invoke-RestMethod -Uri "$BaseUrl/api/reports/top-customers?top=3" -Method Get
    Write-Host " OK ($($TopCustomers.Count) customers)" -ForegroundColor Green
    $TopCustomers | ForEach-Object {
        Write-Host "    - $($_.customerName): $($_.totalSpent)" -ForegroundColor DarkGray
    }

    # 7. Advanced search
    Write-Host "[7] Testing advanced search..." -NoNewline
    $SearchResponse = Invoke-RestMethod -Uri "$BaseUrl/api/orders/search" -Method Post -ContentType "application/json" -Body '{"minAmount": 500}'
    Write-Host " OK ($($SearchResponse.Count) matching orders)" -ForegroundColor Green
    Write-Host "    Result JSON:"
    Write-Host ($SearchResponse | ConvertTo-Json -Depth 3) -ForegroundColor Cyan

    Write-Host ""
    Write-Host "[*] All tests passed successfully! [START]" -ForegroundColor Green

}
catch {
    Write-Host ""
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
