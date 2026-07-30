[CmdletBinding()]
param(
    [ValidateSet('indy', 'httpsys', 'epoll')]
    [string]$Engine = 'epoll',
    [int]$Port = 8086,
    [int]$Concurrency = 32,
    [int]$DurationSeconds = 10,
    [string]$BenchmarkExe = (Join-Path $PSScriptRoot 'Dext.Benchmarks.exe'),
    [switch]$Wsl
)

$ErrorActionPreference = 'Stop'
$url = "http://127.0.0.1:$Port/ping"
$bombardier = Get-Command bombardier -ErrorAction SilentlyContinue
if (-not $bombardier) {
    $candidate = 'C:\dev\tools\bombardier-windows-amd64.exe'
    if (Test-Path -LiteralPath $candidate) { $bombardier = Get-Item -LiteralPath $candidate }
}
if (-not $bombardier) {
    throw 'bombardier nao encontrado. Instale-o ou ajuste o PATH.'
}
$bombardierPath = $bombardier.Source
if (-not $bombardierPath) { $bombardierPath = $bombardier.FullName }

function Wait-HttpReady([string]$Address) {
    $deadline = [DateTime]::UtcNow.AddSeconds(15)
    do {
        try {
            $response = Invoke-WebRequest -Uri $Address -TimeoutSec 2 -UseBasicParsing
            if ($response.StatusCode -eq 200) { return }
        } catch { Start-Sleep -Milliseconds 250 }
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Servidor nao respondeu em $Address"
}

$argumentList = @('--server', "-$Engine", $Port)
$server = $null
$sample = @()
try {
    if ($Wsl) {
        $remoteDir = '/home/cesar/PAServer/scratch-dir/Cezar-WSL-Ubuntu/Dext.Benchmarks'
        $command = "cd '$remoteDir' && DEXT_SERVER_DURATION_MS=$((($DurationSeconds + 20) * 1000)) ./Dext_Benchmarks --server -$Engine $Port"
        $server = Start-Process -FilePath 'wsl.exe' -ArgumentList @('sh', '-lc', $command) -PassThru -WindowStyle Hidden
    } else {
        if (-not (Test-Path -LiteralPath $BenchmarkExe)) {
            throw "Executavel nao encontrado: $BenchmarkExe"
        }
        $server = Start-Process -FilePath $BenchmarkExe -ArgumentList $argumentList -PassThru -WindowStyle Hidden
    }

    Wait-HttpReady $url
    $before = if ($Wsl) { $null } else { Get-Process -Id $server.Id }
    & $bombardierPath -c $Concurrency -d "${DurationSeconds}s" $url
    if ($before) {
        $after = Get-Process -Id $server.Id -ErrorAction SilentlyContinue
        if ($after) {
            $sample = [pscustomobject]@{
                Engine = $Engine
                Concurrency = $Concurrency
                DurationSeconds = $DurationSeconds
                CpuSeconds = [Math]::Round($after.CPU - $before.CPU, 3)
                WorkingSetBytes = $after.WorkingSet64
                PrivateBytes = $after.PrivateMemorySize64
            }
            $sample | Format-List
        }
    }
} finally {
    if ($server) {
        if ($Wsl) {
            wsl.exe -e sh -lc "pkill -f 'Dext_Benchmarks --server -$Engine $Port' 2>/dev/null || true" | Out-Null
        } else {
            Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue
        }
    }
}
