$ErrorActionPreference = "Stop"
$baseUrl = "http://localhost:5000" 

Write-Host "[START] Testing Web.SwaggerExample on $baseUrl" -ForegroundColor Cyan

function Invoke-DextRequest {
    param (
        [string]$Uri,
        [string]$Method = "GET"
    )
    try {
        $resp = Invoke-WebRequest -Uri $Uri -Method $Method -UseBasicParsing
        return $resp
    }
    catch {
        Write-Error "Request to $Uri failed: $($_.Exception.Message)"
        throw
    }
}

try {
    # 1. Check Swagger UI
    Write-Host "`n1. Checking Swagger UI..." -ForegroundColor Yellow
    # Note: Swagger UI often redirects /swagger to /swagger/index.html or similar. Checking status or content.
    # Dext Middleware likely does a Rewrite or ServeStatic.
    
    # Try /swagger first (might redirect)
    try {
        $ui = Invoke-DextRequest "$baseUrl/swagger"
        Write-Host "   /swagger Status: $($ui.StatusCode)"
    }
    catch {
        # Redirect handling in Invoke-WebRequest PS 5.1 is automatic generally, unless strict
        Write-Warning "   /swagger access issue: $_"
    }

    # 2. Check Swagger JSON
    Write-Host "`n2. Checking OpenApi JSON..." -ForegroundColor Yellow
    $jsonResp = Invoke-DextRequest "$baseUrl/swagger.json"
    $spec = $jsonResp.Content | ConvertFrom-Json
    Write-Host "   Title: $($spec.info.title)"
    Write-Host "   Version: $($spec.info.version)"
    
    # Check for path definitions
    # Note: PS object property access for keys with slashes needs quotes
    if ($spec.paths."/api/users") {
        Write-Host "   Definition for /api/users found."
    }
    else {
        throw "Missing API definitions in swagger.json"
    }

    # 3. Test API Endpoint
    Write-Host "`n3. Testing API Users..." -ForegroundColor Yellow
    $usersResp = Invoke-DextRequest "$baseUrl/api/users"
    $users = $usersResp.Content | ConvertFrom-Json
    
    if ($users -is [System.Array]) {
        $count = $users.Count
    }
    else {
        $count = 1
    }
    
    Write-Host "   Returned $count users"
    if ($count -eq 0) { throw "API returned no data" }

    Write-Host "`nSUCCESS: ALL SWAGGER TESTS PASSED!" -ForegroundColor Green

}
catch {
    Write-Error "TEST FAILED: $_"
    exit 1
}
