# ============================================================================
# Test.ECON26.Faturamento.Api.ps1
# Hits every URL the ECON26 talk 1 demo exposes.
# Server must be running: http://127.0.0.1:5000
# Pipeline: Scripts/run_examples.ps1 discovers Test.*.ps1 next to the .dproj
# ============================================================================

$ErrorActionPreference = "Stop"
$baseUrl = "http://127.0.0.1:5000"
$headers = @{
    "Accept"       = "application/json"
    "Content-Type" = "application/json; charset=utf-8"
}

Write-Host ""
Write-Host "ECON26 Faturamento API - $baseUrl" -ForegroundColor Cyan
Write-Host ""

function Invoke-Dext {
    param(
        [string]$Method = "GET",
        [string]$Path,
        [string]$Body = $null,
        [int[]]$Expect = @(200, 201)
    )
    $uri = "$baseUrl$Path"
    try {
        $params = @{
            Uri             = $uri
            Method          = $Method
            Headers         = $headers
            UseBasicParsing = $true
        }
        if ($Body) { $params.Body = $Body }
        $resp = Invoke-WebRequest @params
        $code = [int]$resp.StatusCode
        if ($Expect -notcontains $code) {
            throw "Expected $($Expect -join '/') at $Method $Path, got $code"
        }
        return $resp
    }
    catch {
        $code = 0
        if ($_.Exception.Response) {
            $code = [int]$_.Exception.Response.StatusCode
        }
        if ($code -gt 0 -and ($Expect -contains $code)) {
            return [pscustomobject]@{ StatusCode = $code; Content = $_.ErrorDetails.Message }
        }
        throw "TEST FAILED: $Method $Path - $_"
    }
}

try {
    Write-Host "1. GET /hello" -ForegroundColor Yellow
    $hello = Invoke-Dext -Path "/hello"
    if ($hello.Content -notlike "*ECON26*") { throw "/hello did not return the palco banner" }
    Write-Host "   $($hello.Content)" -ForegroundColor Green

    Write-Host "2. GET /api/products/search?Termo=Ada" -ForegroundColor Yellow
    $search = Invoke-Dext -Path "/api/products/search?Termo=Ada"
    if ($search.Content -notlike "*Lovelace*") { throw "search should find Ada Lovelace" }
    Write-Host "   search found Lovelace" -ForegroundColor Green

    Write-Host "3. GET /api/products (DataAPI list)" -ForegroundColor Yellow
    $list = Invoke-Dext -Path "/api/products"
    $products = $list.Content | ConvertFrom-Json
    if ($products.Count -lt 2) { throw "seed should have at least two products" }
    Write-Host "   $($products.Count) products" -ForegroundColor Green

    $inactive = $products | Where-Object { -not $_.active } | Select-Object -First 1
    $active = $products | Where-Object { $_.active } | Select-Object -First 1
    if (-not $inactive) { throw "seed should include an inactive product" }
    if (-not $active) { throw "seed should include an active product" }

    Write-Host "4. GET /swagger.json" -ForegroundColor Yellow
    $swagger = Invoke-Dext -Path "/swagger.json"
    if ($swagger.Content -notlike "*products*") { throw "swagger.json should describe products" }
    Write-Host "   OpenAPI ok" -ForegroundColor Green

    Write-Host "5. POST /api/orders without Qty (validation 400)" -ForegroundColor Yellow
    Invoke-Dext -Method POST -Path "/api/orders" -Body '{"productId":1}' -Expect @(400) | Out-Null
    Write-Host "   400" -ForegroundColor Green

    Write-Host "6. POST /api/orders inactive product (422)" -ForegroundColor Yellow
    $bodyInactive = @{ productId = [int]$inactive.id; qty = 1 } | ConvertTo-Json -Compress
    Invoke-Dext -Method POST -Path "/api/orders" -Body $bodyInactive -Expect @(422) | Out-Null
    Write-Host "   422" -ForegroundColor Green

    Write-Host "7. POST /api/orders active product (201)" -ForegroundColor Yellow
    $bodyOk = @{ productId = [int]$active.id; qty = 1 } | ConvertTo-Json -Compress
    Invoke-Dext -Method POST -Path "/api/orders" -Body $bodyOk -Expect @(201) | Out-Null
    Write-Host "   201" -ForegroundColor Green

    Write-Host ""
    Write-Host "SUCCESS: ALL FATURAMENTO API TESTS PASSED" -ForegroundColor Green
    exit 0
}
catch {
    Write-Error $_
    exit 1
}
