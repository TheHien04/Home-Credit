param(
    [Parameter(Mandatory)][string]$ServerInstance,
    [Parameter(Mandatory)][long]$BatchID,
    [Parameter(Mandatory)][string]$SourceRoot,
    [Parameter(Mandatory)][string]$WorkRoot,
    [int]$RowLimit = 0,
    [ValidateSet('All','PreviousApplication','BureauCredit','BureauBalance','NDS')][string]$Source = 'All'
)
$ErrorActionPreference = 'Stop'
if ($BatchID -le 0) { throw 'Supply the explicit shared BatchID; this script never selects MAX(BatchID).' }
if ($RowLimit -lt 0) { throw 'RowLimit cannot be negative.' }
if (-not (Get-Service -Name 'MsDtsServer160' -ErrorAction SilentlyContinue)) {
    throw 'The SQL Server 2022 Integration Services server runtime is not installed. Use Configure-Designer.ps1 and execute through Visual Studio. No file audit has been started.'
}
$taskVswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$taskVsRoot = & $taskVswhere -latest -products Microsoft.VisualStudio.Product.Community -property installationPath
$taskSsisRoot = Join-Path $taskVsRoot 'Common7/IDE/CommonExtensions/Microsoft/SSIS'
$env:PATH = (Join-Path $taskSsisRoot '160/Binn') + ';' + $env:PATH
$taskExecutable = Join-Path $PSScriptRoot 'bin/SsisTools.exe'
if (-not (Test-Path $taskExecutable)) { throw 'Run Build-Packages.ps1 first.' }
$taskProject = Get-ChildItem -LiteralPath $PSScriptRoot -Recurse -Filter 'Hop_CreditHistory.dtproj' | Select-Object -First 1
$taskPrepared = Join-Path $WorkRoot ("batch_$BatchID")
New-Item -ItemType Directory -Path $taskPrepared -Force | Out-Null
$taskSources = @(
    @{Name='PreviousApplication';File='previous_application.csv';Package='01_Load_PreviousApplication.dtsx'},
    @{Name='BureauCredit';File='bureau.csv';Package='02_Load_BureauCredit.dtsx'},
    @{Name='BureauBalance';File='bureau_balance.csv';Package='03_Load_BureauBalance.dtsx'}
)
if ($Source -eq 'NDS') {
    & $taskExecutable run $taskSsisRoot (Join-Path $taskProject.DirectoryName '04_Load_Validate_NDS.dtsx') $ServerInstance $BatchID $taskPrepared
    if ($LASTEXITCODE -ne 0) { throw 'NDS package failed. Check all seven staging inputs and DQ results.' }
    return
}
foreach ($taskSource in $taskSources) {
    if ($Source -ne 'All' -and $Source -ne $taskSource.Name) { continue }
    & python (Join-Path $PSScriptRoot 'prepare_source.py') (Join-Path $SourceRoot $taskSource.File) (Join-Path $taskPrepared $taskSource.File) --row-limit $RowLimit
    if ($LASTEXITCODE -ne 0) { throw "CSV preparation failed: $($taskSource.File)" }
    & $taskExecutable run $taskSsisRoot (Join-Path $taskProject.DirectoryName $taskSource.Package) $ServerInstance $BatchID $taskPrepared
    if ($LASTEXITCODE -ne 0) { throw "SSIS load failed: $($taskSource.File). Inspect audit and committed rows before retrying." }
}
