# Dext HTTP/2 — gRPC Test Script
# This script sends a mockup gRPC unary request over HTTP/2 to the local echo server.

$ErrorActionPreference = "Stop"

# Create HttpClient forcing HTTP/2 prior knowledge / exact version
$handler = New-Object System.Net.Http.HttpClientHandler
$client = New-Object System.Net.Http.HttpClient($handler)

# 1. Prepare gRPC Length-Prefixed Message
# Format: [1-byte compressed flag] [4-byte big-endian length] [Protobuf data]
$payload = [System.Text.Encoding]::UTF8.GetBytes("DelphiDeveloper")
$msg = New-Object byte[] (5 + $payload.Length)
$msg[0] = 0 # uncompressed
$msg[1] = 0
$msg[2] = 0
$msg[3] = 0
$msg[4] = [byte]($payload.Length)
[System.Array]::Copy($payload, 0, $msg, 5, $payload.Length)

# 2. Build Request
$req = New-Object System.Net.Http.HttpRequestMessage
$req.Method = [System.Net.Http.HttpMethod]::Post
$req.RequestUri = "http://localhost:8443/grpc.mock.MockService/MockMethod"
$req.Version = [System.Version]"2.0" # Force HTTP/2

$content = New-Object System.Net.Http.ByteArrayContent($msg, 0, $msg.Length)
$content.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("application/grpc")
$req.Content = $content

Write-Host "🚀 Sending HTTP/2 gRPC Unary Request to http://localhost:8443/grpc..." -ForegroundColor Cyan

try {
    $res = $client.SendAsync($req).Result

    Write-Host "`n[HTTP RESPONSE]" -ForegroundColor Green
    Write-Host "Status Code: $($res.StatusCode) ($([int]$res.StatusCode))"
    Write-Host "Version:     $($res.Version)"

    Write-Host "`n[HEADERS]" -ForegroundColor Green
    foreach ($h in $res.Headers) {
        Write-Host "  $($h.Key): $([string]::Join(', ', $h.Value))"
    }
    foreach ($h in $res.Content.Headers) {
        Write-Host "  $($h.Key): $([string]::Join(', ', $h.Value))"
    }

    # Reading gRPC Trailers (Sent as END_STREAM HEADERS)
    Write-Host "`n[TRAILERS]" -ForegroundColor Green
    if ($res.TrailingHeaders.Count -gt 0) {
        foreach ($h in $res.TrailingHeaders) {
            Write-Host "  $($h.Key): $([string]::Join(', ', $h.Value))"
        }
    } else {
        Write-Host "  No trailers found in response (check server logs)." -ForegroundColor Yellow
    }

    # 3. Read & Unpack Response Message
    $resBytes = $res.Content.ReadAsByteArrayAsync().Result
    Write-Host "`n[BODY]" -ForegroundColor Green
    Write-Host "Raw Payload Size: $($resBytes.Length) bytes"

    if ($resBytes.Length -ge 5) {
        $compressed = $resBytes[0] -ne 0
        $msgLen = ($resBytes[1] -shl 24) -bor ($resBytes[2] -shl 16) -bor ($resBytes[3] -shl 8) -bor $resBytes[4]
        
        Write-Host "Compressed:       $compressed"
        Write-Host "Parsed Length:    $msgLen"
        
        if ($resBytes.Length -ge (5 + $msgLen)) {
            $data = [System.Text.Encoding]::UTF8.GetString($resBytes, 5, $msgLen)
            Write-Host "gRPC Message:     '$data'" -ForegroundColor Yellow
        }
    }
} catch {
    Write-Host "`n❌ Error sending request: $_" -ForegroundColor Red
} finally {
    $client.Dispose()
}
