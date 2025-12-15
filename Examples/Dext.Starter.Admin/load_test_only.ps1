$loginUrl = "http://localhost:8080/auth/login"
Write-Host "Logging in..."
$token = ""
try {
    # Login to get token - Send valid JSON object
    $body = "{}" 
    $resp = Invoke-WebRequest -Uri $loginUrl -Method Post -Body $body -ContentType "application/json"
    
    $raw = $resp.Content
    # Write-Host "Response: $raw"

    if ([string]::IsNullOrWhitespace($raw)) {
        Write-Host "Login Failed: Empty response" -ForegroundColor Red
        exit 1
    }

    # Parse JSON
    $json = $raw | ConvertFrom-Json
    $token = $json.token
    
    if ([string]::IsNullOrEmpty($token)) {
        Write-Host "Failed to get token from JSON" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Authenticated. Token len: $($token.Length)"
}
catch {
    Write-Host "Login Failed: $_" -ForegroundColor Red
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader $_.Exception.Response.GetResponseStream()
        $errBody = $reader.ReadToEnd()
        Write-Host "Error Body: $errBody" -ForegroundColor Yellow
    }
    exit 1
}

$url = "http://localhost:8080/dashboard/stats"
Write-Host "Hitting $url with 20 concurrent requests..."

$jobs = @()
for ($i = 0; $i -lt 20; $i++) {
    $jobs += Start-Job -ScriptBlock {
        param($u, $t)
        try {
            # Pass Authorization header
            $headers = @{ "Authorization" = "Bearer $t" }
            $resp = Invoke-WebRequest -Uri $u -Method Get -Headers $headers -ErrorAction Stop
            return $resp.StatusCode
        }
        catch {
            return $_.Exception.Message
        }
    } -ArgumentList $url, $token
}

$results = $jobs | Receive-Job -Wait
$failed = $results | Where-Object { $_ -ne 200 }

if ($failed) {
    Write-Host "Load Test FAILED with errors:" -ForegroundColor Red
    $failed | Select-Object -First 5 | ForEach-Object { Write-Host $_ -ForegroundColor Red }
}
else {
    Write-Host "Load Test PASSED (20 requests with 200 OK)" -ForegroundColor Green
}
