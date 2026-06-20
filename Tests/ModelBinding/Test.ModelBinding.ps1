# Test.ModelBinding.ps1
# Comprehensive Model Binding Tests for Dext Framework
# Tests: Body, Header, Query, Route, and Mixed binding scenarios
# Covers both Minimal API and Controller endpoints

$ErrorActionPreference = "Stop"
$BaseUrl = "http://localhost:8080"

# Test counters
$TestsPassed = 0
$TestsFailed = 0
$TestResults = @()

function Write-TestHeader {
    param([string]$TestNumber, [string]$Description)
    Write-Host ""
    Write-Host "[$TestNumber] $Description" -ForegroundColor Cyan
}

function Test-Endpoint {
    param(
        [string]$Name,
        [string]$Method,
        [string]$Url,
        [hashtable]$Headers = @{},
        [string]$Body = $null,
        [scriptblock]$Validate
    )
    
    try {
        $params = @{
            Uri         = $Url
            Method      = $Method
            ContentType = "application/json"
        }
        
        if ($Headers.Count -gt 0) {
            $params.Headers = $Headers
        }
        
        if ($Body) {
            $params.Body = $Body
        }
        
        $response = Invoke-RestMethod @params
        $result = & $Validate $response
        
        if ($result) {
            Write-Host "    PASS: $Name" -ForegroundColor Green
            $script:TestsPassed++
            $script:TestResults += [PSCustomObject]@{Test = $Name; Status = "PASS"; Error = $null }
        }
        else {
            Write-Host "    FAIL: $Name - Validation failed" -ForegroundColor Red
            Write-Host "    Response: $($response | ConvertTo-Json -Compress)" -ForegroundColor Yellow
            $script:TestsFailed++
            $script:TestResults += [PSCustomObject]@{Test = $Name; Status = "FAIL"; Error = "Validation failed" }
        }
    }
    catch {
        Write-Host "    FAIL: $Name - $($_.Exception.Message)" -ForegroundColor Red
        $script:TestsFailed++
        $script:TestResults += [PSCustomObject]@{Test = $Name; Status = "FAIL"; Error = $_.Exception.Message }
    }
}

function Test-ExpectError {
    param(
        [string]$Name,
        [string]$Method,
        [string]$Url,
        [hashtable]$Headers = @{},
        [string]$Body = $null,
        [int]$ExpectedStatus = 400
    )
    
    try {
        $params = @{
            Uri         = $Url
            Method      = $Method
            ContentType = "application/json"
        }
        
        if ($Headers.Count -gt 0) {
            $params.Headers = $Headers
        }
        
        if ($Body) {
            $params.Body = $Body
        }
        
        $response = Invoke-RestMethod @params
        Write-Host "    FAIL: $Name - Expected error but got success" -ForegroundColor Red
        $script:TestsFailed++
        $script:TestResults += [PSCustomObject]@{Test = $Name; Status = "FAIL"; Error = "Expected error" }
    }
    catch {
        if ($_.Exception.Response.StatusCode.value__ -eq $ExpectedStatus) {
            Write-Host "    PASS: $Name (correctly returned $ExpectedStatus)" -ForegroundColor Green
            $script:TestsPassed++
            $script:TestResults += [PSCustomObject]@{Test = $Name; Status = "PASS"; Error = $null }
        }
        else {
            Write-Host "    FAIL: $Name - Expected $ExpectedStatus but got $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
            $script:TestsFailed++
            $script:TestResults += [PSCustomObject]@{Test = $Name; Status = "FAIL"; Error = "Wrong status code" }
        }
    }
}

# =============================================================================
# TESTS START
# =============================================================================

Write-Host "============================================================" -ForegroundColor White
Write-Host "  Dext Model Binding - Comprehensive Test Suite" -ForegroundColor White
Write-Host "  Testing: Minimal API + Controllers" -ForegroundColor White
Write-Host "============================================================" -ForegroundColor White
Write-Host ""
Write-Host "Target: $BaseUrl" -ForegroundColor Gray

