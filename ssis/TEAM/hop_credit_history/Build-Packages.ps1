param(
    [Parameter(Mandatory)][string]$ServerInstance,
    [Parameter(Mandatory)][string]$SourceRoot,
    [Parameter(Mandatory)][string]$WorkRoot,
    [switch]$CompileOnly
)
$ErrorActionPreference = 'Stop'
$taskVswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
$taskVsRoot = & $taskVswhere -latest -products Microsoft.VisualStudio.Product.Community -property installationPath
$taskSsisRoot = Join-Path $taskVsRoot 'Common7/IDE/CommonExtensions/Microsoft/SSIS'
if (-not (Test-Path (Join-Path $taskSsisRoot 'SSIS160.manifest'))) {
    throw 'Install Microsoft SSIS Projects with the SQL Server 2022 target first.'
}
$taskSsisBin = Join-Path $taskSsisRoot '160/Binn'
$env:PATH = $taskSsisBin + ';' + $env:PATH
$taskBuildRoot = Join-Path $PSScriptRoot 'bin'
New-Item -ItemType Directory -Path $taskBuildRoot -Force | Out-Null
$taskCompiler = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
$taskAssemblyRoot = Join-Path $env:WINDIR 'Microsoft.NET/assembly'
$taskReferences = @(
    (Join-Path $taskAssemblyRoot 'GAC_MSIL/Microsoft.SqlServer.ManagedDTS/v4.0_16.0.0.0__89845dcd8080cc91/Microsoft.SqlServer.ManagedDTS.dll'),
    (Join-Path $taskAssemblyRoot 'GAC_64/Microsoft.SqlServer.DTSRuntimeWrap/v4.0_16.0.0.0__89845dcd8080cc91/Microsoft.SqlServer.DTSRuntimeWrap.dll'),
    (Join-Path $taskAssemblyRoot 'GAC_MSIL/Microsoft.SqlServer.DTSPipelineWrap/v4.0_16.0.0.0__89845dcd8080cc91/Microsoft.SqlServer.DTSPipelineWrap.dll'),
    (Join-Path $env:ProgramFiles 'Microsoft SQL Server/160/DTS/Tasks/Microsoft.SqlServer.SQLTask.dll')
)
$taskExecutable = Join-Path $taskBuildRoot 'SsisTools.exe'
$taskCompilerArgs = @('/nologo','/target:exe','/platform:x64',('/out:' + $taskExecutable),'/r:System.Data.dll','/r:System.Core.dll')
$taskCompilerArgs += $taskReferences | ForEach-Object { '/r:' + $_ }
$taskCompilerArgs += Join-Path $PSScriptRoot 'SsisTools.cs'
& $taskCompiler @taskCompilerArgs
if ($LASTEXITCODE -ne 0) { throw 'SSIS tools compilation failed.' }
if ($CompileOnly) { return }

# A bounded metadata sample is separate from full-load prepared files.
$taskSamples = Join-Path $WorkRoot 'metadata_sample'
foreach ($taskFile in @('previous_application.csv','bureau.csv','bureau_balance.csv')) {
    & python (Join-Path $PSScriptRoot 'prepare_source.py') (Join-Path $SourceRoot $taskFile) (Join-Path $taskSamples $taskFile) --row-limit 1000
    if ($LASTEXITCODE -ne 0) { throw "Cannot prepare metadata sample: $taskFile" }
}
$taskProject = Get-ChildItem -LiteralPath $PSScriptRoot -Recurse -Filter 'Hop_CreditHistory.dtproj' | Select-Object -First 1
if (-not $taskProject) { throw 'Create the Hop_CreditHistory SSIS project before building packages.' }
& $taskExecutable build $taskSsisRoot $taskProject.DirectoryName $ServerInstance $taskSamples
if ($LASTEXITCODE -ne 0) { throw 'SSIS package generation failed.' }

