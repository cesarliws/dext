Write-Host "Starting Server..."
$proc = Start-Process -FilePath ".\Dext.Starter.Admin.exe" -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 5

Write-Host "Running Load Test..."
# Use an endpoint that hits the database
$url = "http://localhost:8080/dashboard/stats" 
$jobs = @()
for ($i=0; $i -lt 20; $i++) {
    $jobs += Start-Job -ScriptBlock {
        param($u)
        try {
            $resp = Invoke-WebRequest -Uri $u -Method Get -ErrorAction Stop
            return $resp.StatusCode
        } catch {
            return $_.Exception.Message
        }
    } -ArgumentList $url
}

$results = $jobs | Receive-Job -Wait
$failed = $results | Where-Object { $_ -ne 200 }

if ($failed) {
    Write-Host "Load Test FAILED with errors:" -ForegroundColor Red
    $failed | ForEach-Object { Write-Host $_ -ForegroundColor Red }
} else {
    Write-Host "Load Test PASSED (20 requests)" -ForegroundColor Green
}

Stop-Process -Id $proc.Id -Force
Write-Host "Server Stopped."
