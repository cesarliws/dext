# Test Script for Web.StreamingDemo
Add-Type -AssemblyName System.Net.Http

$BaseUrl = "http://localhost:8080"
$TestFile = "test_upload.txt"
$TestContent = "Hello Dext Streaming! " + (Get-Date).ToString()
$TestContent | Out-File -FilePath $TestFile -Encoding utf8

Write-Host "[*] Starting Streaming Demo Tests..." -ForegroundColor Cyan

try {
    # 1. Test Listing (should be empty or have files)
    Write-Host "[1] Checking file list..." -NoNewline
    $List = Invoke-RestMethod -Uri "$BaseUrl/download/list" -Method Get
    Write-Host " OK ($( $List.Count ) files found)" -ForegroundColor Green

    # 2. Test Upload
    Write-Host "[2] Uploading file..." -NoNewline
    
    $HttpClient = New-Object System.Net.Http.HttpClient
    $MultipartContent = New-Object System.Net.Http.MultipartFormDataContent
    $FileStream = [System.IO.File]::OpenRead((Get-Item $TestFile).FullName)
    $FileContent = New-Object System.Net.Http.StreamContent($FileStream)
    $MultipartContent.Add($FileContent, "myfile", $TestFile)
    
    $Task = $HttpClient.PostAsync("$BaseUrl/upload", $MultipartContent)
    $Response = $Task.Result
    $ResponseContent = $Response.Content.ReadAsStringAsync().Result
    $UploadResult = $ResponseContent | ConvertFrom-Json
    $FileStream.Close()
    $HttpClient.Dispose()

    if ($UploadResult.success) {
        Write-Host " OK (Saved as: $($UploadResult.filename))" -ForegroundColor Green
    } else {
        Write-Host " FAILED: $ResponseContent" -ForegroundColor Red
        exit 1
    }

    # 3. Test Download
    Write-Host "[3] Downloading file..." -NoNewline
    $DownloadedFile = "downloaded_test.txt"
    Invoke-WebRequest -Uri "$BaseUrl/download/$TestFile" -OutFile $DownloadedFile
    $DownloadedContent = Get-Content -Path $DownloadedFile -Raw
    
    if ($DownloadedContent.Trim() -eq $TestContent.Trim()) {
        Write-Host " OK (Content matches!)" -ForegroundColor Green
    } else {
        Write-Host " FAILED (Content mismatch)" -ForegroundColor Red
        Write-Host " Expected: $TestContent"
        Write-Host " Got: $DownloadedContent"
        exit 1
    }

    # 4. Clean up
    Remove-Item $TestFile
    Remove-Item $DownloadedFile
    Write-Host "[*] All tests passed successfully! [START]" -ForegroundColor Green

} catch {
    Write-Host "`n[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
