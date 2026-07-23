# Test Script for Dext.Examples.MultiTenancy

$BaseUrl = "http://localhost:8080"

Write-Host "[*] Starting Multi-Tenancy Demo Tests..." -ForegroundColor Cyan

try {
    # 1. Create a Tenant
    Write-Host "[1] Creating tenant..." -NoNewline
    $TenantResponse = Invoke-RestMethod -Uri "$BaseUrl/api/tenants" -Method Post -ContentType "application/json" -Body '{"name": "Acme Corp", "subdomain": "acme"}'
    $TenantId = $TenantResponse.id
    Write-Host " OK (ID: $TenantId)" -ForegroundColor Green

    # 2. List Tenants
    Write-Host "[2] Listing tenants..." -NoNewline
    $Tenants = Invoke-RestMethod -Uri "$BaseUrl/api/tenants" -Method Get
    Write-Host " OK ($($Tenants.Count) tenant(s))" -ForegroundColor Green

    # 3. Get Tenant by ID
    Write-Host "[3] Getting tenant by ID..." -NoNewline
    $Tenant = Invoke-RestMethod -Uri "$BaseUrl/api/tenants/$TenantId" -Method Get
    Write-Host " OK (Name: $($Tenant.name))" -ForegroundColor Green

    # 4. Create Product (requires X-Tenant-Id)
    Write-Host "[4] Creating product for tenant..." -NoNewline
    $Headers = @{ "X-Tenant-Id" = $TenantId }
    $ProductResponse = Invoke-RestMethod -Uri "$BaseUrl/api/products" -Method Post -ContentType "application/json" -Headers $Headers -Body '{"name": "Widget Pro", "description": "Professional widget", "price": 99.99, "stock": 50}'
    Write-Host " OK" -ForegroundColor Green

    # 5. List Products for Tenant
    Write-Host "[5] Listing products for tenant..." -NoNewline
    $Products = Invoke-RestMethod -Uri "$BaseUrl/api/products" -Method Get -Headers $Headers
    Write-Host " OK ($($Products.Count) product(s))" -ForegroundColor Green

    # 6. Test without Tenant ID (should fail)
    Write-Host "[6] Testing without X-Tenant-Id (expect error)..." -NoNewline
    try {
        $ErrorResponse = Invoke-RestMethod -Uri "$BaseUrl/api/products" -Method Get
        Write-Host " UNEXPECTED SUCCESS" -ForegroundColor Red
    }
    catch {
        Write-Host " OK (correctly rejected)" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "[*] All tests passed successfully! [START]" -ForegroundColor Green


}
catch {
    Write-Host ""
    Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    
    if ($_.Exception.Response) {
        $Stream = $_.Exception.Response.GetResponseStream()
        if ($Stream) {
            $Reader = New-Object System.IO.StreamReader($Stream)
            $Content = $Reader.ReadToEnd()
            Write-Host "[RESPONSE BODY] $Content" -ForegroundColor Yellow
        }
    }
    exit 1
}
