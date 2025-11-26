$baseUrl = "http://localhost:8080"

function Invoke-Curl {
    param([string]$CmdArgs)
    Write-Host "`n> curl $CmdArgs" -ForegroundColor Yellow
    # Execute curl.exe explicitly using Invoke-Expression to handle quotes correctly
    Invoke-Expression "curl.exe $CmdArgs"
}

Write-Host "--- TESTANDO ACTION FILTERS ---" -ForegroundColor Cyan

# 1. Simple Endpoint
# Expected: 200 OK, Log message in server console
Invoke-Curl "-i $baseUrl/api/filters/simple"

# 2. Cached Endpoint
# Expected: 200 OK, Cache-Control header, X-Custom-Header
Invoke-Curl "-i $baseUrl/api/filters/cached"

# 3. Secure Endpoint (Header Validation)
# Expected: 200 OK with valid key
Invoke-Curl ('-i -X POST -H "X-API-Key: secret" ' + "$baseUrl/api/filters/secure")

# 3.1 Secure Endpoint (Missing Key)
# Expected: 400 Bad Request (or whatever the filter returns, likely 400 or 401)
Invoke-Curl "-i -X POST $baseUrl/api/filters/secure"

# 4. Login to get Admin Token
Write-Host "`n> Autenticando para obter Token Admin..." -ForegroundColor Cyan

# Create a temporary file for the JSON payload to avoid shell escaping issues
$jsonFile = [System.IO.Path]::GetTempFileName()
Set-Content -Path $jsonFile -Value '{"username":"admin", "password":"admin"}'

$loginUrl = "$baseUrl/api/auth/login"
$loginCmd = "-s -X POST -H ""Content-Type: application/json"" -d @$jsonFile $loginUrl"

Write-Host "> curl ... -d @$jsonFile ..." -ForegroundColor Yellow
$tokenJson = & curl.exe -s -X POST -H "Content-Type: application/json" -d "@$jsonFile" "$loginUrl"

# Clean up temp file
Remove-Item $jsonFile

try {
    $token = ($tokenJson | ConvertFrom-Json).token
    if ([string]::IsNullOrWhiteSpace($token)) { throw "Token is empty" }
    Write-Host "Token obtido com sucesso." -ForegroundColor Green
}
catch {
    Write-Host "Erro ao obter token. Resposta do servidor:" -ForegroundColor Red
    Write-Host $tokenJson
    exit
}

# 5. Admin Endpoint (Requires Token + Admin Role)
# Expected: 200 OK
Invoke-Curl "-i -H ""Authorization: Bearer $token"" $baseUrl/api/filters/admin"

# 6. Protected Endpoint (Short-circuit check)
# Expected: 200 OK
Invoke-Curl "-i -H ""Authorization: Bearer $token"" $baseUrl/api/filters/protected"

Write-Host "`n--- TESTES CONCLUIDOS ---" -ForegroundColor Cyan
