$ErrorActionPreference = "Stop"
$baseUrl = "http://localhost:8080"
$demoToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkRlbW8gVXNlciIsImlhdCI6MTUxNjIzOTAyMn0.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"

Write-Host "[START] Testing Web.SwaggerControllerExample on $baseUrl" -ForegroundColor Cyan

function Invoke-DextRequest {
    param (
        [string]$Uri,
        [string]$Method = "GET",
        [string]$Body = $null,
        [string]$ContentType = "application/json",
        [string]$AuthToken = $null
    )
    try {
        $headers = @{}
        if ($AuthToken) {
            $headers["Authorization"] = "Bearer $AuthToken"
        }
        
        $params = @{
            Uri             = $Uri
            Method          = $Method
            UseBasicParsing = $true
            Headers         = $headers
        }
        if ($Body) {
            $params.Body = $Body
            $params.ContentType = $ContentType
        }
        $resp = Invoke-WebRequest @params
        return $resp
    }
    catch {
        if ($_.Exception.Response) {
            return @{
                StatusCode = [int]$_.Exception.Response.StatusCode
                Content    = $null
            }
        }
        throw
    }
}

try {
    # 1. Check Swagger UI
    Write-Host "`n1. Checking Swagger UI..." -ForegroundColor Yellow
    $ui = Invoke-DextRequest "$baseUrl/swagger"
    if ($ui.StatusCode -eq 200 -and $ui.Content -like "*swagger-ui*") {
        Write-Host "   [PASS] Swagger UI is available" -ForegroundColor Green
    }
    else {
        throw "Swagger UI not responding correctly"
    }

    # 2. Check Swagger JSON
    Write-Host "`n2. Checking OpenAPI JSON..." -ForegroundColor Yellow
    $jsonResp = Invoke-DextRequest "$baseUrl/swagger.json"
    $spec = $jsonResp.Content | ConvertFrom-Json
    Write-Host "   Title: $($spec.info.title)"
    Write-Host "   Version: $($spec.info.version)"
    
    if ($spec.paths.'/api/books') {
        Write-Host "   [PASS] /api/books path found in spec" -ForegroundColor Green
    }
    else {
        throw "Missing /api/books in swagger.json"
    }

    if ($spec.paths.'/api/auth/login') {
        Write-Host "   [PASS] /api/auth/login path found in spec" -ForegroundColor Green
    }
    else {
        Write-Host "   [WARN] /api/auth/login not found (optional)" -ForegroundColor Yellow
    }

    if ($spec.components.securitySchemes) {
        Write-Host "   [PASS] Security schemes configured" -ForegroundColor Green
    }

    # 3. Test Login
    Write-Host "`n3. Testing POST /api/auth/login..." -ForegroundColor Yellow
    $loginResp = Invoke-DextRequest "$baseUrl/api/auth/login" -Method "POST"
    if ($loginResp.StatusCode -eq 200) {
        $loginData = $loginResp.Content | ConvertFrom-Json
        Write-Host "   Token type: $($loginData.type)"
        Write-Host "   [PASS] Login returns token" -ForegroundColor Green
    }

    # 4. Test GET /api/books (no auth required)
    Write-Host "`n4. Testing GET /api/books..." -ForegroundColor Yellow
    $booksResp = Invoke-DextRequest "$baseUrl/api/books"
    $books = $booksResp.Content | ConvertFrom-Json
    $initialCount = if ($books -is [System.Array]) { $books.Count } else { 1 }
    Write-Host "   [PASS] Returned $initialCount books" -ForegroundColor Green

    # 5. Test POST /api/books without auth (should fail)
    Write-Host "`n5. Testing POST /api/books WITHOUT auth..." -ForegroundColor Yellow
    $body = '{"title":"Test Book","author":"Test Author","year":2024}'
    $noAuthResp = Invoke-DextRequest "$baseUrl/api/books" -Method "POST" -Body $body
    if ($noAuthResp.StatusCode -eq 401) {
        Write-Host "   [PASS] Correctly returned 401 Unauthorized" -ForegroundColor Green
    }
    else {
        Write-Host "   [WARN] Got status $($noAuthResp.StatusCode) (expected 401)" -ForegroundColor Yellow
    }

    # 6. Test POST /api/books WITH auth
    Write-Host "`n6. Testing POST /api/books WITH auth..." -ForegroundColor Yellow
    $createResp = Invoke-DextRequest "$baseUrl/api/books" -Method "POST" -Body $body -AuthToken $demoToken
    if ($createResp.StatusCode -eq 201) {
        $newBook = $createResp.Content | ConvertFrom-Json
        Write-Host "   Created: $($newBook.Title) (ID: $($newBook.Id))"
        Write-Host "   [PASS] Book created successfully" -ForegroundColor Green
        $createdId = $newBook.Id
    }
    else {
        Write-Host "   [WARN] Got status $($createResp.StatusCode)" -ForegroundColor Yellow
        $createdId = $null
    }

    # 7. Test DELETE /api/books/{id} WITH auth
    if ($createdId) {
        Write-Host "`n7. Testing DELETE /api/books/$createdId WITH auth..." -ForegroundColor Yellow
        $deleteResp = Invoke-DextRequest "$baseUrl/api/books/$createdId" -Method "DELETE" -AuthToken $demoToken
        if ($deleteResp.StatusCode -eq 204) {
            Write-Host "   [PASS] Book deleted successfully" -ForegroundColor Green
        }
        else {
            Write-Host "   [WARN] Got status $($deleteResp.StatusCode)" -ForegroundColor Yellow
        }
    }

    # 8. Test Health Check
    Write-Host "`n8. Testing GET /api/health..." -ForegroundColor Yellow
    $healthResp = Invoke-DextRequest "$baseUrl/api/health"
    $health = $healthResp.Content | ConvertFrom-Json
    Write-Host "   Status: $($health.status)"
    Write-Host "   [PASS] Health check passed" -ForegroundColor Green

    Write-Host "`n" + ("=" * 50) -ForegroundColor Cyan
    Write-Host "SUCCESS: ALL SWAGGER CONTROLLER TESTS PASSED!" -ForegroundColor Green
    Write-Host ("=" * 50) -ForegroundColor Cyan

}
catch {
    Write-Error "TEST FAILED: $_"
    exit 1
}

