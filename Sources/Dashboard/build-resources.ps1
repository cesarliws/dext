param (
    [string]$OutputPath = ""
)

$ErrorActionPreference = "Stop"

$rcFile = Join-Path $PSScriptRoot "Dext.Dashboard.rc"
$resFile = Join-Path $PSScriptRoot "Dext.Dashboard.res"

# Function to find BRCC32
function Get-Brcc32Path {
    $brcc32 = Get-Command "brcc32.exe" -ErrorAction SilentlyContinue
    if ($brcc32) { return $brcc32.Source }
    
    # Common paths (adjust version if needed, searching generic areas)
    $searchPaths = @(
        "C:\Program Files (x86)\Embarcadero\Studio\*\bin\brcc32.exe",
        "C:\Program Files (x86)\Borland\Delphi*\Bin\brcc32.exe"
    )
    
    foreach ($path in $searchPaths) {
        $found = Get-ChildItem $path -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { return $found.FullName }
    }
    
    return $null
}

$brcc32Path = Get-Brcc32Path

if (!$brcc32Path) {
    Write-Error "brcc32.exe not found. Please add Delphi Bin directory to PATH."
}

Write-Host "Using compiler: $brcc32Path"

# Simple Minification (Regex based, very basic)
function Minify-Css($content) {
    return $content -replace '\s+', ' ' -replace '/\*.*?\*/', '' -replace ':\s+', ':' -replace '\s+\{', '{' -replace '\s+\}', '}'
}
function Minify-Js($content) {
    # Remove single line comments (careful with URLs) and whitespace
    # This is risky without a real parser, so for now just basic whitespace trimming
    return $content.Trim()
}

# We are using direct file resources, minification would require writing to temp files or piping.
# For Phase 0, we will skip complex minification to avoid breaking JS/CSS and just compile the source files.
# If minification is needed, we would create .min.css/.js files in a build step.

# Compile
Write-Host "Compiling $rcFile..."
& $brcc32Path $rcFile

if (Test-Path $resFile) {
    Write-Host "[PASS] Resource compiled successfully: $resFile"
    
    if (![string]::IsNullOrEmpty($OutputPath)) {
        if (-not (Test-Path $OutputPath)) {
            New-Item -ItemType Directory -Force -Path $OutputPath | Out-Null
        }
        Copy-Item -Path $resFile -Destination $OutputPath -Force
        Write-Host "[PASS] Copied to: $OutputPath"
    }
}
else {
    Write-Error "[FAIL] Failed to create $resFile"
}
