param(
    [Parameter(Mandatory)][string]$ServerInstance,
    [Parameter(Mandatory)][string]$PipelineName,
    [Parameter(Mandatory)][string]$EvidencePath
)
$ErrorActionPreference = 'Stop'
if (Test-Path -LiteralPath $EvidencePath) { throw 'Batch evidence already exists. Read its BatchID instead of starting another batch.' }
$taskConnectionString = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
$taskConnectionString['Data Source'] = $ServerInstance
$taskConnectionString['Initial Catalog'] = 'HomeCreditBI'
$taskConnectionString['Integrated Security'] = $true
$taskConnectionString['TrustServerCertificate'] = $true
$taskConnection = New-Object System.Data.SqlClient.SqlConnection($taskConnectionString.ConnectionString)
try {
    $taskConnection.Open()
    $taskCommand = $taskConnection.CreateCommand()
    $taskCommand.CommandType = [System.Data.CommandType]::StoredProcedure
    $taskCommand.CommandText = 'ctl.usp_StartETLBatch'
    [void]$taskCommand.Parameters.AddWithValue('@PipelineName',$PipelineName)
    $taskBatchOutput = $taskCommand.Parameters.Add('@BatchID',[System.Data.SqlDbType]::BigInt)
    $taskBatchOutput.Direction = [System.Data.ParameterDirection]::Output
    [void]$taskCommand.ExecuteNonQuery()
    $taskEvidence = [ordered]@{server_instance=$ServerInstance; database='HomeCreditBI'; batch_id=[long]$taskBatchOutput.Value; pipeline_name=$PipelineName; created_utc=[DateTime]::UtcNow.ToString('o')}
    $taskEvidenceDirectory = Split-Path -Parent ([System.IO.Path]::GetFullPath($EvidencePath))
    New-Item -ItemType Directory -Path $taskEvidenceDirectory -Force | Out-Null
    $taskEvidence | ConvertTo-Json | Set-Content -LiteralPath $EvidencePath -Encoding utf8
    $taskEvidence | ConvertTo-Json
} finally { $taskConnection.Dispose() }
