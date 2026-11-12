USE HomeCreditBI;
GO
SELECT TOP (10) b.BatchID,b.PipelineName,b.BatchStatus,b.RowsRead,b.RowsAccepted,b.RowsRejected,b.StartedAtUtc
FROM ctl.ETLBatch AS b
WHERE b.PipelineName=N'HomeCredit_Application_Duy_NativeSSIS'
ORDER BY b.BatchID DESC;
GO
WITH last_batch AS (
    SELECT MAX(BatchID) AS BatchID FROM ctl.ETLBatch
    WHERE PipelineName=N'HomeCredit_Application_Duy_NativeSSIS' AND BatchStatus='SUCCEEDED'
)
SELECT a.BatchID,a.DatasetSplit,COUNT_BIG(*) AS TotalRows,
       MIN(a.SourceRowNumber) AS MinRowNumber,
       MAX(a.SourceRowNumber) AS MaxRowNumber,
       COUNT(DISTINCT a.SK_ID_CURR) AS UniqueApplicants,
       SUM(CASE WHEN a.DatasetSplit='TRAIN' AND a.TARGET IS NULL THEN 1 ELSE 0 END) AS NullTrainTarget,
       SUM(CASE WHEN a.DatasetSplit='TEST' AND a.TARGET IS NOT NULL THEN 1 ELSE 0 END) AS NonNullTestTarget
FROM stg.Application a JOIN last_batch b ON a.BatchID=b.BatchID
GROUP BY a.BatchID,a.DatasetSplit ORDER BY a.DatasetSplit;
GO
SELECT TOP (10) f.BatchID,s.FileName,f.LoadStatus,f.RowsRead,f.RowsAccepted,f.RowsRejected
FROM ctl.ETLFileLoad f JOIN ctl.SourceFile s ON s.SourceFileID=f.SourceFileID
WHERE f.BatchID IN (
 SELECT TOP(1) BatchID FROM ctl.ETLBatch WHERE PipelineName=N'HomeCredit_Application_Duy_NativeSSIS' ORDER BY BatchID DESC
) ORDER BY s.FileName;
GO