# =============================================================================
# MINIMAL API TESTS
# =============================================================================

Write-Host ""
Write-Host "========== MINIMAL API TESTS ==========" -ForegroundColor Magenta

# -----------------------------------------------------------------------------
# TEST 1: Pure Body Binding
# -----------------------------------------------------------------------------
Write-TestHeader "1" "Pure Body Binding (JSON)"

Test-Endpoint -Name "Body: All fields from JSON" `
    -Method "POST" `
    -Url "$BaseUrl/test/body-only" `
    -Body '{"name": "John Doe", "email": "john@example.com", "age": 30, "active": true, "balance": 1500.50}' `
    -Validate {
    param($r)
    $r.name -eq "John Doe" -and $r.email -eq "john@example.com" -and 
    $r.age -eq 30 -and $r.active -eq $true -and $r.balance -gt 1500
}

Test-Endpoint -Name "Body: camelCase to PascalCase mapping" `
    -Method "POST" `
    -Url "$BaseUrl/test/body-only" `
    -Body '{"Name": "Jane", "Email": "jane@test.com", "Age": 25, "Active": false, "Balance": 0}' `
    -Validate {
    param($r)
    $r.name -eq "Jane" -and $r.age -eq 25 -and $r.active -eq $false
}

# -----------------------------------------------------------------------------
# TEST 2: Header Only Binding
# -----------------------------------------------------------------------------
Write-TestHeader "2" "Header Only Binding"

Test-Endpoint -Name "Header: X-Tenant-Id and Authorization" `
    -Method "GET" `
    -Url "$BaseUrl/test/header-only" `
    -Headers @{ "X-Tenant-Id" = "tenant-123"; "Authorization" = "Bearer secret-token-xyz" } `
    -Validate {
    param($r)
    $r.tenantId -eq "tenant-123" -and $r.hasToken -eq $true
}

Test-Endpoint -Name "Header: Only X-Tenant-Id (no token)" `
    -Method "GET" `
    -Url "$BaseUrl/test/header-only" `
    -Headers @{ "X-Tenant-Id" = "tenant-456" } `
    -Validate {
    param($r)
    $r.tenantId -eq "tenant-456" -and $r.hasToken -eq $false
}

# -----------------------------------------------------------------------------
# TEST 3: Query Only Binding
# -----------------------------------------------------------------------------
Write-TestHeader "3" "Query Parameter Binding"

Test-Endpoint -Name "Query: All parameters" `
    -Method "GET" `
    -Url "$BaseUrl/test/query-only?q=delphi&page=2&limit=50" `
    -Validate {
    param($r)
    $r.query -eq "delphi" -and $r.page -eq 2 -and $r.limit -eq 50
}

Test-Endpoint -Name "Query: Partial parameters (defaults)" `
    -Method "GET" `
    -Url "$BaseUrl/test/query-only?q=search" `
    -Validate {
    param($r)
    $r.query -eq "search" -and $r.page -eq 0 -and $r.limit -eq 0
}

Test-Endpoint -Name "Query: URL encoded value" `
    -Method "GET" `
    -Url "$BaseUrl/test/query-only?q=hello%20world&page=1&limit=10" `
    -Validate {
    param($r)
    $r.query -eq "hello world"
}

# -----------------------------------------------------------------------------
# TEST 4: Route Only Binding
# -----------------------------------------------------------------------------
Write-TestHeader "4" "Route Parameter Binding"

Test-Endpoint -Name "Route: Integer and String params" `
    -Method "GET" `
    -Url "$BaseUrl/test/route-only/42/electronics" `
    -Validate {
    param($r)
    $r.id -eq 42 -and $r.category -eq "electronics"
}

