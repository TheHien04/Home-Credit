param(
    [Parameter(Mandatory)][string]$ServerInstance,
    [Parameter(Mandatory)][long]$BatchID,
    [Parameter(Mandatory)][string]$WorkRoot,
    [Parameter(Mandatory)][string]$EvidenceDirectory,
    [switch]$RequireFull
)
$ErrorActionPreference = 'Stop'
$taskConnectionString = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
$taskConnectionString['Data Source']=$ServerInstance
$taskConnectionString['Initial Catalog']='HomeCreditBI'
$taskConnectionString['Integrated Security']=$true
$taskConnectionString['TrustServerCertificate']=$true
$taskConnection = New-Object System.Data.SqlClient.SqlConnection($taskConnectionString.ConnectionString)
function Get-TaskQuery([string]$Query) {
    $taskCommand=$taskConnection.CreateCommand()
    $taskCommand.CommandText=$Query
    $taskCommand.CommandTimeout=0
    [void]$taskCommand.Parameters.AddWithValue('@BatchID',$BatchID)
    $taskTable=New-Object System.Data.DataTable
    $taskAdapter=New-Object System.Data.SqlClient.SqlDataAdapter($taskCommand)
    [void]$taskAdapter.Fill($taskTable)
    return ,$taskTable
}
$taskSources=@(
    @{File='previous_application.csv';Table='PreviousApplication';FullRows=1670214;MissingKey='SK_ID_PREV IS NULL OR SK_ID_CURR IS NULL'},
    @{File='bureau.csv';Table='BureauCredit';FullRows=1716428;MissingKey='SK_ID_BUREAU IS NULL OR SK_ID_CURR IS NULL'},
    @{File='bureau_balance.csv';Table='BureauBalance';FullRows=27299925;MissingKey='SK_ID_BUREAU IS NULL OR MONTHS_BALANCE IS NULL'}
)
$taskResults=@()
try {
    $taskConnection.Open()
    foreach ($taskSource in $taskSources) {
        $taskPrepared=Join-Path (Join-Path $WorkRoot "batch_$BatchID") $taskSource.File
        $taskManifestPath=[IO.Path]::ChangeExtension($taskPrepared,'.manifest.json')
        $taskManifest=Get-Content -LiteralPath $taskManifestPath -Raw | ConvertFrom-Json
        $taskCounts=Get-TaskQuery ("SELECT COUNT_BIG(*) AS ActualRows,COUNT_BIG(DISTINCT SourceRowNumber) AS UniqueOrdinals,MIN(SourceRowNumber) AS FirstOrdinal,MAX(SourceRowNumber) AS LastOrdinal,COALESCE(SUM(CONVERT(BIGINT,CASE WHEN "+$taskSource.MissingKey+" THEN 1 ELSE 0 END)),0) AS MissingKeys FROM stg.["+$taskSource.Table+"] WHERE BatchID=@BatchID;")
        $taskCount=$taskCounts.Rows[0]
        $taskFileLiteral=$taskSource.File.Replace("'","''")
        $taskAudit=Get-TaskQuery ("SELECT TOP(1) f.FileLoadID,f.LoadStatus,f.RowsRead,f.RowsAccepted,f.RowsRejected,DATEDIFF_BIG(millisecond,f.StartedAtUtc,f.EndedAtUtc) AS DurationMs FROM ctl.ETLFileLoad f JOIN ctl.SourceFile s ON s.SourceFileID=f.SourceFileID WHERE f.BatchID=@BatchID AND s.FileName=N'"+$taskFileLiteral+"' ORDER BY f.FileLoadID DESC;")
        $taskRejects=Get-TaskQuery ("SELECT COUNT_BIG(*) AS RejectedRecords FROM ctl.RejectedRow r JOIN ctl.SourceFile s ON s.SourceFileID=r.SourceFileID WHERE r.BatchID=@BatchID AND s.FileName=N'"+$taskFileLiteral+"';")

        # Verify complete field values on a bounded independent SQL read, including quoted text and nulls.
        $taskSample=@(Import-Csv -LiteralPath $taskPrepared -Encoding utf8 | Select-Object -First 1000)
        if ($taskSample.Count -eq 0) { throw "Empty prepared sample: $($taskSource.File)" }
        $taskFields=@($taskSample[0].PSObject.Properties.Name)
        $taskSqlFields=($taskFields | ForEach-Object {'['+$_.Replace(']',']]')+']'}) -join ','
        $taskSqlSample=Get-TaskQuery ("SELECT TOP(1000) "+$taskSqlFields+" FROM stg.["+$taskSource.Table+"] WHERE BatchID=@BatchID ORDER BY SourceRowNumber;")
        $taskValueMismatches=0
        if ($taskSqlSample.Rows.Count -ne $taskSample.Count) { $taskValueMismatches++ }
        for ($taskRow=0; $taskRow -lt [Math]::Min($taskSample.Count,$taskSqlSample.Rows.Count); $taskRow++) {
            foreach ($taskField in $taskFields) {
                $taskActualValue=$taskSqlSample.Rows[$taskRow][$taskField]
                $taskActualText=if ($taskActualValue -is [DBNull]) {''} else {[Convert]::ToString($taskActualValue,[Globalization.CultureInfo]::InvariantCulture)}
                if ($taskActualText -cne [string]$taskSample[$taskRow].$taskField) { $taskValueMismatches++ }
            }
        }
        $taskAuditRow=if($taskAudit.Rows.Count){$taskAudit.Rows[0]}else{$null}
        $taskScopeOk=(-not $RequireFull) -or ($taskManifest.scope -eq 'full' -and [long]$taskManifest.rows -eq $taskSource.FullRows)
        $taskPassed=$taskScopeOk -and [long]$taskCount.ActualRows -eq [long]$taskManifest.rows -and [long]$taskCount.UniqueOrdinals -eq [long]$taskManifest.rows -and $taskCount.FirstOrdinal -eq 1 -and $taskCount.LastOrdinal -eq $taskManifest.rows -and $taskCount.MissingKeys -eq 0 -and $taskValueMismatches -eq 0 -and $taskAuditRow -and $taskAuditRow.LoadStatus -eq 'SUCCEEDED' -and $taskAuditRow.RowsRead -eq $taskManifest.rows -and $taskAuditRow.RowsAccepted -eq $taskCount.ActualRows -and $taskAuditRow.RowsRejected -eq 0 -and $taskRejects.Rows[0].RejectedRecords -eq 0
        $taskResults += [pscustomobject][ordered]@{
            File=$taskSource.File;Table=('stg.'+$taskSource.Table);BatchID=$BatchID;Scope=$taskManifest.scope
            ExpectedRows=[long]$taskManifest.rows;FullProfileRows=$taskSource.FullRows;ActualRows=[long]$taskCount.ActualRows
            UniqueOrdinals=[long]$taskCount.UniqueOrdinals;MissingKeys=[long]$taskCount.MissingKeys
            SampleRows=$taskSqlSample.Rows.Count;SampleFieldMismatches=$taskValueMismatches
            FileLoadID=if($taskAuditRow){$taskAuditRow.FileLoadID}else{$null}
            LoadStatus=if($taskAuditRow){$taskAuditRow.LoadStatus}else{'MISSING'}
            RowsRead=if($taskAuditRow){$taskAuditRow.RowsRead}else{$null}
            RowsAccepted=if($taskAuditRow){$taskAuditRow.RowsAccepted}else{$null}
            RowsRejected=if($taskAuditRow){$taskAuditRow.RowsRejected}else{$null}
            RejectRecords=[long]$taskRejects.Rows[0].RejectedRecords
            DurationMs=if($taskAuditRow){$taskAuditRow.DurationMs}else{$null}
            Status=if($taskPassed){'PASS'}else{'FAIL'}
        }
        Write-Output ("{0}: {1}; actual={2}; expected={3}; sample field mismatches={4}" -f $taskSource.File,$taskResults[-1].Status,$taskCount.ActualRows,$taskManifest.rows,$taskValueMismatches)
    }
    New-Item -ItemType Directory -Path $EvidenceDirectory -Force | Out-Null
    $taskLabel=if($RequireFull){'full'}else{'sample'}
    $taskResults | Export-Csv -LiteralPath (Join-Path $EvidenceDirectory "${taskLabel}_batch_${BatchID}_reconciliation.csv") -NoTypeInformation -Encoding utf8
    $taskResults | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $EvidenceDirectory "${taskLabel}_batch_${BatchID}_reconciliation.json") -Encoding utf8
    if (@($taskResults | Where-Object Status -ne 'PASS').Count) { throw 'Credit History reconciliation failed. Inspect saved evidence.' }
} finally { $taskConnection.Dispose() }
