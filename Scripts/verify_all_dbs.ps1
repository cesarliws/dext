$ErrorActionPreference = "Stop"

Write-Host "[START] Starting Multi-Database Verification..." -ForegroundColor Cyan

# Check if executable exists
$ExePath = "..\Examples\Output\Orm.EntityDemo.exe"
if (-not (Test-Path $ExePath)) {
    $ExePath = "..\Examples\Orm.EntityDemo\Orm.EntityDemo.exe"
}
if (-not (Test-Path $ExePath)) {
    Write-Error "Executable not found. Please build first."
}

# Define test matrix
$dbs = @(
    "SQLite",
    "PostgreSQL",
    "MySQL",
    "Firebird",
    "SQLServer"
)

$failed = @()

foreach ($db in $dbs) {
    Write-Host "`n========================================" -ForegroundColor Yellow
    Write-Host "testing Provider: $db" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    
    try {
        # Run process and wait
        $proc = Start-Process -FilePath $ExePath -ArgumentList $db -Wait -NoNewWindow -PassThru
        
        if ($proc.ExitCode -ne 0) {
            Write-Host "[FAIL] Tests FAILED for $db (Exit Code: $($proc.ExitCode))" -ForegroundColor Red
            $failed += $db
        } else {
            Write-Host "[PASS] Tests PASSED for $db" -ForegroundColor Green
        }
    } catch {
        Write-Host "[FAIL] Error executing test for $db : $_" -ForegroundColor Red
        $failed += $db
    }
}

Write-Host "`n----------------------------------------"
if ($failed.Count -eq 0) {
    Write-Host "[DONE] ALL DATABASE CHECKS PASSED!" -ForegroundColor Green
} else {
    Write-Host "[FAIL] SOME CHECKS FAILED: $($failed -join ', ')" -ForegroundColor Red
    exit 1
}
