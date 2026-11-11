param(
    [Parameter(Mandatory)][string]$ServerInstance,
    [Parameter(Mandatory)][string]$EvidenceDirectory
)
# Compare the deployed NDS modules with the repository; no SQL is deployed here.
$ErrorActionPreference = 'Stop'
$taskRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$taskFiles = @('sql/04_etl/040_create_clean_views.sql','sql/04_etl/041_load_nds.sql','sql/05_tests/051_validate_nds.sql')
function Normalize-TaskDefinition([string]$Definition) {
    $taskText = $Definition.Trim()
    $taskText = [regex]::Replace($taskText,'(?i)^(?:CREATE\s+(?:OR\s+ALTER\s+)?|ALTER\s+)(VIEW|PROCEDURE)\b','CREATE $1')
    # Preserve literal strings/comments; only normalize line endings and outer whitespace.
    return ($taskText -replace "`r`n","`n" -replace "`r","`n")
}
function Get-TaskHash([string]$Value) {
    $taskHasher = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($taskHasher.ComputeHash([Text.Encoding]::UTF8.GetBytes($Value)))).Replace('-','').ToLowerInvariant() }
    finally { $taskHasher.Dispose() }
}
$taskBuilder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
$taskBuilder['Data Source']=$ServerInstance
$taskBuilder['Initial Catalog']='HomeCreditBI'
$taskBuilder['Integrated Security']=$true
$taskBuilder['TrustServerCertificate']=$true
$taskConnection = New-Object System.Data.SqlClient.SqlConnection($taskBuilder.ConnectionString)
try {
    $taskConnection.Open()
    $taskResults = @()
    foreach ($taskFile in $taskFiles) {
        $taskSql = Get-Content -LiteralPath (Join-Path $taskRoot $taskFile) -Raw -Encoding utf8
        foreach ($taskBatch in [regex]::Split($taskSql,'(?im)^\s*GO\s*\r?$')) {
            $taskMatch = [regex]::Match($taskBatch,'(?is)CREATE\s+OR\s+ALTER\s+(?:VIEW|PROCEDURE)\s+([\w.\[\]]+).*')
            if (-not $taskMatch.Success) { continue }
            $taskName = $taskMatch.Groups[1].Value.Replace('[','').Replace(']','')
            $taskCommand = $taskConnection.CreateCommand()
            $taskCommand.CommandText='SELECT OBJECT_DEFINITION(OBJECT_ID(@Name));'
            [void]$taskCommand.Parameters.AddWithValue('@Name',$taskName)
            try { $taskActual = $taskCommand.ExecuteScalar() } finally { $taskCommand.Dispose() }
            $taskExpectedHash = Get-TaskHash (Normalize-TaskDefinition $taskMatch.Value)
            $taskActualHash = if ($taskActual -is [string]) {Get-TaskHash (Normalize-TaskDefinition $taskActual)} else {$null}
            $taskResults += [pscustomobject]@{
                Module=$taskName;Source=$taskFile;SourceSha256=$taskExpectedHash;DatabaseSha256=$taskActualHash
                Status=if($taskActualHash -ceq $taskExpectedHash){'PASS'}else{'DIFFERENT_OR_MISSING'}
            }
        }
    }
    New-Item -ItemType Directory -Path $EvidenceDirectory -Force | Out-Null
    $taskResults | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $EvidenceDirectory 'nds_deployed_source_comparison.json') -Encoding utf8
    $taskResults | Format-Table Module,Status -AutoSize
    if ($taskResults.Count -ne 10 -or @($taskResults | Where-Object Status -ne 'PASS').Count) {
        throw 'The ten NDS modules do not exactly match repository definitions; review before deployment.'
    }
} finally { $taskConnection.Dispose() }
