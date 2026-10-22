/*
Purpose: Persist core staging quality checks for one ETL batch.
Dependency: control layer and all seven staging tables.
Usage: EXEC [ctl].[usp_ValidateHomeCreditStaging] @BatchID = 1;
*/

CREATE OR ALTER PROCEDURE [ctl].[usp_ValidateHomeCreditStaging]
    @BatchID BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM [ctl].[ETLBatch] WHERE [BatchID] = @BatchID)
        THROW 50001, 'Unknown BatchID.', 1;

    DELETE FROM [ctl].[DataQualityResult]
    WHERE [BatchID] = @BatchID
      AND [TestCode] LIKE 'STG_%';

    DECLARE @Actual BIGINT;

    SELECT @Actual = COUNT_BIG(*) - COUNT_BIG(DISTINCT [SK_ID_CURR])
    FROM [stg].[Application]
    WHERE [BatchID] = @BatchID;

    INSERT [ctl].[DataQualityResult]
        ([BatchID], [TestCode], [ObjectName], [TestDescription],
         [ExpectedValue], [ActualValue], [TestStatus])
    VALUES
        (@BatchID, 'STG_APP_DUPLICATE_KEY', 'stg.Application',
         'Duplicate SK_ID_CURR rows within the batch', '0', CONVERT(NVARCHAR(200), @Actual),
         CASE WHEN @Actual = 0 THEN 'PASS' ELSE 'FAIL' END);

    SELECT @Actual = COUNT_BIG(*)
    FROM [stg].[Application]
    WHERE [BatchID] = @BatchID
      AND ([SK_ID_CURR] IS NULL OR [TARGET] NOT IN (0, 1)
           OR ([DatasetSplit] = 'TRAIN' AND [TARGET] IS NULL)
           OR ([DatasetSplit] = 'TEST' AND [TARGET] IS NOT NULL));

    INSERT [ctl].[DataQualityResult]
        ([BatchID], [TestCode], [ObjectName], [TestDescription],
         [ExpectedValue], [ActualValue], [TestStatus])
    VALUES
        (@BatchID, 'STG_APP_INVALID_CORE', 'stg.Application',
         'Missing key or invalid split/target combination', '0', CONVERT(NVARCHAR(200), @Actual),
         CASE WHEN @Actual = 0 THEN 'PASS' ELSE 'FAIL' END);

    SELECT @Actual = COUNT_BIG(*)
    FROM [stg].[Application]
    WHERE [BatchID] = @BatchID
      AND [DAYS_EMPLOYED] = 365243;

    INSERT [ctl].[DataQualityResult]
        ([BatchID], [TestCode], [ObjectName], [TestDescription],
         [ExpectedValue], [ActualValue], [TestStatus])
    VALUES
        (@BatchID, 'STG_DAYS_EMPLOYED_SENTINEL', 'stg.Application',
         'Rows requiring DAYS_EMPLOYED sentinel normalization', 'Informational',
         CONVERT(NVARCHAR(200), @Actual), 'WARN');

    SELECT @Actual = COUNT_BIG(*)
    FROM [stg].[POSCashBalance] AS child
    LEFT JOIN [stg].[PreviousApplication] AS parent
      ON parent.[BatchID] = child.[BatchID]
     AND parent.[SK_ID_PREV] = child.[SK_ID_PREV]
    WHERE child.[BatchID] = @BatchID
      AND parent.[StagingRowID] IS NULL;

    INSERT [ctl].[DataQualityResult]
        ([BatchID], [TestCode], [ObjectName], [TestDescription],
         [ExpectedValue], [ActualValue], [TestStatus])
    VALUES
        (@BatchID, 'STG_POS_PREV_UNMATCHED', 'stg.POSCashBalance',
         'SK_ID_PREV absent from supplied previous applications', 'Review, do not reject',
         CONVERT(NVARCHAR(200), @Actual), CASE WHEN @Actual = 0 THEN 'PASS' ELSE 'WARN' END);

    SELECT @Actual = COUNT_BIG(*)
    FROM [stg].[CreditCardBalance] AS child
    LEFT JOIN [stg].[PreviousApplication] AS parent
      ON parent.[BatchID] = child.[BatchID]
     AND parent.[SK_ID_PREV] = child.[SK_ID_PREV]
    WHERE child.[BatchID] = @BatchID
      AND parent.[StagingRowID] IS NULL;

    INSERT [ctl].[DataQualityResult]
        ([BatchID], [TestCode], [ObjectName], [TestDescription],
         [ExpectedValue], [ActualValue], [TestStatus])
    VALUES
        (@BatchID, 'STG_CC_PREV_UNMATCHED', 'stg.CreditCardBalance',
         'SK_ID_PREV absent from supplied previous applications', 'Review, do not reject',
         CONVERT(NVARCHAR(200), @Actual), CASE WHEN @Actual = 0 THEN 'PASS' ELSE 'WARN' END);

    SELECT @Actual = COUNT_BIG(*)
    FROM [stg].[InstallmentPayment] AS child
    LEFT JOIN [stg].[PreviousApplication] AS parent
      ON parent.[BatchID] = child.[BatchID]
     AND parent.[SK_ID_PREV] = child.[SK_ID_PREV]
    WHERE child.[BatchID] = @BatchID
      AND parent.[StagingRowID] IS NULL;

    INSERT [ctl].[DataQualityResult]
        ([BatchID], [TestCode], [ObjectName], [TestDescription],
         [ExpectedValue], [ActualValue], [TestStatus])
    VALUES
        (@BatchID, 'STG_INSTALLMENT_PREV_UNMATCHED', 'stg.InstallmentPayment',
         'SK_ID_PREV absent from supplied previous applications', 'Review, do not reject',
         CONVERT(NVARCHAR(200), @Actual), CASE WHEN @Actual = 0 THEN 'PASS' ELSE 'WARN' END);

    SELECT @Actual = COUNT_BIG(*)
    FROM [stg].[BureauBalance] AS child
    LEFT JOIN [stg].[BureauCredit] AS parent
      ON parent.[BatchID] = child.[BatchID]
     AND parent.[SK_ID_BUREAU] = child.[SK_ID_BUREAU]
    WHERE child.[BatchID] = @BatchID
      AND parent.[StagingRowID] IS NULL;

    INSERT [ctl].[DataQualityResult]
        ([BatchID], [TestCode], [ObjectName], [TestDescription],
         [ExpectedValue], [ActualValue], [TestStatus])
    VALUES
        (@BatchID, 'STG_BUREAU_BALANCE_UNMATCHED', 'stg.BureauBalance',
         'SK_ID_BUREAU absent from supplied bureau credits', 'Review, do not reject',
         CONVERT(NVARCHAR(200), @Actual), CASE WHEN @Actual = 0 THEN 'PASS' ELSE 'WARN' END);

    SELECT
        [TestCode], [ObjectName], [ExpectedValue], [ActualValue], [TestStatus]
    FROM [ctl].[DataQualityResult]
    WHERE [BatchID] = @BatchID
      AND [TestCode] LIKE 'STG_%'
    ORDER BY [TestStatus], [TestCode];
END;
GO
