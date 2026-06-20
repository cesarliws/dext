### Tests for Dext Air Flow API
$HostUrl = "http://localhost:9000"

Write-Host "`n🧪 Testing Dext Air Flow API..." -ForegroundColor Cyan
Write-Host "================================`n"

# Helper function to print response
function Show-Response($Name, $Response) {
    Write-Host "   ✅ $Name" -ForegroundColor Green
    $Response | ConvertTo-Json -Depth 10 | Write-Host
    Write-Host "--------------------------------"
}

# 1. Health Check
try {
    $Response = Invoke-RestMethod -Uri "$HostUrl/health" -Method Get -ErrorAction Stop
    Show-Response "Health Check" $Response
}
catch {
    Write-Host "   ❌ Health Check Failed: $_" -ForegroundColor Red
}

# 2. Trigger Alert
try {
    $Response = Invoke-RestMethod -Uri "$HostUrl/api/alerts?vehicleId=V05&message=High%20wind%20warning%20in%20North%20sector" -Method Post -ErrorAction Stop
    Show-Response "Trigger Alert" $Response
}
catch {
    Write-Host "   ❌ Trigger Alert Failed: $_" -ForegroundColor Red
}

Write-Host "`n✨ All tests completed." -ForegroundColor Green
