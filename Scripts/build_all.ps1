# build_all.ps1 - Orchestrates the build of the entire Dext Framework
# Replaces build_framework.bat, build_framework_x64.bat, and build_framework_linux.bat.
#
# USAGE:
#   .\build_all.ps1 [-Platform Win32|Win64|Linux64] [-Config Debug|Release] [-Clean]
#
# EXAMPLES:
#   .\build_all.ps1                   # Win32 Debug (Default)
#   .\build_all.ps1 -Platform Win64    # Win64 Debug
#   .\build_all.ps1 -Platform Linux64  # Linux64 Debug
#   .\build_all.ps1 -Config Release    # Win32 Release

param(
    [ValidateSet("Win32", "Win64", "Linux64")]
    [string]$Platform = "Win32",
    
    [ValidateSet("Debug", "Release")]
    [string]$Config = "Debug",
    
    [string]$DelphiVersion = "",
    
    [switch]$Clean
)

$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
if (-not $PSScriptRoot) { $PSScriptRoot = Get-Location }

# 1. Setup Environment from set_env.ps1
$env:DEXT_PROJECT_TYPE = "Framework"
. "$PSScriptRoot\set_env.ps1" -Platform $Platform -Config $Config -DelphiVersion $DelphiVersion

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Building Dext Framework ($Platform $Config)" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 2. Build via groupproj (Preferred for dependency order)
if ($env:PRODUCT_VERSION) {
    $MajorVer = [int]($env:PRODUCT_VERSION.Split('.')[0])
    $FolderNum = $MajorVer - 24
    $TargetFolder = "d$FolderNum"
    $GroupProj = Join-Path $env:DEXT "Packages\$TargetFolder\DextFramework.groupproj"
} else {
    $GroupProj = ""
}

if (-not $GroupProj -or -not (Test-Path $GroupProj)) {
    $found = Get-ChildItem -Path (Join-Path $env:DEXT "Packages") -Recurse -Filter "DextFramework.groupproj" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) {
        $GroupProj = $found.FullName
    } else {
        Write-Error "DextFramework.groupproj not found in Packages directory."
        exit 1
    }
}

if ($Clean) {
    Write-Host "`n[CLEAN] Cleaning project group..." -ForegroundColor Yellow
    msbuild "$GroupProj" /t:Clean /p:Configuration=$env:BUILD_CONFIG /p:Platform=$env:PLATFORM /v:minimal /nologo
}

Write-Host "`n[BUILD] Compiling project group..." -ForegroundColor Yellow
$MSBuildArgs = @(
    $GroupProj,
    "/t:Build",
    "/p:Configuration=$env:BUILD_CONFIG",
    "/p:Config=$env:BUILD_CONFIG",
    "/p:Platform=$env:PLATFORM",
    "/p:ProductVersion=$env:PRODUCT_VERSION",
    "/p:DCC_DcuOutput=`"$env:OUTPUT_PATH`"",
    "/p:DCC_BplOutput=`"$env:COMMON_BPL_OUTPUT`"",
    "/p:DCC_DcpOutput=`"$env:COMMON_DCP_OUTPUT`"",
    "/p:DCC_UnitSearchPath=`"$env:OUTPUT_PATH;C:\dev\Dext\DextRepository\Sources;C:\dev\Dext\DextRepository\Sources\Dashboard;C:\dev\Dext\DextRepository\External\DelphiAST\Source;C:\dev\Dext\DextRepository\External\DelphiAST\Source\SimpleParser;C:\dev\Dext\DextRepository\Sources\Common`"",
    "/v:minimal",
    "/nologo"
)

$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
& msbuild @MSBuildArgs
$BuildExitCode = $LASTEXITCODE
$Stopwatch.Stop()

# 3. Post-Build: Rename CLI Tool if it exists in the output
if ($BuildExitCode -eq 0) {
    $DextToolExe = Join-Path $env:OUTPUT_PATH "DextTool.exe"
    if (Test-Path $DextToolExe) {
         Write-Host "`n[POST] Renaming DextTool.exe to dext.exe" -ForegroundColor Gray
         Move-Item -Path $DextToolExe -Destination (Join-Path $env:OUTPUT_PATH "dext.exe") -Force
    }
}

Write-Host "`n==========================================" -ForegroundColor Cyan
if ($BuildExitCode -eq 0) {
    Write-Host "BUILD SUCCESSFUL" -ForegroundColor Green
    Write-Host "Time: $([math]::Round($Stopwatch.Elapsed.TotalSeconds, 1))s" -ForegroundColor Gray
    Write-Host "Output: $env:OUTPUT_PATH" -ForegroundColor Gray
} else {
    Write-Host "BUILD FAILED" -ForegroundColor Red
}
Write-Host "==========================================" -ForegroundColor Cyan

exit $BuildExitCode
