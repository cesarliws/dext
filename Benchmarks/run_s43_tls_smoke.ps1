[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$HttpsUrl,
    [string]$HostName = 'localhost',
    [int]$Port = 443,
    [string]$WebSocketUrl,
    [string]$Websocat = 'websocat'
)

$ErrorActionPreference = 'Stop'
$curl = Get-Command curl.exe -ErrorAction SilentlyContinue
$openssl = Get-Command openssl.exe -ErrorAction SilentlyContinue
if (-not $curl) { throw 'curl.exe nao encontrado.' }
if (-not $openssl) { throw 'openssl.exe nao encontrado.' }

Write-Host "HTTPS smoke: $HttpsUrl"
$curlOutput = & $curl.Source '--http1.1' '-k' '-sS' '-o' 'NUL' '-w' 'status=%{http_code} connect=%{time_connect}s tls=%{time_appconnect}s total=%{time_total}s' $HttpsUrl
if ($LASTEXITCODE -ne 0) { throw "curl HTTPS falhou com codigo $LASTEXITCODE" }
$curlOutput

Write-Host "TLS handshake: $HostName`:$Port"
$tlsOutput = '' | & $openssl.Source s_client '-connect' "$HostName`:$Port" '-servername' $HostName '-brief' 2>&1
if ($LASTEXITCODE -ne 0) { throw "OpenSSL handshake falhou com codigo $LASTEXITCODE`n$tlsOutput" }
$tlsOutput | Select-String 'Protocol|Ciphersuite|Verification|Peer certificate'

if ($WebSocketUrl) {
    $ws = Get-Command $Websocat -ErrorAction SilentlyContinue
    if (-not $ws) { throw "websocat nao encontrado para validar WSS: $Websocat" }
    Write-Host "WSS smoke: $WebSocketUrl"
    's43-wss-probe' | & $ws.Source '-k' $WebSocketUrl
    if ($LASTEXITCODE -ne 0) { throw "websocat WSS falhou com codigo $LASTEXITCODE" }
}
