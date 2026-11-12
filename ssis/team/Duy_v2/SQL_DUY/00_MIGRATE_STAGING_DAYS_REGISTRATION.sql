-- DUY v4: apply ONCE to existing HomeCreditBI DB BEFORE running SSIS v4.
-- Does not drop/truncate/modify any rows. Alters one column's data type.
-- Coordinate with team before changing shared schema. DB backup recommended.
USE [HomeCreditBI];
GO
SET XACT_ABORT ON;
SET NOCOUNT ON;

IF OBJECT_ID(N'stg.Application', N'U') IS NULL
    THROW 53400, 'stg.Application missing; do not run this migration.', 1;

DECLARE @type sysname, @precision tinyint, @scale tinyint, @nullable bit;
SELECT @type=TYPE_NAME(c.user_type_id), @precision=c.precision,
       @scale=c.scale, @nullable=c.is_nullable
FROM sys.columns AS c
WHERE c.object_id=OBJECT_ID(N'stg.Application')
  AND c.name=N'DAYS_REGISTRATION';

IF @type=N'decimal' AND @precision=28 AND @scale=12 AND @nullable=1
BEGIN
    PRINT 'PASS: DAYS_REGISTRATION already DECIMAL(28,12) NULL.';
END
ELSE IF @type=N'bigint' AND @nullable=1
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;
        ALTER TABLE [stg].[Application]
            ALTER COLUMN [DAYS_REGISTRATION] DECIMAL(28,12) NULL;
        COMMIT TRANSACTION;
        PRINT 'PASS: DAYS_REGISTRATION migrated BIGINT -> DECIMAL(28,12) NULL.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END
ELSE
    THROW 53401, 'Unexpected DAYS_REGISTRATION type/nullability; manual review required.', 1;

SELECT c.name AS ColumnName, TYPE_NAME(c.user_type_id) AS SqlType,
       c.precision AS NumericPrecision, c.scale AS NumericScale, c.is_nullable
FROM sys.columns c
WHERE c.object_id=OBJECT_ID(N'stg.Application') AND c.name=N'DAYS_REGISTRATION';
GO
