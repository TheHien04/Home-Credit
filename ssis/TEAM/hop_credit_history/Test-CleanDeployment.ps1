param(
    [Parameter(Mandatory)][string]$ServerInstance,
    [Parameter(Mandatory)][ValidatePattern('^HomeCreditBI_Hop_DeployCheck_[A-Za-z0-9_]+$')][string]$DatabaseName,
    [Parameter(Mandatory)][string]$EvidenceDirectory
)
# Creates a separate, empty deployment-check database; never resets any database.
$ErrorActionPreference = 'Stop'
$taskRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$taskBuilder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
$taskBuilder['Data Source']=$ServerInstance
$taskBuilder['Initial Catalog']='master'
$taskBuilder['Integrated Security']=$true
$taskBuilder['TrustServerCertificate']=$true
$taskConnection = New-Object System.Data.SqlClient.SqlConnection($taskBuilder.ConnectionString)
try {
    $taskConnection.Open()
    $taskCommand=$taskConnection.CreateCommand()
    $taskCommand.CommandText='SELECT DB_ID(@Name);'
    [void]$taskCommand.Parameters.AddWithValue('@Name',$DatabaseName)
    $taskExisting=$taskCommand.ExecuteScalar()
    if ($taskExisting -isnot [DBNull] -and $null -ne $taskExisting) {
        throw 'The deployment-check database already exists. Choose a fresh name; this tool never drops or resets it.'
    }
} finally { $taskConnection.Dispose() }
$taskSqlRoot=Join-Path $taskRoot 'sql'
$taskEntry=Get-Content -LiteralPath (Join-Path $taskSqlRoot '000_deploy_all.sql') -Raw -Encoding utf8
$taskIncludes=@([regex]::Matches($taskEntry,'(?m)^:r\s+([^\r\n]+)') | ForEach-Object {$_.Groups[1].Value.Trim()})
if ($taskIncludes.Count -ne 16 -or $taskIncludes[0] -ne '00_admin/000_create_database.sql') {
    throw 'Deployment entry point changed. Review the isolated bootstrap before proceeding.'
}
$taskBootstrap=Get-Content -LiteralPath (Join-Path $taskSqlRoot $taskIncludes[0]) -Raw -Encoding utf8
$taskBootstrap=$taskBootstrap.Replace('HomeCreditBI',$DatabaseName)
$taskDriver=@(':on error exit',$taskBootstrap)
$taskSources=@()
foreach ($taskRelative in $taskIncludes) {
    $taskPath=Join-Path $taskSqlRoot $taskRelative
    $taskSources += [pscustomobject]@{Source=('sql/'+$taskRelative);Sha256=(Get-FileHash -LiteralPath $taskPath -Algorithm SHA256).Hash.ToLowerInvariant()}
    if ($taskRelative -eq $taskIncludes[0]) { continue }
    if ((Get-Content -LiteralPath $taskPath -Raw -Encoding utf8) -match '(?im)^\s*USE\s+') {
        throw "An included source overrides the target database: $taskRelative"
    }
    $taskDriver += ':r "'+$taskPath+'"'
}
$taskDriverPath=Join-Path $PSScriptRoot 'clean_deployment.local.sql'
$taskDriver -join "`r`n" | Set-Content -LiteralPath $taskDriverPath -Encoding utf8
New-Item -ItemType Directory -Path $EvidenceDirectory -Force | Out-Null
foreach ($taskPass in @(1,2)) {
    $taskOutput=Join-Path $EvidenceDirectory "clean_deploy_pass_$taskPass.txt"
    & sqlcmd -S $ServerInstance -E -C -b -i $taskDriverPath -o $taskOutput
    if ($LASTEXITCODE -ne 0) { throw "Isolated deployment pass $taskPass failed. Review $taskOutput; the database is retained for investigation." }
    if (-not (Select-String -LiteralPath $taskOutput -Pattern 'PASS\s+59\s+10\s+5' -Quiet)) {
        throw "The required 59-object smoke result is missing from pass $taskPass."
    }
}
$taskCommit=(& git -C $taskRoot rev-parse HEAD).Trim()
$taskReport=[ordered]@{
    CapturedAtUtc=[DateTime]::UtcNow.ToString('o');Database=$DatabaseName;SourceCommit=$taskCommit
    Scope='Clean schema deployment and idempotent redeployment only; no source rows loaded and no NDS runtime acceptance.'
    BootstrapChange='Only the database name in 00_admin/000_create_database.sql is replaced; the other fifteen source includes are executed unchanged in entry-point order.'
    FirstDeployment='PASS';SecondDeployment='PASS';RequiredObjects=59;RegisteredSources=10;SeededAffordabilityBands=5
    Sources=$taskSources;Status='PASS'
}
$taskReport | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $EvidenceDirectory 'clean_deployment.json') -Encoding utf8
Write-Output "Clean deployment and redeployment: PASS ($DatabaseName). The separate empty test database is retained."
