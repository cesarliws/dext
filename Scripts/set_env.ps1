# set_env.ps1 - Common environment setup for Dext Framework Build Scripts
# Replaces set_env.bat with a native PowerShell implementation.
#
# USAGE:
#   . .\set_env.ps1 [Platform] [Config] [DelphiVersion]
#
# EXAMPLES:
#   . .\set_env.ps1 Win32 Debug
#   . .\set_env.ps1 Win64 Release 37.0

param(
    [string]$Platform = "Win32",
    [string]$Config = "Debug",
    [string]$DelphiVersion = ""
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 1. Store inputs in environment variables (for MSBuild and other tools)
$env:PLATFORM = $Platform
$env:BUILD_CONFIG = $Config

# 2. Define Dext Root Path
$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
if (-not $PSScriptRoot) { $PSScriptRoot = Get-Location }
$DextRoot = (Get-Item (Join-Path $PSScriptRoot "..")).FullName
$env:DEXT = $DextRoot

# 3. Dynamic Delphi Discovery
function Get-DelphiInfo {
    param([string]$Version)
    
    $RegistryPaths = @(
        "HKLM:\SOFTWARE\Embarcadero\BDS",
        "HKLM:\SOFTWARE\WOW6432Node\Embarcadero\BDS"
    )

    $FoundVersions = @()
    foreach ($RegPath in $RegistryPaths) {
        if (Test-Path $RegPath) {
            Get-ChildItem -Path $RegPath -ErrorAction SilentlyContinue | ForEach-Object {
                if ($_.PSChildName -match '^\d+\.\d+$') {
                    $ver = $_.PSChildName
                    $rootDir = (Get-ItemProperty -Path $_.PSPath -Name "RootDir" -ErrorAction SilentlyContinue).RootDir
                    if ($rootDir -and (Test-Path $rootDir)) {
                        $FoundVersions += [PSCustomObject]@{ Version = $ver; RootDir = $rootDir }
                    }
                }
            }
        }
    }

    if ($FoundVersions.Count -eq 0) { return $null }
    
    if ($Version) {
        return $FoundVersions | Where-Object { $_.Version -eq $Version } | Select-Object -First 1
    }
    return ($FoundVersions | Sort-Object { [Version]$_.Version } -Descending)[0]
}

Write-Host "[ENV] Initializing Delphi environment..." -ForegroundColor Cyan
$DelphiInfo = Get-DelphiInfo -Version $DelphiVersion
if (-not $DelphiInfo) {
    Write-Error "Could not find Delphi installation."
    exit 1
}

$RSVars = Join-Path $DelphiInfo.RootDir "bin\rsvars.bat"
if (-not (Test-Path $RSVars)) {
    Write-Error "rsvars.bat not found at: $RSVars"
    exit 1
}

# 4. Sync rsvars.bat into current scope
$tempFile = [System.IO.Path]::GetTempFileName()
cmd /c "`"$RSVars`" && set > `"$tempFile`"" 2>$null
Get-Content $tempFile | ForEach-Object {
    if ($_ -match "^(.*?)=(.*)$") {
        $name = $Matches[1]
        $val = $Matches[2]
        
        # Access environment variable dynamically
        $currentVal = Get-Item -Path "Env:\$name" -ErrorAction SilentlyContinue
        if ($null -eq $currentVal -or $currentVal.Value -ne $val) {
            Set-Item -Path "Env:\$name" -Value $val
        }
    }
}
Remove-Item $tempFile -ErrorAction SilentlyContinue

# 5. Extract ProductVersion (e.g. 37.0)
$env:PRODUCT_VERSION = Split-Path $env:BDS -Leaf
$env:ProductVersion = $env:PRODUCT_VERSION

# 6. Standardize Paths
$env:BDSCOMMONDIR = (Get-Item "env:PUBLIC").Value + "\Documents\Embarcadero\Studio\$($env:PRODUCT_VERSION)"
$env:COMMON_BPL_OUTPUT = Join-Path $env:DEXT "Output\Bin\$($env:PRODUCT_VERSION)\$($env:PLATFORM)\$($env:BUILD_CONFIG)"
$env:COMMON_DCP_OUTPUT = Join-Path $env:DEXT "Output\Bin\$($env:PRODUCT_VERSION)\$($env:PLATFORM)\$($env:BUILD_CONFIG)"

if ($null -eq $env:DEXT_PROJECT_TYPE) { $env:DEXT_PROJECT_TYPE = "Framework" }

$ProjOutput = "Output"
if ($env:DEXT_PROJECT_TYPE -eq "Examples") { $ProjOutput = "Examples\Output" }
elseif ($env:DEXT_PROJECT_TYPE -eq "Tests") { $ProjOutput = "Tests\Output" }

$env:OUTPUT_PATH = Join-Path $env:DEXT "$ProjOutput\$($env:PRODUCT_VERSION)\$($env:PLATFORM)\$($env:BUILD_CONFIG)"

# 7. Context-Aware Search Paths
$FrameDCU = Join-Path $env:DEXT "Output\$($env:PRODUCT_VERSION)\$($env:PLATFORM)\$($env:BUILD_CONFIG)"
$FrameBin = Join-Path $env:DEXT "Output\Bin\$($env:PRODUCT_VERSION)\$($env:PLATFORM)\$($env:BUILD_CONFIG)"
$ExamplesDCU = Join-Path $env:DEXT "Examples\Output\$($env:PRODUCT_VERSION)\$($env:PLATFORM)\$($env:BUILD_CONFIG)"
$TestsDCU = Join-Path $env:DEXT "Tests\Output\$($env:PRODUCT_VERSION)\$($env:PLATFORM)\$($env:BUILD_CONFIG)"

# Root Sources included for Dext.inc
# We include External\DelphiAST sources because several internal tools and tests reference the units directly.
$ExtAST = Join-Path $env:DEXT "External\DelphiAST\Source"
$ExtParser = Join-Path $ExtAST "SimpleParser"
$env:SEARCH_PATH = "$($env:OUTPUT_PATH);$FrameDCU;$FrameBin;$ExamplesDCU;$TestsDCU;$($env:DEXT)\Sources;$($env:DEXT)\Sources\Common;$($env:DEXT)\Sources\Web;$($env:DEXT)\Sources\Server;$($env:DEXT)\Apps\CLI\Commands;$ExtAST;$ExtParser"

# 8. Create common directories
@($env:COMMON_BPL_OUTPUT, $env:COMMON_DCP_OUTPUT, $env:OUTPUT_PATH) | ForEach-Object {
    if (-not (Test-Path $_)) { New-Item -ItemType Directory -Path $_ -Force | Out-Null }
}

Write-Host "[ENV] Product Version: $($env:PRODUCT_VERSION)"
Write-Host "[ENV] Platform:        $($env:PLATFORM)"
Write-Host "[ENV] Configuration:   $($env:BUILD_CONFIG)"
Write-Host "[ENV] Output Path:     $($env:OUTPUT_PATH)"
Write-Host ""
