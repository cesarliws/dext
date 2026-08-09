# Script de Teste e Benchmark Paralelo (FastPath + DbContext Pool)
param(
    [int]$Concurrency = 20,
    [int]$RequestsPerWorker = 50,
    [string]$BaseUrl = "http://localhost:5050"
)

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "🚀 Dext FastPath & DbContext Pool Concurrent Test Suite" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "Target URL: $BaseUrl"
Write-Host "Workers: $Concurrency | Requests/Worker: $RequestsPerWorker | Total: $($Concurrency * $RequestsPerWorker)"
Write-Host ""

function Test-Endpoint {
    param([string]$Path)
    
    $Url = "$BaseUrl$Path"
    Write-Host "Testing Endpoint: $Url ..." -NoNewline
    
    $SW = [System.Diagnostics.Stopwatch]::StartNew()
    
    $Jobs = 1..$Concurrency | ForEach-Object {
        Start-Job -ScriptBlock {
            param($TargetUrl, $Count)
            $SuccessCount = 0
            $FailCount = 0
            
            for ($i = 0; $i -lt $Count; $i++) {
                try {
                    $Req = [System.Net.WebRequest]::Create($TargetUrl)
                    $Req.Timeout = 5000
                    $Resp = $Req.GetResponse()
                    if ($Resp.StatusCode -eq 200) {
                        $SuccessCount++
                    } else {
                        $FailCount++
                    }
                    $Resp.Close()
                } catch {
                    $FailCount++
                }
            }
            return @{ Success = $SuccessCount; Fail = $FailCount }
        } -ArgumentList $Url, $RequestsPerWorker
    }

    $Results = $Jobs | Wait-Job | Receive-Job
    $Jobs | Remove-Job

    $SW.Stop()
    
    $TotalSuccess = ($Results | ForEach-Object { $_.Success } | Measure-Object -Sum).Sum
    $TotalFail = ($Results | ForEach-Object { $_.Fail } | Measure-Object -Sum).Sum
    $TotalReqs = $TotalSuccess + $TotalFail
    $RPS = [math]::Round($TotalReqs / $SW.Elapsed.TotalSeconds, 2)

    Write-Host " [DONE in $($SW.Elapsed.TotalMilliseconds) ms]" -ForegroundColor Green
    Write-Host "   ✅ Passed: $TotalSuccess | ❌ Failed: $TotalFail | ⚡ Throughput: $RPS Reqs/sec" -ForegroundColor Yellow
    Write-Host ""
}

Test-Endpoint -Path "/fastusers"
Test-Endpoint -Path "/users"
