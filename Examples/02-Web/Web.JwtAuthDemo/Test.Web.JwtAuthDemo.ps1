$ErrorActionPreference = "Stop"
$baseUrl = "http://localhost:8080"

Write-Host "[START] Testing Web.JwtAuthDemo on $baseUrl" -ForegroundColor Cyan

function Invoke-DextRequest {
    param (
        [string]$Uri,
        [string]$Method = "GET",
        [string]$Body = $null,
        [hashtable]$Headers = @{}
    )
    try {
        $params = @{
            Uri             = $Uri
            Method          = $Method
            UseBasicParsing = $true
            Headers         = $Headers
            ContentType     = "application/json"
        }
        if ($Body) { $params.Body = $Body }
        
        $resp = Invoke-WebRequest @params
        # Handle JSON content
        try {
            return ($resp.Content | ConvertFrom-Json)
        }
        catch {
            return $resp.Content 
        }
    }
    catch {
        if ($_.Exception.Response) {
            # Return response object for error status checking in caller
            # Throwing here makes flow control harder for expected errors
            throw
        }
        throw
    }
}

try {
    # 1. Public Endpoint
    Write-Host "`n1. Testing Public Endpoint..." -ForegroundColor Yellow
    $pub = Invoke-DextRequest "$baseUrl/api/public"
    Write-Host "   Message: $($pub.message)"

    # 2. Login (Admin)
    Write-Host "`n2. Logging in (Admin)..." -ForegroundColor Yellow
    $loginData = '{"Username": "admin", "Password": "password"}'
    $tokenJson = Invoke-DextRequest "$baseUrl/api/auth/login" "POST" $loginData
    $token = $tokenJson.token
    Write-Host "   Token received"
    $headers = @{ "Authorization" = "Bearer $token" }

    # 3. Protected Endpoint (With Token)
    Write-Host "`n3. Testing Protected (Authorized)..." -ForegroundColor Yellow
    $prot = Invoke-DextRequest "$baseUrl/api/protected" "GET" $null $headers
    Write-Host "   User: $($prot.username)"
    if ($prot.username -ne "admin") { throw "Wrong user returned" }

    # 4. Protected Endpoint (No Token)
    Write-Host "`n4. Testing Protected (Unauthorized)..." -ForegroundColor Yellow
    try {
        Invoke-WebRequest -Uri "$baseUrl/api/protected" -UseBasicParsing | Out-Null
        Write-Error "FAIL: Should have failed with 401/403"
    }
    catch {
        $status = $_.Exception.Response.StatusCode
        if ($status -eq [System.Net.HttpStatusCode]::Unauthorized -or $status -eq [System.Net.HttpStatusCode]::Forbidden) {
            Write-Host "   SUCCESS: Correctly blocked ($status)" -ForegroundColor Green
        }
        else {
            Write-Error "FAIL: Unexpected status code $status"
        }
    }

    # 5. Access Admin Endpoint
    Write-Host "`n5. Testing Admin Endpoint..." -ForegroundColor Yellow
    $admin = Invoke-DextRequest "$baseUrl/api/admin" "GET" $null $headers
    Write-Host "   Message: $($admin.message)"

    Write-Host "`nSUCCESS: ALL JWT TESTS PASSED!" -ForegroundColor Green

}
catch {
    Write-Error "TEST FAILED: $_"
    exit 1
}
