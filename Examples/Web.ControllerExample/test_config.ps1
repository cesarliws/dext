# Config Test Script (ControllerExample)
$baseUrl = "http://localhost:8080"
$token = ""

Write-Host "[TEST] Config Test Suite" -ForegroundColor Cyan
Write-Host "========================" -ForegroundColor Cyan

# Helper function
function Test-Endpoint {
  param($Method, $Url, $Body = $null, $Headers = @{}, $ExpectedStatus = 200)
    
  Write-Host "Testing $Method $Url..." -NoNewline -ForegroundColor Yellow
  try {
    if ($Body) {
      $response = Invoke-RestMethod -Method $Method -Uri "$baseUrl$Url" -Body ($Body | ConvertTo-Json) -ContentType "application/json" -Headers $Headers -ErrorAction Stop
    }
    else {
      $response = Invoke-RestMethod -Method $Method -Uri "$baseUrl$Url" -Headers $Headers -ErrorAction Stop
    }
    Write-Host " [OK]" -ForegroundColor Green
    return $response
  }
  catch {
    if ($_.Exception.Response.StatusCode.value__ -eq $ExpectedStatus) {
      Write-Host " [OK] (Expected $ExpectedStatus)" -ForegroundColor Green
    }
    else {
      Write-Host " [FAILED] Status: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
            
      # Print Body if available
      $stream = $_.Exception.Response.GetResponseStream()
      if ($stream) {
        $reader = New-Object System.IO.StreamReader($stream)
        $body = $reader.ReadToEnd()
        if ($body) { Write-Host "Response Body: $body" -ForegroundColor DarkRed }
      }
    }
    return $null
  }
}

# 1. Login
$loginResponse = Test-Endpoint "POST" "/api/auth/login" -Body @{ username = "admin"; password = "admin" }
if ($loginResponse) {
  $token = $loginResponse.token
  Write-Host "Token obtained." -ForegroundColor Gray
}
else {
  Write-Host "Login Failed. Aborting." -ForegroundColor Red
  exit
}

# 2. Config Endpoint
$configResponse = Test-Endpoint "GET" "/api/greet/config" -Headers @{ "Authorization" = "Bearer $token" }

if ($configResponse) {
  Write-Host "Response:" -ForegroundColor Cyan
  $configResponse | ConvertTo-Json -Depth 2 | Write-Host -ForegroundColor Gray
    
  if ($configResponse.message -match "Hello.*config") {
    Write-Host "✅ Configuration Value Verified" -ForegroundColor Green
  }
  else {
    Write-Host "❌ Unexpected configuration value: $($configResponse.message)" -ForegroundColor Red
  }
}

Write-Host "`n[DONE] Test Suite Completed!" -ForegroundColor Green
