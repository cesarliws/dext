# Script to update all public symbol index files (Markdown, JSON, CSV)
# Usage: .\Scripts\update_symbols.ps1

$ErrorActionPreference = "Stop"
$Root = Resolve-Path "$PSScriptRoot\.."
$DextTool = "$Root\Apps\dext.exe"

# Fallback to system path if not found in Apps directory
if (-not (Test-Path $DextTool)) {
    $DextTool = "dext"
}

Write-Host "Updating Public Symbol Maps..." -ForegroundColor Cyan

# 1. Generate Markdown
Write-Host "Generating Markdown index (dext-symbols.md)..." -ForegroundColor Yellow
& $DextTool index -p "$Root\Sources" -f markdown -o "$Root\dext-symbols.md"

# 2. Generate JSON
Write-Host "Generating JSON index (dext-symbols.json)..." -ForegroundColor Yellow
& $DextTool index -p "$Root\Sources" -f json -o "$Root\dext-symbols.json"

# 3. Generate CSV
Write-Host "Generating CSV index (dext-symbols.csv)..." -ForegroundColor Yellow
& $DextTool index -p "$Root\Sources" -f csv -o "$Root\dext-symbols.csv"

Write-Host "All public symbol maps updated successfully!" -ForegroundColor Green
