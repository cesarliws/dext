<#
.SYNOPSIS
    Cleans Delphi project (.dproj) and group (.groupproj) files using
    ProjectMagicianCmd.exe according to standard team configurations.
    Defaults to processing Packages\d13 relative to script location.
#>

param (
    [string]$TargetDir = "..\Packages\d13"
)

$ErrorActionPreference = "Continue"

$exePath = "C:\Program Files (x86)\ProjectMagician\ProjectMagicianCmd.exe"

if (-not (Test-Path $exePath)) {
    Write-Error "ProjectMagicianCmd.exe not found at: $exePath"
    exit 1
}

# Resolve target path relative to script directory if not rooted
if ([System.IO.Path]::IsPathRooted($TargetDir)) {
    $targetPath = $TargetDir
} else {
    $targetPath = Join-Path $PSScriptRoot $TargetDir
}

if (-not (Test-Path $targetPath)) {
    Write-Error "Target directory not found: $targetPath"
    exit 1
}

$resolvedDir = (Resolve-Path $targetPath).Path
Write-Host "Cleaning Delphi projects in: $resolvedDir" -ForegroundColor Cyan

# Find all .dproj and .groupproj files, ignoring .git folders
$files = Get-ChildItem -Path $resolvedDir -Recurse `
    -Include "*.dproj","*.groupproj" |
    Where-Object { $_.FullName -notmatch '\\\.git\\' }

$total = $files.Count
$current = 0
$errors = 0

Write-Host "Found $total project files." -ForegroundColor Yellow

foreach ($file in $files) {
    $current++
    $relPath = $file.FullName.Replace($resolvedDir, "")
    Write-Host "[$current/$total] Processing: $relPath" -ForegroundColor Gray

    # Pipe empty input so "press <enter> to continue" will not block
    $result = "" | & $exePath -n -r -x -d -uwp "$($file.FullName)" 2>&1

    if ($LASTEXITCODE -ne 0 -or $result -match "Error:") {
        $errors++
        Write-Host "  [WARN] Failed to process: $relPath" -ForegroundColor Red
    }
}

if ($errors -gt 0) {
    Write-Host "Completed with $errors warnings/errors." -ForegroundColor Yellow
} else {
    Write-Host "All $total projects cleaned successfully!" -ForegroundColor Green
}
