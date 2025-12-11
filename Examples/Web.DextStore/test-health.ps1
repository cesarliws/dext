# Simple test to check if server is running
$baseUrl = "http://localhost:9000"

Write-Host "Testing Health Check..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "$baseUrl/health" -Method Get
    Write-Host "✅ Server is running!" -ForegroundColor Green
    Write-Host ($response | ConvertTo-Json)
}
catch {
    Write-Host "❌ Server is not responding" -ForegroundColor Red
    Write-Host $_.Exception.Message
}
