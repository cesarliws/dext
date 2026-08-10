$proc = Start-Process -FilePath "C:\dev\Dext\DextRepository\Examples\Output\Web.FastPath.OrmPool.exe" -PassThru
Start-Sleep -Seconds 2
Write-Host "Process HasExited: $($proc.HasExited)"
if (-not $proc.HasExited) {
    try {
        $res = Invoke-RestMethod -Uri "http://localhost:5050/fastusers"
        Write-Host "FASTUSERS:" ($res | ConvertTo-Json -Compress)
        $res2 = Invoke-RestMethod -Uri "http://localhost:5050/users"
        Write-Host "USERS:" ($res2 | ConvertTo-Json -Compress)
    } finally {
        Stop-Process -Id $proc.Id -Force
    }
}
