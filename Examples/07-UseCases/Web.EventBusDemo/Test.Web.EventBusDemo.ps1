# Test.Web.EventBusDemo.ps1
# Tests all endpoints of the Web Event Bus Demo API
# Make sure the server is running on http://localhost:8080

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$baseUrl = "http://localhost:8080"
$passed = 0
$failed = 0

Write-Host "================================================" -ForegroundColor Cyan
Write-Host " Dext Event Bus - Web Demo Test Suite" -ForegroundColor Cyan
Write-Host " Pattern: AddScopedEventBus (per-request scope)" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
# 1. Swagger availability
# ---------------------------------------------------------------------------
Write-Host "`n[TEST 1] Swagger UI (/swagger)..."
try {
    $resp = Invoke-WebRequest -Uri "$baseUrl/swagger" -Method Get -UseBasicParsing
    if ($resp.StatusCode -eq 200) {
        Write-Host "  PASS: Swagger UI is available" -ForegroundColor Green
        $passed++
    }
    else {
        Write-Host "  FAIL: Unexpected status $($resp.StatusCode)" -ForegroundColor Red
        $failed++
    }
}
catch {
    Write-Host "  FAIL: Could not reach /swagger. Is the server running? Error: $_" -ForegroundColor Red
    $failed++
}

# ---------------------------------------------------------------------------
# 2. Create a task (POST /api/tasks)
# ---------------------------------------------------------------------------
Write-Host "`n[TEST 2] Create Task (POST /api/tasks)..."
$taskId = $null
try {
    $body = @{
        title      = "Fix bug #42"
        assignedTo = "Alice"
    } | ConvertTo-Json

    $task = Invoke-RestMethod -Uri "$baseUrl/api/tasks" `
        -Method Post -Body $body -ContentType "application/json"

    if ($task.taskId -and $task.status -eq "Created") {
        $taskId = $task.taskId
        Write-Host "  PASS: Task created (id=$taskId, title='$($task.title)', assignedTo='$($task.assignedTo)')" -ForegroundColor Green
        Write-Host "        Message: $($task.message)"
        $passed++
    }
    else {
        Write-Host "  FAIL: Unexpected response: $($task | ConvertTo-Json -Compress)" -ForegroundColor Red
        $failed++
    }
}
catch {
    Write-Host "  FAIL: Error creating task: $_" -ForegroundColor Red
    $failed++
}

# ---------------------------------------------------------------------------
# 3. Create a second task
# ---------------------------------------------------------------------------
Write-Host "`n[TEST 3] Create Second Task (POST /api/tasks)..."
$taskId2 = $null
try {
    $body = @{
        title      = "Write unit tests"
        assignedTo = "Bob"
    } | ConvertTo-Json

    $task2 = Invoke-RestMethod -Uri "$baseUrl/api/tasks" `
        -Method Post -Body $body -ContentType "application/json"

    if ($task2.taskId -and $task2.status -eq "Created") {
        $taskId2 = $task2.taskId
        Write-Host "  PASS: Task created (id=$taskId2, title='$($task2.title)', assignedTo='$($task2.assignedTo)')" -ForegroundColor Green
        $passed++
    }
    else {
        Write-Host "  FAIL: Unexpected response: $($task2 | ConvertTo-Json -Compress)" -ForegroundColor Red
        $failed++
    }
}
catch {
    Write-Host "  FAIL: Error creating second task: $_" -ForegroundColor Red
    $failed++
}

# ---------------------------------------------------------------------------
# 4. Complete first task (PUT /api/tasks/{id}/complete)
# ---------------------------------------------------------------------------
Write-Host "`n[TEST 4] Complete Task (PUT /api/tasks/$taskId/complete)..."
if ($taskId) {
    try {
        $body = @{ completedBy = "Alice" } | ConvertTo-Json

        $completed = Invoke-RestMethod -Uri "$baseUrl/api/tasks/$taskId/complete" `
            -Method Put -Body $body -ContentType "application/json"

        if ($completed.status -eq "Completed") {
            Write-Host "  PASS: Task #$taskId completed (status='$($completed.status)')" -ForegroundColor Green
            Write-Host "        Message: $($completed.message)"
            $passed++
        }
        else {
            Write-Host "  FAIL: Expected status 'Completed', got '$($completed.status)'" -ForegroundColor Red
            $failed++
        }
    }
    catch {
        Write-Host "  FAIL: Error completing task: $_" -ForegroundColor Red
        $failed++
    }
}
else {
    Write-Host "  SKIP: No task ID from previous test" -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# 5. Cancel second task (DELETE /api/tasks/{id})
# ---------------------------------------------------------------------------
Write-Host "`n[TEST 5] Cancel Task (DELETE /api/tasks/$taskId2)..."
if ($taskId2) {
    try {
        $body = @{ reason = "Duplicate of task #$taskId" } | ConvertTo-Json

        $cancelled = Invoke-RestMethod -Uri "$baseUrl/api/tasks/$taskId2" `
            -Method Delete -Body $body -ContentType "application/json"

        if ($cancelled.status -eq "Cancelled") {
            Write-Host "  PASS: Task #$taskId2 cancelled (status='$($cancelled.status)')" -ForegroundColor Green
            Write-Host "        Message: $($cancelled.message)"
            $passed++
        }
        else {
            Write-Host "  FAIL: Expected status 'Cancelled', got '$($cancelled.status)'" -ForegroundColor Red
            $failed++
        }
    }
    catch {
        Write-Host "  FAIL: Error cancelling task: $_" -ForegroundColor Red
        $failed++
    }
}
else {
    Write-Host "  SKIP: No task ID from previous test" -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# 6. Verify 404 on unknown route
# ---------------------------------------------------------------------------
Write-Host "`n[TEST 6] Unknown route returns 404 (GET /api/nonexistent)..."
try {
    $resp = Invoke-WebRequest -Uri "$baseUrl/api/nonexistent" -Method Get -UseBasicParsing
    Write-Host "  FAIL: Expected 404 but got $($resp.StatusCode)" -ForegroundColor Red
    $failed++
}
catch {
    if ($_.Exception.Response.StatusCode.value__ -eq 404) {
        Write-Host "  PASS: GET /api/nonexistent correctly returns 404 (unknown route)" -ForegroundColor Green
        $passed++
    }
    else {
        Write-Host "  FAIL: Expected 404 but got: $_" -ForegroundColor Red
        $failed++
    }
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
Write-Host "`n================================================" -ForegroundColor Cyan
Write-Host " Results: $passed passed, $failed failed" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Red" })
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Tip: Check the server console for event handler log output." -ForegroundColor DarkGray
Write-Host "     TEventLoggingBehavior writes structured ILogger entries" -ForegroundColor DarkGray
Write-Host "     for every Publish call (Handling/Handled/Error)." -ForegroundColor DarkGray