$taskProjectXml = [xml](Get-Content -LiteralPath $taskProject.FullName -Raw)
$taskNs = New-Object System.Xml.XmlNamespaceManager($taskProjectXml.NameTable)
$taskNs.AddNamespace('SSIS','www.microsoft.com/SqlServer/SSIS')
$taskPackageList = $taskProjectXml.SelectSingleNode('//SSIS:Packages',$taskNs)
$taskPackageList.RemoveAll()
foreach ($taskPackageFile in Get-ChildItem -LiteralPath $taskProject.DirectoryName -Filter '0?_*.dtsx' | Where-Object {$_.Name -notlike '*.local.dtsx'} | Sort-Object Name) {
    $taskPackageNode = $taskProjectXml.CreateElement('SSIS','Package','www.microsoft.com/SqlServer/SSIS')
    [void]$taskPackageNode.SetAttribute('Name','www.microsoft.com/SqlServer/SSIS',$taskPackageFile.Name)
    [void]$taskPackageNode.SetAttribute('EntryPoint','www.microsoft.com/SqlServer/SSIS','1')
    [void]$taskPackageList.AppendChild($taskPackageNode)
}
[void]$taskProjectXml.SelectSingleNode('//SSIS:Project',$taskNs).SetAttribute('ProtectionLevel','www.microsoft.com/SqlServer/SSIS','DontSaveSensitive')
$taskPasswordVerifier = $taskProjectXml.SelectSingleNode('//SSIS:Property[@SSIS:Name="PasswordVerifier"]',$taskNs)
if ($taskPasswordVerifier) { [void]$taskPasswordVerifier.ParentNode.RemoveChild($taskPasswordVerifier) }
$taskPackageInfo = $taskProjectXml.SelectSingleNode('//SSIS:PackageInfo',$taskNs)
if ($taskPackageInfo) {
    $taskPackageInfo.RemoveAll()
    foreach ($taskPackageFile in Get-ChildItem -LiteralPath $taskProject.DirectoryName -Filter '0?_*.dtsx' | Where-Object {$_.Name -notlike '*.local.dtsx'} | Sort-Object Name) {
        $taskPackageXml = [xml](Get-Content -LiteralPath $taskPackageFile.FullName -Raw)
        $taskDtsNs = 'www.microsoft.com/SqlServer/Dts'
        $taskRoot = $taskPackageXml.DocumentElement
        $taskMetadata = $taskProjectXml.CreateElement('SSIS','PackageMetaData','www.microsoft.com/SqlServer/SSIS')
        [void]$taskMetadata.SetAttribute('Name','www.microsoft.com/SqlServer/SSIS',$taskPackageFile.Name)
        $taskProperties = $taskProjectXml.CreateElement('SSIS','Properties','www.microsoft.com/SqlServer/SSIS')
        $taskPropertyValues = [ordered]@{ID=$taskRoot.GetAttribute('DTSID',$taskDtsNs); Name=$taskRoot.GetAttribute('ObjectName',$taskDtsNs); VersionMajor='1'; VersionMinor='0'; VersionBuild='0'; VersionComments=''; VersionGUID=$taskRoot.GetAttribute('VersionGUID',$taskDtsNs); PackageFormatVersion='8'; Description=''; ProtectionLevel='0'}
        foreach ($taskPropertyName in $taskPropertyValues.Keys) {
            $taskProperty = $taskProjectXml.CreateElement('SSIS','Property','www.microsoft.com/SqlServer/SSIS')
            [void]$taskProperty.SetAttribute('Name','www.microsoft.com/SqlServer/SSIS',$taskPropertyName)
            $taskProperty.InnerText = $taskPropertyValues[$taskPropertyName]
            [void]$taskProperties.AppendChild($taskProperty)
        }
        [void]$taskMetadata.AppendChild($taskProperties)
        [void]$taskMetadata.AppendChild($taskProjectXml.CreateElement('SSIS','Parameters','www.microsoft.com/SqlServer/SSIS'))
        [void]$taskPackageInfo.AppendChild($taskMetadata)
    }
}
foreach ($taskTarget in $taskProjectXml.SelectNodes('//TargetServerVersion')) { $taskTarget.InnerText = 'SQLServer2022' }
$taskProjectXml.Save($taskProject.FullName)
Write-Output "BUILT: $($taskProject.FullName)"
