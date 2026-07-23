#Requires -Version 5.1
<#
.SYNOPSIS
    Synchronizes legacy Delphi package files from the most recent version folder.

.DESCRIPTION
    Self-contained implementation of S38 - Legacy Package Synchronization.
    Copies .dpk, .dproj, .res and DextFramework.groupproj files from the most
    recent Delphi version folder (currently d13) to all legacy version folders,
    applying the minimum required substitutions per version.

    Rules applied (see Docs/Specs/S38-Legacy-Package-Sync.md):
      - .dpk       : copied verbatim; {$LIBSUFFIX AUTO} replaced for pre-Sydney
      - .dproj     : copied with output path and DllSuffix substitutions
      - .groupproj : copied verbatim
      - .res       : copied verbatim
      - .dproj.local : NOT copied (user-local, not version-controlled)

.NOTES
    Author : Cesar Romero & Antigravity
    Spec   : S38-Legacy-Package-Sync.md
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# 1. Paths
# ---------------------------------------------------------------------------
$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RepoRoot   = (Resolve-Path (Join-Path $ScriptDir '..')).Path
$PackagesDir = Join-Path $RepoRoot 'Packages'

# ---------------------------------------------------------------------------
# 2. Version metadata table
#
#  Folder         : target subfolder inside Packages/
#  ProductVersion : value to substitute for $(ProductVersion) in output paths
#  DllSuffix      : literal DllSuffix value (empty string = keep $(Auto))
#  UseAutoSuffix  : $true      keep $(Auto) in .dproj and {$LIBSUFFIX AUTO} in .dpk
#                   $false     replace with DllSuffix literal
# ---------------------------------------------------------------------------
$Versions = @(
    # Versions that natively support $(ProductVersion) and $(Auto)     Sydney+
    [PSCustomObject]@{ Folder = 'd12';      ProductVersion = '23.0'; DllSuffix = '';    UseAutoSuffix = $true  }
    [PSCustomObject]@{ Folder = 'd11';      ProductVersion = '22.0'; DllSuffix = '';    UseAutoSuffix = $true  }
    [PSCustomObject]@{ Folder = 'dsydney';  ProductVersion = '21.0'; DllSuffix = '';    UseAutoSuffix = $true  }
    # Versions that require literal substitution     pre-Sydney
    [PSCustomObject]@{ Folder = 'drio';     ProductVersion = '20.0'; DllSuffix = '260'; UseAutoSuffix = $false }
    [PSCustomObject]@{ Folder = 'dtokyo';   ProductVersion = '19.0'; DllSuffix = '250'; UseAutoSuffix = $false }
    [PSCustomObject]@{ Folder = 'dberlin';  ProductVersion = '18.0'; DllSuffix = '240'; UseAutoSuffix = $false }
    [PSCustomObject]@{ Folder = 'dseattle'; ProductVersion = '17.0'; DllSuffix = '230'; UseAutoSuffix = $false }
    [PSCustomObject]@{ Folder = 'dxe8';     ProductVersion = '16.0'; DllSuffix = '220'; UseAutoSuffix = $false }
    [PSCustomObject]@{ Folder = 'dxe7';     ProductVersion = '15.0'; DllSuffix = '210'; UseAutoSuffix = $false }
    [PSCustomObject]@{ Folder = 'dxe6';     ProductVersion = '14.0'; DllSuffix = '200'; UseAutoSuffix = $false }
    [PSCustomObject]@{ Folder = 'dxe5';     ProductVersion = '12.0'; DllSuffix = '190'; UseAutoSuffix = $false }
    [PSCustomObject]@{ Folder = 'dxe4';     ProductVersion = '11.0'; DllSuffix = '180'; UseAutoSuffix = $false }
    [PSCustomObject]@{ Folder = 'dxe3';     ProductVersion = '10.0'; DllSuffix = '170'; UseAutoSuffix = $false }
    [PSCustomObject]@{ Folder = 'dxe2';     ProductVersion = '9.0';  DllSuffix = '160'; UseAutoSuffix = $false }
)

