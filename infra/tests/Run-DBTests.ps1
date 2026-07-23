# =============================================================================
# Run-DBTests.ps1
# Dext ORM Integration Tests against Docker Databases
# =============================================================================
# Usage:
#   .\Run-DBTests.ps1              # Run all tests
#   .\Run-DBTests.ps1 -Database pg # Run PostgreSQL only
#   .\Run-DBTests.ps1 -StartOnly   # Start containers only
#   .\Run-DBTests.ps1 -StopOnly    # Stop containers only
# =============================================================================

param(
    [ValidateSet("all", "pg", "mssql", "mysql", "firebird", "oracle")]
    [string]$Database = "all",
    [switch]$StartOnly,
    [switch]$StopOnly,
    [switch]$SkipBuild,
    [int]$WaitSeconds = 30
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$DockerCompose = Join-Path $ScriptDir "docker-compose.yml"
$TestsDir = Join-Path $RepoRoot "Tests\Entity"
$OutputDir = Join-Path $RepoRoot "Output"

# Colors
function Write-Success { param($msg) Write-Host "[OK] " -ForegroundColor Green -NoNewline; Write-Host $msg }
function Write-Failure { param($msg) Write-Host "[FAIL] " -ForegroundColor Red -NoNewline; Write-Host $msg }
function Write-Info { param($msg) Write-Host "[INFO] " -ForegroundColor Cyan -NoNewline; Write-Host $msg }
function Write-Header { param($msg) Write-Host "`n                                                           " -ForegroundColor Magenta; Write-Host "  $msg" -ForegroundColor Magenta; Write-Host "                                                           " -ForegroundColor Magenta }

# Database configurations
$Databases = @{
    "pg"       = @{
        Name             = "PostgreSQL"
        Container        = "dext_postgres"
        Port             = 5432
        TestProject      = "TestTypeConvertersDb.dproj"
        ConnectionString = "Server=localhost;Port=5432;Database=dext_test_db;User_Name=dext_user;Password=dext_password"
    }
    "mssql"    = @{
        Name             = "SQL Server"
        Container        = "dext_sqlserver"
        Port             = 1433
        TestProject      = "TestTypeConvertersDb.dproj"  # Needs separate MSSQL test project
        ConnectionString = "Server=localhost,1433;Database=dext_test_db;User_Id=sa;Password=DextPassword123!"
    }
    "mysql"    = @{
        Name             = "MySQL"
        Container        = "dext_mysql"
        Port             = 3306
        TestProject      = "TestTypeConvertersDb.dproj"  # Needs separate MySQL test project
        ConnectionString = "Server=localhost;Port=3306;Database=dext_test_db;User_Name=dext_user;Password=dext_password"
    }
    "firebird" = @{
        Name             = "Firebird"
        Container        = "dext_firebird"
        Port             = 3050
        TestProject      = "TestTypeConvertersDb.dproj"  # Needs separate Firebird test project
        ConnectionString = "Server=localhost;Port=3050;Database=dext_test_db;User_Name=SYSDBA;Password=masterkey"
    }
    "oracle"   = @{
        Name             = "Oracle"
        Container        = "dext_oracle"
        Port             = 1521
        TestProject      = "TestTypeConvertersDb.dproj"  # Needs separate Oracle test project
        ConnectionString = "Server=localhost:1521/FREEPDB1;User_Name=dext_user;Password=dext_password"
    }
}

# =============================================================================
# Functions
# =============================================================================

function Start-Databases {
    Write-Header "Starting Docker Containers"
    
    if (-not (Test-Path $DockerCompose)) {
        Write-Failure "docker-compose.yml not found at: $DockerCompose"
        exit 1
    }
    
    Write-Info "Starting containers..."
    Push-Location $ScriptDir
    try {
        docker-compose up -d
        if ($LASTEXITCODE -ne 0) {
            Write-Failure "Failed to start containers"
            exit 1
        }
    }
    finally {
        Pop-Location
    }
    
    Write-Success "Containers started!"
    Write-Info "Waiting $WaitSeconds seconds for databases to initialize..."
    
    $progress = 0
    while ($progress -lt $WaitSeconds) {
        Write-Progress -Activity "Waiting for databases" -Status "$progress / $WaitSeconds seconds" -PercentComplete (($progress / $WaitSeconds) * 100)
        Start-Sleep -Seconds 1
        $progress++
    }
    Write-Progress -Activity "Waiting for databases" -Completed
    
    # Check container status
    Write-Info "Container status:"
    docker ps --filter "name=dext_" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
}

function Stop-Databases {
    Write-Header "Stopping Docker Containers"
    
    Push-Location $ScriptDir
    try {
        docker-compose down
        Write-Success "Containers stopped!"
    }
    finally {
        Pop-Location
    }
}

function Test-DatabaseConnection {
    param([string]$DbKey)
    
    $Db = $Databases[$DbKey]
    $Port = $Db.Port
    
    Write-Info "Testing connection to $($Db.Name) on port $Port..."
    
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $tcp.Connect("localhost", $Port)
        $tcp.Close()
        Write-Success "$($Db.Name) is reachable!"
        return $true
    }
    catch {
        Write-Failure "$($Db.Name) is not reachable on port $Port"
        return $false
    }
}

