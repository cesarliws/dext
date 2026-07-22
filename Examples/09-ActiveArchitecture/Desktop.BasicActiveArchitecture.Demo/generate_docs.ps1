<#
.SYNOPSIS
    Generates dynamic API documentation for the Active Architecture Demo and opens it.
.DESCRIPTION
    Runs `dext.exe doc` command and instantly showcases the live documentation.
#>

$ErrorActionPreference = "Stop"

# Clear host to look extremely clean in the terminal
Clear-Host

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "   Dext Live Documentation Generator - Show Case" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Resolve Dext executable location
$DextExe = "dext" # Default fallback in system PATH
$LocalLocations = @(
    "$PSScriptRoot\..\..\..\Apps\dext.exe",
    "C:\dev\Dext\DextRepository\Apps\dext.exe"
)

foreach ($loc in $LocalLocations) {
    if (Test-Path $loc) {
        $DextExe = Resolve-Path $loc
        break
    }
}

# 2. Setup Input and Output
$InputPath = "$PSScriptRoot"
$OutputPath = Join-Path $PSScriptRoot "docs"
$Title = "Dext Active Architecture"

Write-Host "Analyzing Active Architecture codebase..." -ForegroundColor Gray
Write-Host "Source Path: $InputPath" -ForegroundColor DarkGray
Write-Host "Output Path: $OutputPath" -ForegroundColor DarkGray
Write-Host ""

# Ensure output dir is clean
if (Test-Path $OutputPath) {
    Remove-Item -Path $OutputPath -Recurse -Force | Out-Null
}
New-Item -ItemType Directory -Force -Path $OutputPath | Out-Null

# 3. Execute documentation generation
Write-Host ">> Executing: dext.exe doc" -ForegroundColor Yellow
try {
    & $DextExe doc --title "$Title" --input "$InputPath" --output "$OutputPath"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "* Success! Live documentation generated successfully!" -ForegroundColor Green
        Write-Host "[START] Launching responsive HTML portal in browser..." -ForegroundColor Green
        
        $IndexHtml = Join-Path $OutputPath "index.html"
        if (Test-Path $IndexHtml) {
            Start-Process $IndexHtml
        }
    }
    else {
        Write-Host "`n[ERROR] Generation failed. CLI Exit Code: $LASTEXITCODE" -ForegroundColor Red
    }
}
catch {
    Write-Error "An unexpected error occurred during execution: $_"
}