# ---------------------------------------------------------------------------
# 3. Locate source folder (most recent version = highest d<N> folder)
# ---------------------------------------------------------------------------
function Find-SourceFolder {
    param([string]$PackagesRoot)

    # Find all d<digits> folders, pick the one with the highest number
    $candidates = Get-ChildItem -Path $PackagesRoot -Directory |
        Where-Object { $_.Name -match '^d(\d+)$' } |
        Sort-Object { [int]($_.Name -replace '^d', '') } -Descending

    if (-not $candidates) {
        throw "No versioned package folders (d<N>) found under '$PackagesRoot'."
    }

    return $candidates[0].FullName
}

# ---------------------------------------------------------------------------
# 4. Helper: apply substitutions to .dproj content
# ---------------------------------------------------------------------------
function Convert-DprojContent {
    param(
        [string]$Content,
        [string]$ProductVersion,
        [bool]  $UseAutoSuffix,
        [string]$DllSuffix
    )

    # --- Output path substitution ---
    # Tags where $(ProductVersion) must be replaced with the literal value
    $outputTags = @(
        'DCC_DcuOutput'
        'DCC_DcpOutput'
        'DCC_BplOutput'
        'DCC_ExeOutput'
        'DCC_BpiOutput'
        'DCC_HppOutput'
        'DCC_ObjOutput'
        'BRCC_OutputDir'
    )

    foreach ($tag in $outputTags) {
        # Replace $(ProductVersion) within the specific tag only
        $Content = $Content -replace "(<$tag>[^<]*)\`$\(ProductVersion\)([^<]*</$tag>)",
                                     "`${1}$ProductVersion`${2}"
    }

    # --- DllSuffix substitution (only for pre-Sydney) ---
    if (-not $UseAutoSuffix) {
        # Replace <DllSuffix>$(Auto)</DllSuffix> with the literal value
        $Content = $Content -replace '<DllSuffix>\$\(Auto\)</DllSuffix>',
                                     "<DllSuffix>$DllSuffix</DllSuffix>"
    }

    return $Content
}

# ---------------------------------------------------------------------------
# 5. Helper: apply substitutions to .dpk content
# ---------------------------------------------------------------------------
function Convert-DpkContent {
    param(
        [string]$Content,
        [bool]  $UseAutoSuffix,
        [string]$DllSuffix
    )

    if (-not $UseAutoSuffix) {
        # Replace {$LIBSUFFIX AUTO} with {$LIBSUFFIX '<numeric>'}
        $Content = $Content -replace '\{\$LIBSUFFIX AUTO\}',
                                     "{`$LIBSUFFIX '$DllSuffix'}"
    }

    return $Content
}

# ---------------------------------------------------------------------------
# 6. Validate that a path looks like a correct two-level-up output path
# ---------------------------------------------------------------------------
function Assert-NoBadPaths {
    param([string]$FilePath, [string]$Content)

    # If any 3-level-up path appears in an output tag, something went wrong
    $badPattern = '<(?:DCC_DcuOutput|DCC_DcpOutput|DCC_BplOutput|DCC_BplOutput)>[^<]*\.\.\\\.\.\\\.\.\\'
    if ($Content -match $badPattern) {
        throw "Validation failed: file '$FilePath' contains a 3-level relative output path. Aborting."
    }
}

# ---------------------------------------------------------------------------
# 7. Main
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '========================================================' -ForegroundColor Cyan
Write-Host '  Dext Legacy Package Synchronization  (S38)' -ForegroundColor Cyan
Write-Host '========================================================' -ForegroundColor Cyan
Write-Host ''

# --- Phase 2: Locate and validate source folder ---
$SourceDir = Find-SourceFolder -PackagesRoot $PackagesDir
$SourceName = Split-Path -Leaf $SourceDir

Write-Host "Source (most recent version) : $SourceName" -ForegroundColor Green
Write-Host "Repository root              : $RepoRoot"
Write-Host ''

# Validate required source files exist
$requiredFiles = @('DextFramework.groupproj')
foreach ($f in $requiredFiles) {
    $fp = Join-Path $SourceDir $f
    if (-not (Test-Path $fp)) {
        throw "Required source file missing: '$fp'"
    }
}