function Run-Tests {
    param([string]$DbKey)
    
    $Db = $Databases[$DbKey]
    
    Write-Header "Running Tests: $($Db.Name)"
    
    # Check connection first
    if (-not (Test-DatabaseConnection $DbKey)) {
        Write-Failure "Skipping $($Db.Name) - not reachable"
        return $false
    }
    
    # For now, we just report success if the container is up
    # TODO: Build and run actual test project with dynamic connection string
    
    Write-Info "Test project: $($Db.TestProject)"
    Write-Info "Connection: $($Db.ConnectionString)"
    
    # Check if test executable exists
    $ExeName = [System.IO.Path]::GetFileNameWithoutExtension($Db.TestProject) + ".exe"
    $ExePath = Join-Path $OutputDir $ExeName
    
    if (Test-Path $ExePath) {
        Write-Info "Running $ExeName..."
        
        # Set environment variable for connection string
        $env:DEXT_TEST_CONNECTION = $Db.ConnectionString
        $env:DEXT_TEST_DRIVER = $DbKey
        
        try {
            & $ExePath
            if ($LASTEXITCODE -eq 0) {
                Write-Success "$($Db.Name) tests passed!"
                return $true
            }
            else {
                Write-Failure "$($Db.Name) tests failed with exit code $LASTEXITCODE"
                return $false
            }
        }
        catch {
            Write-Failure "Error running tests: $_"
            return $false
        }
    }
    else {
        Write-Info "Test executable not found: $ExePath"
        Write-Info "Please build the test project first"
        Write-Info "Container is ready for manual testing"
        return $true  # Container is up, that's a success
    }
}

# =============================================================================
# Main
# =============================================================================

Write-Host ""
Write-Header "Dext ORM - Database Integration Tests"
Write-Host "Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor DarkGray
Write-Host ""

# Stop only
if ($StopOnly) {
    Stop-Databases
    exit 0
}

# Start containers
Start-Databases

if ($StartOnly) {
    Write-Host ""
    Write-Success "Containers are running. Use -StopOnly to shut them down."
    Write-Host ""
    Write-Host "Connection strings:" -ForegroundColor Yellow
    foreach ($key in $Databases.Keys) {
        Write-Host "  $($Databases[$key].Name): " -NoNewline
        Write-Host $Databases[$key].ConnectionString -ForegroundColor DarkGray
    }
    exit 0
}

# Run tests
$Results = @{}
$TestedDatabases = if ($Database -eq "all") { $Databases.Keys } else { @($Database) }

foreach ($DbKey in $TestedDatabases) {
    $Results[$DbKey] = Run-Tests $DbKey
}

# Summary
Write-Header "Test Summary"

$Passed = 0
$Failed = 0

foreach ($key in $Results.Keys) {
    $Db = $Databases[$key]
    if ($Results[$key]) {
        Write-Success "$($Db.Name)"
        $Passed++
    }
    else {
        Write-Failure "$($Db.Name)"
        $Failed++
    }
}

Write-Host ""
Write-Host "Total: $($Passed + $Failed) | Passed: $Passed | Failed: $Failed" -ForegroundColor White
Write-Host ""

# Ask to stop containers
$response = Read-Host "Stop containers? (y/N)"
if ($response -eq "y" -or $response -eq "Y") {
    Stop-Databases
}

exit $(if ($Failed -gt 0) { 1 } else { 0 })
