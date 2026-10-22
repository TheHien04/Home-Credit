/*
Purpose: Create idempotent ETL control, audit, rejection, and data-quality objects.
Target: Run inside the selected Home Credit SQL Server database.
Safety: This script creates objects only; it does not drop or truncate data.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF SCHEMA_ID(N'ctl') IS NULL EXEC(N'CREATE SCHEMA ctl');
IF SCHEMA_ID(N'stg') IS NULL EXEC(N'CREATE SCHEMA stg');
IF SCHEMA_ID(N'nds') IS NULL EXEC(N'CREATE SCHEMA nds');
IF SCHEMA_ID(N'dds') IS NULL EXEC(N'CREATE SCHEMA dds');
IF SCHEMA_ID(N'etl') IS NULL EXEC(N'CREATE SCHEMA etl');
GO

IF OBJECT_ID(N'ctl.ETLBatch', N'U') IS NULL
BEGIN
    CREATE TABLE ctl.ETLBatch
    (
        BatchID             BIGINT IDENTITY(1,1) NOT NULL,
        PipelineName        NVARCHAR(128) NOT NULL,
        StartedAtUtc        DATETIME2(3) NOT NULL
            CONSTRAINT DF_ETLBatch_StartedAtUtc DEFAULT SYSUTCDATETIME(),
        EndedAtUtc          DATETIME2(3) NULL,
        BatchStatus         VARCHAR(20) NOT NULL
            CONSTRAINT DF_ETLBatch_Status DEFAULT 'RUNNING',
        RowsRead            BIGINT NOT NULL
            CONSTRAINT DF_ETLBatch_RowsRead DEFAULT 0,
        RowsAccepted        BIGINT NOT NULL
            CONSTRAINT DF_ETLBatch_RowsAccepted DEFAULT 0,
        RowsRejected        BIGINT NOT NULL
            CONSTRAINT DF_ETLBatch_RowsRejected DEFAULT 0,
        ErrorMessage        NVARCHAR(2000) NULL,
        CreatedBy           SYSNAME NOT NULL
            CONSTRAINT DF_ETLBatch_CreatedBy DEFAULT SUSER_SNAME(),
        CONSTRAINT PK_ETLBatch PRIMARY KEY CLUSTERED (BatchID),
        CONSTRAINT CK_ETLBatch_Status CHECK
            (BatchStatus IN ('RUNNING', 'SUCCEEDED', 'FAILED', 'CANCELLED')),
        CONSTRAINT CK_ETLBatch_RowCounts CHECK
            (RowsRead >= 0 AND RowsAccepted >= 0 AND RowsRejected >= 0)
    );
END;
GO

IF OBJECT_ID(N'ctl.SourceFile', N'U') IS NULL
BEGIN
    CREATE TABLE ctl.SourceFile
    (
        SourceFileID        INT IDENTITY(1,1) NOT NULL,
        FileName            NVARCHAR(260) NOT NULL,
        ScopeName           VARCHAR(20) NOT NULL,
        ExpectedGrain       NVARCHAR(500) NOT NULL,
        NaturalKeyRule      NVARCHAR(500) NULL,
        IsActive            BIT NOT NULL
            CONSTRAINT DF_SourceFile_IsActive DEFAULT 1,
        CONSTRAINT PK_SourceFile PRIMARY KEY CLUSTERED (SourceFileID),
        CONSTRAINT UQ_SourceFile_FileName UNIQUE (FileName),
        CONSTRAINT CK_SourceFile_Scope CHECK
            (ScopeName IN ('CORE', 'EXTENSION', 'METADATA', 'EXCLUDED'))
    );
END;
GO

IF OBJECT_ID(N'ctl.ETLFileLoad', N'U') IS NULL
BEGIN
    CREATE TABLE ctl.ETLFileLoad
    (
        FileLoadID          BIGINT IDENTITY(1,1) NOT NULL,
        BatchID             BIGINT NOT NULL,
        SourceFileID        INT NOT NULL,
        StartedAtUtc        DATETIME2(3) NOT NULL
            CONSTRAINT DF_ETLFileLoad_StartedAtUtc DEFAULT SYSUTCDATETIME(),
        EndedAtUtc          DATETIME2(3) NULL,
        FileSizeBytes       BIGINT NULL,
        RowsRead            BIGINT NOT NULL
            CONSTRAINT DF_ETLFileLoad_RowsRead DEFAULT 0,
        RowsAccepted        BIGINT NOT NULL
            CONSTRAINT DF_ETLFileLoad_RowsAccepted DEFAULT 0,
        RowsRejected        BIGINT NOT NULL
            CONSTRAINT DF_ETLFileLoad_RowsRejected DEFAULT 0,
        LoadStatus          VARCHAR(20) NOT NULL
            CONSTRAINT DF_ETLFileLoad_Status DEFAULT 'RUNNING',
        CONSTRAINT PK_ETLFileLoad PRIMARY KEY CLUSTERED (FileLoadID),
        CONSTRAINT FK_ETLFileLoad_Batch FOREIGN KEY (BatchID)
            REFERENCES ctl.ETLBatch (BatchID),
        CONSTRAINT FK_ETLFileLoad_SourceFile FOREIGN KEY (SourceFileID)
            REFERENCES ctl.SourceFile (SourceFileID),
        CONSTRAINT CK_ETLFileLoad_Status CHECK
            (LoadStatus IN ('RUNNING', 'SUCCEEDED', 'FAILED', 'SKIPPED')),
        CONSTRAINT CK_ETLFileLoad_RowCounts CHECK
            (RowsRead >= 0 AND RowsAccepted >= 0 AND RowsRejected >= 0)
    );

    CREATE INDEX IX_ETLFileLoad_BatchID
        ON ctl.ETLFileLoad (BatchID, SourceFileID);
END;
GO

IF OBJECT_ID(N'ctl.RejectedRow', N'U') IS NULL
BEGIN
    CREATE TABLE ctl.RejectedRow
    (
        RejectedRowID       BIGINT IDENTITY(1,1) NOT NULL,
        BatchID             BIGINT NOT NULL,
        SourceFileID        INT NOT NULL,
        SourceRowNumber     BIGINT NULL,
        ColumnName          SYSNAME NULL,
        ErrorCode           VARCHAR(50) NOT NULL,
        ErrorMessage        NVARCHAR(1000) NOT NULL,
        RawValueHash        VARBINARY(32) NULL,
        RejectedAtUtc       DATETIME2(3) NOT NULL
            CONSTRAINT DF_RejectedRow_At DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_RejectedRow PRIMARY KEY CLUSTERED (RejectedRowID),
        CONSTRAINT FK_RejectedRow_Batch FOREIGN KEY (BatchID)
            REFERENCES ctl.ETLBatch (BatchID),
        CONSTRAINT FK_RejectedRow_SourceFile FOREIGN KEY (SourceFileID)
            REFERENCES ctl.SourceFile (SourceFileID)
    );

    CREATE INDEX IX_RejectedRow_BatchSource
        ON ctl.RejectedRow (BatchID, SourceFileID);
END;
GO

IF OBJECT_ID(N'ctl.DataQualityResult', N'U') IS NULL
BEGIN
    CREATE TABLE ctl.DataQualityResult
    (
        DataQualityResultID BIGINT IDENTITY(1,1) NOT NULL,
        BatchID             BIGINT NOT NULL,
        TestCode            VARCHAR(100) NOT NULL,
        ObjectName          NVARCHAR(256) NOT NULL,
        TestDescription     NVARCHAR(1000) NOT NULL,
        ExpectedValue       NVARCHAR(200) NULL,
        ActualValue         NVARCHAR(200) NULL,
        TestStatus          VARCHAR(10) NOT NULL,
        ExecutedAtUtc       DATETIME2(3) NOT NULL
            CONSTRAINT DF_DataQualityResult_At DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_DataQualityResult PRIMARY KEY CLUSTERED (DataQualityResultID),
        CONSTRAINT FK_DataQualityResult_Batch FOREIGN KEY (BatchID)
            REFERENCES ctl.ETLBatch (BatchID),
        CONSTRAINT CK_DataQualityResult_Status CHECK
            (TestStatus IN ('PASS', 'FAIL', 'WARN'))
    );

    CREATE INDEX IX_DataQualityResult_BatchStatus
        ON ctl.DataQualityResult (BatchID, TestStatus);
END;
GO
