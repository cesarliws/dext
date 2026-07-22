$ErrorActionPreference = "Stop"
$baseUrl = "http://localhost:8080"

Write-Host "[START] Testing Web.TaskFlowAPI on $baseUrl" -ForegroundColor Cyan

function Invoke-DextRequest {
    param (
        [string]$Uri,
        [string]$Method = "GET",
        [string]$Body = $null
    )
    try {
        $params = @{
            Uri             = $Uri
            Method          = $Method
            UseBasicParsing = $true
            ContentType     = "application/json"
        }
        if ($Body) { $params.Body = $Body }
        
        $resp = Invoke-WebRequest @params
        try { return ($resp.Content | ConvertFrom-Json) } catch { return $resp.Content }
    }
    catch {
        Write-Error "Request to $Uri failed: $($_.Exception.Message)"
        throw
    }
}

try {
    # 1. Root
    Write-Host "`n1. Testing Root..." -ForegroundColor Yellow
    $root = Invoke-DextRequest "$baseUrl/"
    Write-Host "   Message: $($root.message)"

    # 2. Get Tasks (Minimal API)
    Write-Host "`n2. Testing Get Tasks..." -ForegroundColor Yellow
    $tasks = Invoke-DextRequest "$baseUrl/api/tasks"
    # O exemplo retorna objeto plano: {"message": "Tasks endpoint", "count": 5}
    Write-Host "   Count: $($tasks.count)" 
    if ($tasks.count -ne 5) { Write-Warning "Expected count 5" }

    # 3. Get Task By ID (Minimal API: /api/tasks/{id})
    Write-Host "`n3. Testing Get Task/1..." -ForegroundColor Yellow
    $task1 = Invoke-DextRequest "$baseUrl/api/tasks/1"
    Write-Host "   Task: $($task1.title) (ID: $($task1.id))"
    if ($task1.id -ne 1) { throw "ID mismatch" }

    # 4. Create User (Injection Test)
    Write-Host "`n4. Testing Create User (DI Injection)..." -ForegroundColor Yellow
    $userBody = '{"Name": "John Task", "Email": "john@example.com"}'
    # POST /api/users
    $created = Invoke-DextRequest "$baseUrl/api/users" "POST" $userBody
    Write-Host "   Created User: $($created.name)"
    if ($created.name -ne "John Task") { throw "User creation failed" }

    Write-Host "`nSUCCESS: ALL TASKFLOW TESTS PASSED!" -ForegroundColor Green

}
catch {
    Write-Error "TEST FAILED: $_"
    exit 1
}
