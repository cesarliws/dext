param(
    [ValidateSet('Win32', 'Win64')]
    [string]$Platform = 'Win64',
    [ValidateSet('Release', 'Debug')]
    [string]$Config = 'Release',
    [string]$Filter = 'BM_*',
    [ValidateRange(1, 100)]
    [int]$Repetitions = 10,
    [string]$OutputDirectory = ''
)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$repositoryRoot = Split-Path -Parent $scriptRoot
$environmentScript = Join-Path $repositoryRoot 'Scripts\set_env.ps1'
$projectFile = Join-Path $scriptRoot 'Dext.Benchmarks.dproj'
$executable = Join-Path $scriptRoot 'Dext.Benchmarks.exe'
$msbuild = 'C:\Windows\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe'

if (-not $OutputDirectory) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $OutputDirectory = Join-Path $scriptRoot "Results\S55\$stamp-$Platform"
}
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null

. $environmentScript -Platform $Platform -Config $Config -UseSourcePath:$false
& $msbuild $projectFile /t:Build "/p:Config=$Config" "/p:Platform=$Platform" /v:minimal /nologo
if ($LASTEXITCODE -ne 0) {
    throw "Benchmark build failed with exit code $LASTEXITCODE."
}

$resultFile = Join-Path $OutputDirectory 'results.json'
$metadataFile = Join-Path $OutputDirectory 'environment.json'
$arguments = @(
    "--benchmark_filter=$Filter",
    "--benchmark_repetitions=$Repetitions",
    "--benchmark_out=$resultFile",
    '--benchmark_out_format=json'
)

$processor = Get-CimInstance Win32_Processor | Select-Object -First 1
$operatingSystem = Get-CimInstance Win32_OperatingSystem
$commit = (& git -C $repositoryRoot rev-parse HEAD).Trim()
$branch = (& git -C $repositoryRoot branch --show-current).Trim()
$dirty = [bool](& git -C $repositoryRoot status --porcelain)
$metadata = [ordered]@{
    schema_version = 1
    captured_at_utc = (Get-Date).ToUniversalTime().ToString('o')
    commit = $commit
    branch = $branch
    working_tree_dirty = $dirty
    platform = $Platform
    configuration = $Config
    delphi_product_version = $env:PRODUCT_VERSION
    operating_system = $operatingSystem.Caption
    operating_system_version = $operatingSystem.Version
    cpu = $processor.Name.Trim()
    logical_processors = $processor.NumberOfLogicalProcessors
    physical_cores = $processor.NumberOfCores
    filter = $Filter
    repetitions = $Repetitions
    executable = $executable
    arguments = $arguments
}
$metadata | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $metadataFile -Encoding utf8

'' | & $executable @arguments
if ($LASTEXITCODE -ne 0) {
    throw "Benchmark execution failed with exit code $LASTEXITCODE."
}
if (-not (Test-Path -LiteralPath $resultFile)) {
    throw "Benchmark reporter did not create $resultFile."
}

Write-Host "S55 benchmark artifacts: $OutputDirectory"
