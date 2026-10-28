/*
Purpose: Standardize ETL batch/file lifecycle calls used by Mage orchestration.
Dependency: 001_create_control_layer.sql and 002_seed_source_files.sql.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

CREATE OR ALTER PROCEDURE ctl.usp_StartETLBatch
    @PipelineName NVARCHAR(128),
    @BatchID BIGINT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF NULLIF(LTRIM(RTRIM(@PipelineName)), N'') IS NULL
        THROW 51200, 'PipelineName is required.', 1;

    INSERT ctl.ETLBatch (PipelineName, BatchStatus)
    VALUES (LTRIM(RTRIM(@PipelineName)), 'RUNNING');

    SET @BatchID = CONVERT(BIGINT, SCOPE_IDENTITY());

    SELECT @BatchID AS BatchID;
END;
GO

CREATE OR ALTER PROCEDURE ctl.usp_StartFileLoad
    @BatchID BIGINT,
    @FileName NVARCHAR(260),
    @FileSizeBytes BIGINT = NULL,
    @FileLoadID BIGINT OUTPUT,
    @SourceFileID INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS
    (
        SELECT 1 FROM ctl.ETLBatch
        WHERE BatchID = @BatchID AND BatchStatus = 'RUNNING'
    )
        THROW 51201, 'Batch does not exist or is not RUNNING.', 1;

    SELECT @SourceFileID = SourceFileID
    FROM ctl.SourceFile
    WHERE FileName = @FileName AND IsActive = 1;

    IF @SourceFileID IS NULL
        THROW 51202, 'FileName is not registered as an active source.', 1;

    INSERT ctl.ETLFileLoad (BatchID, SourceFileID, FileSizeBytes, LoadStatus)
    VALUES (@BatchID, @SourceFileID, @FileSizeBytes, 'RUNNING');

    SET @FileLoadID = CONVERT(BIGINT, SCOPE_IDENTITY());

    SELECT @FileLoadID AS FileLoadID, @SourceFileID AS SourceFileID;
END;
GO

CREATE OR ALTER PROCEDURE ctl.usp_EndFileLoad
    @FileLoadID BIGINT,
    @LoadStatus VARCHAR(20),
    @RowsRead BIGINT,
    @RowsAccepted BIGINT,
    @RowsRejected BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    IF @LoadStatus NOT IN ('SUCCEEDED', 'FAILED', 'SKIPPED')
        THROW 51203, 'File load must end as SUCCEEDED, FAILED, or SKIPPED.', 1;

    IF @RowsRead < 0 OR @RowsAccepted < 0 OR @RowsRejected < 0
        THROW 51204, 'File row counts cannot be negative.', 1;

    IF @RowsRead <> @RowsAccepted + @RowsRejected
        THROW 51205, 'RowsRead must equal RowsAccepted plus RowsRejected.', 1;

    UPDATE ctl.ETLFileLoad
    SET EndedAtUtc = SYSUTCDATETIME(),
        RowsRead = @RowsRead,
        RowsAccepted = @RowsAccepted,
        RowsRejected = @RowsRejected,
        LoadStatus = @LoadStatus
    WHERE FileLoadID = @FileLoadID
      AND LoadStatus = 'RUNNING';

    IF @@ROWCOUNT <> 1
        THROW 51206, 'FileLoadID does not exist or is not RUNNING.', 1;
END;
GO

CREATE OR ALTER PROCEDURE ctl.usp_EndETLBatch
    @BatchID BIGINT,
    @BatchStatus VARCHAR(20),
    @ErrorMessage NVARCHAR(2000) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @BatchStatus NOT IN ('SUCCEEDED', 'FAILED', 'CANCELLED')
        THROW 51207, 'Batch must end as SUCCEEDED, FAILED, or CANCELLED.', 1;

    IF @BatchStatus = 'SUCCEEDED'
       AND NOT EXISTS
       (
           SELECT 1 FROM ctl.ETLFileLoad WHERE BatchID = @BatchID
       )
        THROW 51211, 'Batch cannot succeed without file-load audit rows.', 1;

    IF @BatchStatus = 'SUCCEEDED'
       AND EXISTS
       (
           SELECT 1 FROM ctl.DataQualityResult
           WHERE BatchID = @BatchID AND TestStatus = 'FAIL'
       )
        THROW 51208, 'Batch cannot succeed while a persisted data-quality test is FAIL.', 1;

    IF @BatchStatus = 'SUCCEEDED'
       AND EXISTS
       (
           SELECT 1 FROM ctl.ETLFileLoad
           WHERE BatchID = @BatchID AND LoadStatus <> 'SUCCEEDED'
       )
        THROW 51209, 'Batch cannot succeed while a file load is not SUCCEEDED.', 1;

    UPDATE b
    SET EndedAtUtc = SYSUTCDATETIME(),
        BatchStatus = @BatchStatus,
        RowsRead = totals.RowsRead,
        RowsAccepted = totals.RowsAccepted,
        RowsRejected = totals.RowsRejected,
        ErrorMessage = LEFT(@ErrorMessage, 2000)
    FROM ctl.ETLBatch AS b
    CROSS APPLY
    (
        SELECT
            COALESCE(SUM(f.RowsRead), 0) AS RowsRead,
            COALESCE(SUM(f.RowsAccepted), 0) AS RowsAccepted,
            COALESCE(SUM(f.RowsRejected), 0) AS RowsRejected
        FROM ctl.ETLFileLoad AS f
        WHERE f.BatchID = b.BatchID
    ) AS totals
    WHERE b.BatchID = @BatchID
      AND b.BatchStatus = 'RUNNING';

    IF @@ROWCOUNT <> 1
        THROW 51210, 'BatchID does not exist or is not RUNNING.', 1;

    SELECT BatchID, PipelineName, StartedAtUtc, EndedAtUtc, BatchStatus,
           RowsRead, RowsAccepted, RowsRejected, ErrorMessage
    FROM ctl.ETLBatch
    WHERE BatchID = @BatchID;
END;
GO
