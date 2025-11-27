$baseUrl = "http://localhost:8080"

function Invoke-Curl {
    param (
        [string]$Arguments
    )
    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = "curl"
    $processInfo.Arguments = $Arguments
    $processInfo.RedirectStandardOutput = $true
    $processInfo.RedirectStandardError = $true
    $processInfo.UseShellExecute = $false
    $processInfo.CreateNoWindow = $true
    $process = [System.Diagnostics.Process]::Start($processInfo)
    $process.WaitForExit()
    $output = $process.StandardOutput.ReadToEnd()
    $error = $process.StandardError.ReadToEnd()
    
    if ($process.ExitCode -ne 0) {
        Write-Host "Error executing curl: $error" -ForegroundColor Red
    }
    
    return $output
}

Write-Host "Testing Configuration Endpoint..." -ForegroundColor Cyan
$response = Invoke-Curl "-s $baseUrl/api/greet/config"
Write-Host "Response: $response"

if ($response -match "Hello from appsettings.json") {
    Write-Host "✅ Configuration Test Passed" -ForegroundColor Green
}
else {
    Write-Host "❌ Configuration Test Failed" -ForegroundColor Red
}