Test-Endpoint -Name "Route: Large ID" `
    -Method "GET" `
    -Url "$BaseUrl/test/route-only/999999/books" `
    -Validate {
    param($r)
    $r.id -eq 999999 -and $r.category -eq "books"
}

# -----------------------------------------------------------------------------
# TEST 5: Mixed - Header + Body (Multi-Tenancy Use Case)
# -----------------------------------------------------------------------------
Write-TestHeader "5" "Mixed: Header + Body (Multi-Tenancy)"

Test-Endpoint -Name "Mixed: TenantId from header, data from body" `
    -Method "POST" `
    -Url "$BaseUrl/test/header-body" `
    -Headers @{ "X-Tenant-Id" = "acme-corp" } `
    -Body '{"name": "Widget Pro", "description": "Professional widget", "price": 99.99, "stock": 100}' `
    -Validate {
    param($r)
    $r.tenantId -eq "acme-corp" -and $r.name -eq "Widget Pro" -and 
    $r.price -gt 99 -and $r.stock -eq 100
}

Test-ExpectError -Name "Mixed: Missing required header should fail" `
    -Method "POST" `
    -Url "$BaseUrl/test/header-body" `
    -Body '{"name": "Test", "description": "Test", "price": 10, "stock": 5}' `
    -ExpectedStatus 400

# -----------------------------------------------------------------------------
# TEST 6: Mixed - Route + Body
# -----------------------------------------------------------------------------
Write-TestHeader "6" "Mixed: Route + Body"

Test-Endpoint -Name "Route+Body: Id from route, data from body" `
    -Method "PUT" `
    -Url "$BaseUrl/test/route-body/123" `
    -Body '{"name": "Updated Product", "price": 149.99}' `
    -Validate {
    param($r)
    $r.id -eq 123 -and $r.name -eq "Updated Product" -and $r.price -gt 149
}

# -----------------------------------------------------------------------------
# TEST 7: Mixed - Route + Query
# -----------------------------------------------------------------------------
Write-TestHeader "7" "Mixed: Route + Query"

Test-Endpoint -Name "Route+Query: Category from route, sort/page from query" `
    -Method "GET" `
    -Url "$BaseUrl/test/route-query/clothing?sort=price_asc&page=3" `
    -Validate {
    param($r)
    $r.category -eq "clothing" -and $r.sort -eq "price_asc" -and $r.page -eq 3
}

# -----------------------------------------------------------------------------
# TEST 8: Complex Mixed - Header + Route + Body
# -----------------------------------------------------------------------------
Write-TestHeader "8" "Complex: Header + Route + Body"

Test-Endpoint -Name "Multi-source: All three sources" `
    -Method "PUT" `
    -Url "$BaseUrl/test/multi-source/456" `
    -Headers @{ "X-Tenant-Id" = "tenant-xyz"; "X-Correlation-Id" = "corr-789" } `
    -Body '{"name": "Complex Item", "value": 1234.56}' `
    -Validate {
    param($r)
    $r.tenantId -eq "tenant-xyz" -and $r.correlationId -eq "corr-789" -and 
    $r.id -eq 456 -and $r.name -eq "Complex Item" -and $r.value -gt 1234
}

# -----------------------------------------------------------------------------
# TEST 9: All Sources Combined
# -----------------------------------------------------------------------------
Write-TestHeader "9" "Full: Header + Route + Query + Body"

Test-Endpoint -Name "All sources: Header, Route, Query, Body" `
    -Method "PUT" `
    -Url "$BaseUrl/test/full/789?include=details" `
    -Headers @{ "X-Api-Key" = "my-api-key-123" } `
    -Body '{"data": "Test data content", "count": 42}' `
    -Validate {
    param($r)
    $r.apiKey -eq "my-api-key-123" -and $r.resourceId -eq 789 -and 
    $r.include -eq "details" -and $r.data -eq "Test data content" -and $r.count -eq 42
}

# -----------------------------------------------------------------------------
# TEST 10: Service Injection + Model Binding
# -----------------------------------------------------------------------------
Write-TestHeader "10" "Service Injection + Model Binding"

Test-Endpoint -Name "Service+Binding: Create with injected service" `
    -Method "POST" `
    -Url "$BaseUrl/test/service" `
    -Headers @{ "X-Tenant-Id" = "service-test" } `
    -Body '{"name": "New Product", "description": "Created via service", "price": 299.99, "stock": 50}' `
    -Validate {
    param($r)
    $r.tenantId -eq "service-test" -and $r.name -eq "New Product" -and $r.id -gt 0
}

