# ============================================================================
# Test.WebStencilsDemo.ps1
# Hits every URL the ECON26 talk 2 demo exposes.
# Server must be running: http://127.0.0.1:5000
# Pipeline: Scripts/run_examples.ps1 discovers Test.*.ps1 next to the .dproj
# ============================================================================

$ErrorActionPreference = "Stop"
$baseUrl = "http://127.0.0.1:5000"

Write-Host ""
Write-Host "ECON26 WebStencilsDemo - $baseUrl" -ForegroundColor Cyan
Write-Host ""

function Invoke-Page {
    param(
        [string]$Path,
        [hashtable]$Headers = @{}
    )
    $uri = "$baseUrl$Path"
    try {
        return Invoke-WebRequest -Uri $uri -Headers $Headers -UseBasicParsing
    }
    catch {
        throw "TEST FAILED: GET $Path - $_"
    }
}

try {
    Write-Host "1. GET /" -ForegroundColor Yellow
    $landing = Invoke-Page "/"
    if ($landing.Content -notlike "*SSR*") { throw "home page should render the SSR landing" }
    if ($landing.Content -like "*Gemini*") { throw "home page served DextGemini leftover from Examples/Output/wwwroot" }
    Write-Host "   home ok" -ForegroundColor Green

    Write-Host "2. GET /customers" -ForegroundColor Yellow
    $list = Invoke-Page "/customers"
    if ($list.Content -notlike "*Lovelace*") { throw "customers page should list Ada Lovelace" }
    if ($list.Content -notlike "*hx-get*") { throw "customers page should include HTMX on the search" }
    Write-Host "   list + HTMX ok" -ForegroundColor Green

    Write-Host "3. GET /customers/search?SearchTerm=Love" -ForegroundColor Yellow
    $search = Invoke-Page "/customers/search?SearchTerm=Love"
    if ($search.Content -notlike "*Lovelace*") { throw "search should find Lovelace" }
    if ($search.Content -like "*Turing*") { throw "search for Love should not still list Turing" }
    Write-Host "   search ok" -ForegroundColor Green

    Write-Host "4. GET /customers/search with HX-Request (fragment)" -ForegroundColor Yellow
    $frag = Invoke-Page "/customers/search?SearchTerm=Love" -Headers @{ "HX-Request" = "true" }
    if ($frag.Content -notlike "*Lovelace*") { throw "HTMX fragment should still contain Lovelace" }
    Write-Host "   fragment ok" -ForegroundColor Green

    Write-Host ""
    Write-Host "SUCCESS: ALL WEBSTENCILS DEMO TESTS PASSED" -ForegroundColor Green
    exit 0
}
catch {
    Write-Error $_
    exit 1
}