$sourceDpk   = Get-ChildItem -Path $SourceDir -Filter '*.dpk'
$sourceDproj = Get-ChildItem -Path $SourceDir -Filter '*.dproj'
$sourceRes   = Get-ChildItem -Path $SourceDir -Filter '*.res'

if ($sourceDpk.Count -eq 0) {
    throw "No .dpk files found in source folder '$SourceDir'."
}
if ($sourceDproj.Count -eq 0) {
    throw "No .dproj files found in source folder '$SourceDir'."
}

Write-Host "Files to process per version:" -ForegroundColor Yellow
Write-Host "  .dpk    : $($sourceDpk.Count)"
Write-Host "  .dproj  : $($sourceDproj.Count)"
Write-Host "  .res    : $($sourceRes.Count)"
Write-Host "  .groupproj : 1"
Write-Host ''

# --- Summary counters ---
$totalVersions = 0
$totalFiles    = 0

# --- Phase 3 & 4: Process each target version ---
foreach ($ver in $Versions) {

    $targetDir = Join-Path $PackagesDir $ver.Folder

    Write-Host "+-- [$($ver.Folder)]" -ForegroundColor Cyan
    Write-Host "|  ProductVersion = $($ver.ProductVersion)  |  AutoSuffix = $($ver.UseAutoSuffix)  |  DllSuffix = $($ver.DllSuffix)"

    # Phase 3: Clean and (re)create target folder
    if (Test-Path $targetDir) {
        # Remove only the files we manage; leave any untracked files alone
        Get-ChildItem -Path $targetDir -File | Where-Object {
            $_.Extension -in @('.dpk', '.dproj', '.res') -or
            $_.Name -eq 'DextFramework.groupproj'
        } | Remove-Item -Force
        Write-Host "|  Cleaned managed files in existing folder."
    } else {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        Write-Host "|  Created folder."
    }

    $fileCount = 0

    # --- Copy DextFramework.groupproj verbatim ---
    $srcGroupProj = Join-Path $SourceDir 'DextFramework.groupproj'
    $dstGroupProj = Join-Path $targetDir 'DextFramework.groupproj'
    Copy-Item -Path $srcGroupProj -Destination $dstGroupProj -Force
    $fileCount++

    # --- Copy .res files verbatim ---
    foreach ($res in $sourceRes) {
        Copy-Item -Path $res.FullName -Destination (Join-Path $targetDir $res.Name) -Force
        $fileCount++
    }

    # --- Copy and adapt .dpk files ---
    foreach ($dpk in $sourceDpk) {
        $content = [System.IO.File]::ReadAllText($dpk.FullName, [System.Text.Encoding]::UTF8)
        $adapted = Convert-DpkContent -Content $content -UseAutoSuffix $ver.UseAutoSuffix -DllSuffix $ver.DllSuffix
        $dstPath = Join-Path $targetDir $dpk.Name
        [System.IO.File]::WriteAllText($dstPath, $adapted, [System.Text.Encoding]::UTF8)
        $fileCount++
    }

    # --- Copy and adapt .dproj files ---
    foreach ($dproj in $sourceDproj) {
        $content = [System.IO.File]::ReadAllText($dproj.FullName, [System.Text.Encoding]::UTF8)
        $adapted = Convert-DprojContent `
            -Content        $content `
            -ProductVersion $ver.ProductVersion `
            -UseAutoSuffix  $ver.UseAutoSuffix `
            -DllSuffix      $ver.DllSuffix

        # Validate output before writing
        $dstPath = Join-Path $targetDir $dproj.Name
        Assert-NoBadPaths -FilePath $dstPath -Content $adapted

        [System.IO.File]::WriteAllText($dstPath, $adapted, [System.Text.Encoding]::UTF8)
        $fileCount++
    }

    Write-Host "|  $fileCount files written." -ForegroundColor Green
    Write-Host "+--"
    Write-Host ''

    $totalVersions++
    $totalFiles += $fileCount
}

# ---------------------------------------------------------------------------
# 8. Final report
# ---------------------------------------------------------------------------
Write-Host '========================================================' -ForegroundColor Green
Write-Host "  Done.  $totalVersions version folders updated.  $totalFiles total files written." -ForegroundColor Green
Write-Host '========================================================' -ForegroundColor Green
Write-Host ''