# =============================================================================
# CONTROLLER TESTS
# =============================================================================

Write-Host ""
Write-Host "========== CONTROLLER TESTS ==========" -ForegroundColor Magenta

# -----------------------------------------------------------------------------
# TEST 11: Controller Header Binding
# -----------------------------------------------------------------------------
Write-TestHeader "11" "Controller: Header Binding"

Test-Endpoint -Name "Controller: X-Tenant-Id from header" `
    -Method "GET" `
    -Url "$BaseUrl/api/controller/header" `
    -Headers @{ "X-Tenant-Id" = "controller-tenant" } `
    -Validate {
    param($r)
    $r.source -eq "controller-header" -and $r.tenantId -eq "controller-tenant"
}

# -----------------------------------------------------------------------------
# TEST 12: Controller Query Binding
# -----------------------------------------------------------------------------
Write-TestHeader "12" "Controller: Query Binding"

Test-Endpoint -Name "Controller: Query parameters" `
    -Method "GET" `
    -Url "$BaseUrl/api/controller/query?q=controller-search&page=5" `
    -Validate {
    param($r)
    $r.source -eq "controller-query" -and $r.query -eq "controller-search" -and $r.page -eq 5
}

# -----------------------------------------------------------------------------
# TEST 13: Controller Body Binding
# -----------------------------------------------------------------------------
Write-TestHeader "13" "Controller: Body Binding"

Test-Endpoint -Name "Controller: JSON body" `
    -Method "POST" `
    -Url "$BaseUrl/api/controller/body" `
    -Body '{"name": "Controller User", "email": "ctrl@example.com"}' `
    -Validate {
    param($r)
    $r.source -eq "controller-body" -and $r.name -eq "Controller User" -and $r.email -eq "ctrl@example.com"
}

# -----------------------------------------------------------------------------
# TEST 14: Controller Mixed Binding (Header + Body)
# -----------------------------------------------------------------------------
Write-TestHeader "14" "Controller: Mixed (Header + Body)"

Test-Endpoint -Name "Controller: TenantId from header, data from body" `
    -Method "POST" `
    -Url "$BaseUrl/api/controller/mixed" `
    -Headers @{ "X-Tenant-Id" = "ctrl-tenant" } `
    -Body '{"name": "Controller Product", "price": 199.99}' `
    -Validate {
    param($r)
    $r.source -eq "controller-mixed" -and $r.tenantId -eq "ctrl-tenant" -and 
    $r.name -eq "Controller Product" -and $r.price -gt 199
}

Test-ExpectError -Name "Controller: Missing header should fail" `
    -Method "POST" `
    -Url "$BaseUrl/api/controller/mixed" `
    -Body '{"name": "No Tenant", "price": 10}' `
    -ExpectedStatus 400

# -----------------------------------------------------------------------------
# TEST 15: Controller Route + Query
# -----------------------------------------------------------------------------
Write-TestHeader "15" "Controller: Route + Query"

