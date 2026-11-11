param(
    [Parameter(Mandatory)][string]$ServerInstance,
    [Parameter(Mandatory)][ValidateRange(1,[long]::MaxValue)][long]$BatchID,
    [Parameter(Mandatory)][string]$EvidenceDirectory,
    [ValidateSet('Readiness','Regression')][string]$Mode = 'Readiness'
)
# Read-only: does not load/replace NDS, close batches, or persist validator rows.
$ErrorActionPreference = 'Stop'
$taskBuilder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
$taskBuilder['Data Source'] = $ServerInstance
$taskBuilder['Initial Catalog'] = 'HomeCreditBI'
$taskBuilder['Integrated Security'] = $true
$taskBuilder['TrustServerCertificate'] = $true
$taskConnection = New-Object System.Data.SqlClient.SqlConnection($taskBuilder.ConnectionString)
function Read-TaskSql([string]$Sql) {
    $taskCommand = $taskConnection.CreateCommand()
    $taskCommand.CommandText = $Sql
    $taskCommand.CommandTimeout = 0
    [void]$taskCommand.Parameters.AddWithValue('@BatchID',$BatchID)
    $taskTable = New-Object System.Data.DataTable
    $taskAdapter = New-Object System.Data.SqlClient.SqlDataAdapter($taskCommand)
    try { [void]$taskAdapter.Fill($taskTable); return ,$taskTable }
    finally { $taskAdapter.Dispose(); $taskCommand.Dispose() }
}
function Convert-TaskRows($Table) {
    foreach ($taskRow in $Table.Rows) {
        $taskObject = [ordered]@{}
        foreach ($taskColumn in $Table.Columns) {
            $taskValue = $taskRow[$taskColumn.ColumnName]
            $taskObject[$taskColumn.ColumnName] = if ($taskValue -is [DBNull]) {$null} else {$taskValue}
        }
        [pscustomobject]$taskObject
    }
}
$taskSources = @(
    @{File='application_train.csv';Table='Application';Split='TRAIN';Rows=307511},
    @{File='application_test.csv';Table='Application';Split='TEST';Rows=48744},
    @{File='previous_application.csv';Table='PreviousApplication';Rows=1670214},
    @{File='bureau.csv';Table='BureauCredit';Rows=1716428},
    @{File='bureau_balance.csv';Table='BureauBalance';Rows=27299925},
    @{File='POS_CASH_balance.csv';Table='POSCashBalance';Rows=10001358},
    @{File='installments_payments.csv';Table='InstallmentPayment';Rows=13605401},
    @{File='credit_card_balance.csv';Table='CreditCardBalance';Rows=3840312}
)
$taskNds = [ordered]@{
    Applicant=356255;LoanApplication=356255;PreviousApplication=1670214
    BureauCredit=1716428;BureauMonthlyStatus=27299925
    POSCashMonthly=10001358;InstallmentPayment=13605401;CreditCardMonthly=3840312
}
try {
    $taskConnection.Open()
    $taskBatch = Read-TaskSql 'SELECT BatchID,PipelineName,BatchStatus FROM ctl.ETLBatch WHERE BatchID=@BatchID;'
    if ($taskBatch.Rows.Count -ne 1) { throw 'The explicit batch does not exist on this database.' }
    $taskInputs = @()
    foreach ($taskSource in $taskSources) {
        $taskSplit = if ($taskSource.Split) {" AND DatasetSplit='"+$taskSource.Split+"'"} else {''}
        $taskCount = Read-TaskSql ('SELECT COUNT_BIG(*) ActualRows FROM stg.['+$taskSource.Table+'] WHERE BatchID=@BatchID'+$taskSplit+';')
        $taskFile = $taskSource.File.Replace("'","''")
        $taskAudit = Read-TaskSql ("SELECT TOP(1) f.FileLoadID,f.LoadStatus,f.RowsRead,f.RowsAccepted,f.RowsRejected FROM ctl.ETLFileLoad f JOIN ctl.SourceFile s ON s.SourceFileID=f.SourceFileID WHERE f.BatchID=@BatchID AND s.FileName=N'"+$taskFile+"' ORDER BY f.FileLoadID DESC;")
        $taskRejected = Read-TaskSql ("SELECT COUNT_BIG(*) RejectRecords FROM ctl.RejectedRow r JOIN ctl.SourceFile s ON s.SourceFileID=r.SourceFileID WHERE r.BatchID=@BatchID AND s.FileName=N'"+$taskFile+"';")
        $taskAuditRow = if ($taskAudit.Rows.Count) {$taskAudit.Rows[0]} else {$null}
        $taskOk = [long]$taskCount.Rows[0].ActualRows -eq $taskSource.Rows -and $taskAuditRow -and
            $taskAuditRow.LoadStatus -eq 'SUCCEEDED' -and $taskAuditRow.RowsRead -eq $taskSource.Rows -and
            $taskAuditRow.RowsAccepted -eq $taskSource.Rows -and $taskAuditRow.RowsRejected -eq 0 -and
            $taskRejected.Rows[0].RejectRecords -eq 0
        $taskInputs += [pscustomobject][ordered]@{
            File=$taskSource.File;Table=('stg.'+$taskSource.Table);ExpectedRows=$taskSource.Rows
            ActualRows=[long]$taskCount.Rows[0].ActualRows
            FileLoadID=if($taskAuditRow){$taskAuditRow.FileLoadID}else{$null}
            AuditStatus=if($taskAuditRow){$taskAuditRow.LoadStatus}else{'MISSING'}
            RejectRecords=[long]$taskRejected.Rows[0].RejectRecords
            Status=if($taskOk){'PASS'}else{'INCOMPLETE'}
        }
    }
    $taskNdsResults = @()
    foreach ($taskName in $taskNds.Keys) {
        $taskCount = Read-TaskSql ('SELECT COUNT_BIG(*) ActualRows FROM nds.['+$taskName+'] WHERE SourceBatchID=@BatchID;')
        $taskNdsResults += [pscustomobject]@{
            Table=('nds.'+$taskName);ExpectedRows=$taskNds[$taskName]
            ActualRows=[long]$taskCount.Rows[0].ActualRows
            Status=if([long]$taskCount.Rows[0].ActualRows -eq $taskNds[$taskName]){'PASS'}else{'INCOMPLETE'}
        }
    }
    $taskCapacity = Read-TaskSql "SELECT CONVERT(nvarchar(128),SERVERPROPERTY('Edition')) Edition,SUM(CASE WHEN type=0 THEN size ELSE 0 END)*8.0/1024 DataFileMB,SUM(CASE WHEN type=0 THEN FILEPROPERTY(name,'SpaceUsed') ELSE 0 END)*8.0/1024 UsedDataMB FROM sys.database_files;"
    $taskQuality = Read-TaskSql 'SELECT TestCode,ExpectedValue,ActualValue,TestStatus FROM ctl.DataQualityResult WHERE BatchID=@BatchID ORDER BY TestCode;'
    $taskInputOk = @($taskInputs | Where-Object Status -ne 'PASS').Count -eq 0
    $taskNdsOk = @($taskNdsResults | Where-Object Status -ne 'PASS').Count -eq 0
    $taskTests = @()
    if ($Mode -eq 'Regression' -and $taskInputOk -and $taskNdsOk) {
        # Never allow empty/partial populations to produce a vacuous validator PASS.
        $taskTests = @(Convert-TaskRows (Read-TaskSql 'EXEC etl.usp_ValidateNDS @BatchID=@BatchID,@PersistResults=0;'))
    }
    $taskPass = if ($Mode -eq 'Readiness') {
        $taskInputOk -and $taskBatch.Rows[0].BatchStatus -eq 'RUNNING'
    } else {
        $taskInputOk -and $taskNdsOk -and $taskTests.Count -eq 12 -and @($taskTests | Where-Object TestStatus -ne 'PASS').Count -eq 0
    }
    $taskReport = [ordered]@{
        CapturedAtUtc=[DateTime]::UtcNow.ToString('o');Database='HomeCreditBI';Mode=$Mode
        Batch=@(Convert-TaskRows $taskBatch)[0];Status=if($taskPass){'PASS'}else{'INCOMPLETE'}
        Inputs=$taskInputs;Nds=$taskNdsResults;Capacity=@(Convert-TaskRows $taskCapacity)[0]
        PersistedQuality=@(Convert-TaskRows $taskQuality);ReadOnlyNdsTests=$taskTests
        Note='PASS requires full source counts and latest successful audit for each of eight source files. Readiness is not NDS acceptance. Express capacity must be reviewed before loading all warehouse layers.'
    }
    New-Item -ItemType Directory -Path $EvidenceDirectory -Force | Out-Null
    $taskOutput = Join-Path $EvidenceDirectory ('nds_'+$Mode.ToLower()+'_batch_'+$BatchID+'.json')
    $taskReport | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $taskOutput -Encoding utf8
    $taskInputs | Format-Table File,ExpectedRows,ActualRows,AuditStatus,Status -AutoSize
    Write-Output "$Mode status: $($taskReport.Status). Evidence: $taskOutput"
    if (-not $taskPass) { throw 'Full integration requirements are incomplete; evidence was saved. No warehouse data was changed.' }
} finally { $taskConnection.Dispose() }
