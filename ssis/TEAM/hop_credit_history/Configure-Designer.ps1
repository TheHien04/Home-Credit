param(
    [Parameter(Mandatory)][string]$ServerInstance,
    [Parameter(Mandatory)][long]$BatchID,
    [Parameter(Mandatory)][string]$SourceRoot,
    [Parameter(Mandatory)][string]$WorkRoot,
    [int]$RowLimit = 0
)
$ErrorActionPreference = 'Stop'
if ($BatchID -le 0 -or $RowLimit -lt 0) { throw 'Provide an explicit BatchID and a nonnegative RowLimit.' }
$taskVswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$taskVsRoot = & $taskVswhere -latest -products Microsoft.VisualStudio.Product.Community -property installationPath
$taskSsisRoot = Join-Path $taskVsRoot 'Common7/IDE/CommonExtensions/Microsoft/SSIS'
$env:PATH = (Join-Path $taskSsisRoot '160/Binn') + ';' + $env:PATH
$taskExecutable = Join-Path $PSScriptRoot 'bin/SsisTools.exe'
$taskProject = Get-ChildItem -LiteralPath $PSScriptRoot -Recurse -Filter 'Hop_CreditHistory.dtproj' | Select-Object -First 1
$taskPrepared = Join-Path $WorkRoot ("batch_$BatchID")
foreach ($taskFile in @('previous_application.csv','bureau.csv','bureau_balance.csv')) {
    & python (Join-Path $PSScriptRoot 'prepare_source.py') (Join-Path $SourceRoot $taskFile) (Join-Path $taskPrepared $taskFile) --row-limit $RowLimit
    if ($LASTEXITCODE -ne 0) { throw "Cannot prepare CSV: $taskFile" }
}
$taskProjectXml = [xml](Get-Content -LiteralPath $taskProject.FullName -Raw)
$taskNs = New-Object System.Xml.XmlNamespaceManager($taskProjectXml.NameTable)
$taskNs.AddNamespace('SSIS','www.microsoft.com/SqlServer/SSIS')
foreach ($taskPackage in $taskProjectXml.SelectNodes('//SSIS:Packages/SSIS:Package',$taskNs)) {
    $taskName = $taskPackage.GetAttribute('Name','www.microsoft.com/SqlServer/SSIS')
    $taskLocalName = $taskName.Replace('.dtsx','.local.dtsx')
    & $taskExecutable configure $taskSsisRoot (Join-Path $taskProject.DirectoryName $taskName) $ServerInstance $BatchID $taskPrepared (Join-Path $taskProject.DirectoryName $taskLocalName)
    if ($LASTEXITCODE -ne 0) { throw "Cannot configure package: $taskName" }
    [void]$taskPackage.SetAttribute('Name','www.microsoft.com/SqlServer/SSIS',$taskLocalName)
    foreach ($taskMetadata in $taskProjectXml.SelectNodes('//SSIS:PackageMetaData',$taskNs)) {
        if ($taskMetadata.GetAttribute('Name','www.microsoft.com/SqlServer/SSIS') -eq $taskName) {
            [void]$taskMetadata.SetAttribute('Name','www.microsoft.com/SqlServer/SSIS',$taskLocalName)
        }
    }
}
$taskLocalProject = Join-Path $taskProject.DirectoryName 'Hop_CreditHistory.local.dtproj'
$taskProjectXml.Save($taskLocalProject)
$taskLocalSolution = Join-Path $taskProject.Directory.Parent.FullName 'Hop_CreditHistory.local.slnx'
$taskSolutionXml = [xml](Get-Content -LiteralPath (Join-Path $taskProject.Directory.Parent.FullName 'Hop_CreditHistory.slnx') -Raw)
$taskSolutionXml.Solution.Project.Path = 'Hop_CreditHistory/Hop_CreditHistory.local.dtproj'
if (-not (Test-Path -LiteralPath $taskLocalSolution) -or ([xml](Get-Content -LiteralPath $taskLocalSolution -Raw)).OuterXml -ne $taskSolutionXml.OuterXml) {
    $taskSolutionXml.Save($taskLocalSolution)
}
Write-Output "Open in Visual Studio: $taskLocalSolution"
Write-Output "BatchID=$BatchID; RowLimit=$RowLimit (0=FULL). Execute source packages one at a time."