Test-Endpoint -Name "Controller: Id from route, details from query" `
    -Method "GET" `
    -Url "$BaseUrl/api/controller/route/999?details=full" `
    -Validate {
    param($r)
    $r.source -eq "controller-route" -and $r.id -eq 999 -and $r.details -eq "full"
}

# -----------------------------------------------------------------------------
# TEST 16: Controller Header Binding - UpperCase
# -----------------------------------------------------------------------------
Write-TestHeader "16" "Controller: Header Binding"

Test-Endpoint -Name "Controller: X-TENANT-ID from header - UpperCase" `
    -Method "GET" `
    -Url "$BaseUrl/api/controller/header" `
    -Headers @{ "X-TENANT-ID" = "controller-tenant" } `
    -Validate {
    param($r)
    $r.source -eq "controller-header" -and $r.tenantId -eq "controller-tenant"
}

# -----------------------------------------------------------------------------
# TEST 17: Controller Header Binding - LowerCase
# -----------------------------------------------------------------------------
Write-TestHeader "17" "Controller: Header Binding"

Test-Endpoint -Name "Controller: x-tenant-id from header - LowerCase" `
    -Method "GET" `
    -Url "$BaseUrl/api/controller/header" `
    -Headers @{ "x-tenant-id" = "controller-tenant" } `
    -Validate {
    param($r)
    $r.source -eq "controller-header" -and $r.tenantId -eq "controller-tenant"
}

# -----------------------------------------------------------------------------
# TEST 18: Controller Header Binding - Misto Case
# -----------------------------------------------------------------------------
Write-TestHeader "18" "Controller: Header Binding"

Test-Endpoint -Name "Controller: x-TeNanT-iD from header - Misto Case" `
    -Method "GET" `
    -Url "$BaseUrl/api/controller/header" `
    -Headers @{ "x-TeNanT-iD" = "controller-tenant" } `
    -Validate {
    param($r)
    $r.source -eq "controller-header" -and $r.tenantId -eq "controller-tenant"
}

# -----------------------------------------------------------------------------
# TEST 19: Controller FromBody Primitive Name-Matched
# -----------------------------------------------------------------------------
Write-TestHeader "19" "Controller: FromBody Primitive Name-Matched"

Test-Endpoint -Name "Controller: String param from name-matched JSON body" `
    -Method "POST" `
    -Url "$BaseUrl/api/controller/echo" `
    -Body '{"AMsg": "Hello Stefano"}' `
    -Validate {
    param($r)
    $r.source -eq "controller-echo" -and $r.message -eq "Hello Stefano"
}

# -----------------------------------------------------------------------------
# TEST 20: Controller FromBody Primitive Whole-Body
# -----------------------------------------------------------------------------
Write-TestHeader "20" "Controller: FromBody Primitive Whole-Body"

Test-Endpoint -Name "Controller: String param from raw whole body" `
    -Method "POST" `
    -Url "$BaseUrl/api/controller/echo" `
    -Body '"Hello Pure Body"' `
    -Validate {
    param($r)
    $r.source -eq "controller-echo" -and $r.message -eq "Hello Pure Body"
}

# =============================================================================
# SUMMARY
# =============================================================================

Write-Host ""
Write-Host "============================================================" -ForegroundColor White
Write-Host "  TEST SUMMARY" -ForegroundColor White  
Write-Host "============================================================" -ForegroundColor White
Write-Host ""
Write-Host "  Minimal API Tests: " -NoNewline
$minimalTests = $TestResults | Where-Object { -not $_.Test.StartsWith("Controller") } | Measure-Object
Write-Host "$($minimalTests.Count)" -ForegroundColor Gray

Write-Host "  Controller Tests:  " -NoNewline
$ctrlTests = $TestResults | Where-Object { $_.Test.StartsWith("Controller") } | Measure-Object
Write-Host "$($ctrlTests.Count)" -ForegroundColor Gray

Write-Host ""
Write-Host "  Passed: $TestsPassed" -ForegroundColor Green
Write-Host "  Failed: $TestsFailed" -ForegroundColor $(if ($TestsFailed -gt 0) { "Red" } else { "Green" })
Write-Host "  Total:  $($TestsPassed + $TestsFailed)" -ForegroundColor Gray
Write-Host ""

if ($TestsFailed -gt 0) {
    Write-Host "FAILED TESTS:" -ForegroundColor Red
    $TestResults | Where-Object { $_.Status -eq "FAIL" } | ForEach-Object {
        Write-Host "  - $($_.Test): $($_.Error)" -ForegroundColor Red
    }
    Write-Host ""
    exit 1
}
else {
    Write-Host "All tests passed! " -ForegroundColor Green -NoNewline
    Write-Host ([char]::ConvertFromUtf32(0x1F680)) # Rocket emoji
    exit 0
}
