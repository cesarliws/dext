$proc = Start-Process -FilePath "C:\dev\Dext\DextRepository\Examples\Output\Web.FastPath.OrmPool.exe" -PassThru
Start-Sleep -Seconds 3
try {
    $res1 = Invoke-RestMethod -Uri "http://localhost:5050/fastusers"
    Write-Host "FASTUSERS RESPONSE:"
    $res1 | ConvertTo-Json -Compress | Write-Host
    Write-Host "---"
    $res2 = Invoke-RestMethod -Uri "http://localhost:5050/users"
    Write-Host "USERS RESPONSE:"
    $res2 | ConvertTo-Json -Compress | Write-Host
} finally {
    if ($proc -and -not $proc.HasExited) {
        Stop-Process -Id $proc.Id -Force
    }
}
