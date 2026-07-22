$ErrorActionPreference = "Continue"
$baseUrl = "http://localhost:8080"

Write-Host "[START] Testing Web.RateLimitDemo on $baseUrl" -ForegroundColor Cyan
Write-Host "Sending 15 requests (Limit is 10/min)..."

$success = 0
$limited = 0

for ($i = 1; $i -le 15; $i++) {
    try {
        $resp = Invoke-WebRequest "$baseUrl/api/test" -UseBasicParsing
        
        # Try to extract header safely (PS Core / Desktop compatibility)
        $headers = $resp.Headers
        if ($null -eq $headers["X-RateLimit-Remaining"] -and $null -ne $resp.BaseResponse) {
            $headers = $resp.BaseResponse.Headers
        }

        if ($i -eq 1) {
            Write-Host "DEBUG: Headers received on first request:" -ForegroundColor Gray
            if ($headers -is [System.Collections.Specialized.NameValueCollection]) {
                foreach ($key in $headers.AllKeys) {
                    Write-Host "  $key - $($headers[$key])" -ForegroundColor Gray
                }
            }
            else {
                # Fallback for Dictionary or other types
                $headers.GetEnumerator() | ForEach-Object { Write-Host "  $($_.Key) - $($_.Value)" -ForegroundColor Gray }
            }
        }

        $rem = $headers["X-RateLimit-Remaining"]
        
        # Handle case-sensitivity issues if dictionary is case-sensitive
        if ($null -eq $rem) { $rem = $headers["x-ratelimit-remaining"] }
        
        if ($null -eq $rem) { $rem = "?" }
        
        Write-Host "Req #$i - OK (Remaining: $rem)"
        $success++
    }
    catch {
        $ex = $_.Exception
        $statusCode = 0
        
        if ($null -ne $ex.Response) {
            $statusCode = [int]$ex.Response.StatusCode
        }

        if ($statusCode -eq 429) {
            # 429 Too Many Requests
            $retry = "?"
            if ($null -ne $ex.Response.Headers["Retry-After"]) {
                $retry = $ex.Response.Headers["Retry-After"]
            }
            
            Write-Host "Req #$i - BLOCKED (429) - Retry After: $retry sec" -ForegroundColor Magenta
            $limited++
        }
        else {
            Write-Error "Req #$i - Failed with $($ex.Message) (Status: $statusCode)"
        }
    }
}

Write-Host "`nResults:"
Write-Host "Success: $success"
Write-Host "Limited: $limited"

if ($success -eq 10 -and $limited -eq 5) {
    Write-Host "`nSUCCESS: RATE LIMIT TEST PASSED (Exact Match)" -ForegroundColor Green
}
elseif ($success -gt 10) {
    Write-Error "`nFAIL: Rate limit not enforced (Success > 10)" 
    exit 1
}
elseif ($success -lt 10) {
    # Se rodar o teste 2 vezes seguido, pode falhar pq o contador n o resetou.
    Write-Host "`nWARN: Less success than expected. Did you run the test twice within 60s?" -ForegroundColor Yellow
}
else {
    Write-Host "`nWARN: Counts differ." -ForegroundColor Yellow
}
