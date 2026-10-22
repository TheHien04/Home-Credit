/*
Purpose: Reconcile cleaned NDS rows and cleaning flags with staging.
Dependency: etl.usp_LoadNDS has completed for @BatchID.
*/

SET NOCOUNT ON;
GO

CREATE OR ALTER PROCEDURE etl.usp_ValidateNDS
    @BatchID BIGINT,
    @PersistResults BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Results TABLE
    (
        TestCode VARCHAR(100) NOT NULL,
        ObjectName NVARCHAR(256) NOT NULL,
        TestDescription NVARCHAR(1000) NOT NULL,
        ExpectedValue BIGINT NULL,
        ActualValue BIGINT NULL,
        TestStatus VARCHAR(10) NOT NULL
    );

    INSERT @Results
    SELECT 'NDS_APP_ROW_PARITY', N'nds.Applicant', N'Application rows with mandatory key are preserved.',
           (SELECT COUNT_BIG(*) FROM stg.Application WHERE BatchID = @BatchID AND SK_ID_CURR IS NOT NULL),
           (SELECT COUNT_BIG(*) FROM nds.Applicant WHERE SourceBatchID = @BatchID),
           CASE WHEN (SELECT COUNT_BIG(*) FROM stg.Application WHERE BatchID = @BatchID AND SK_ID_CURR IS NOT NULL)
                   = (SELECT COUNT_BIG(*) FROM nds.Applicant WHERE SourceBatchID = @BatchID) THEN 'PASS' ELSE 'FAIL' END
    UNION ALL
    SELECT 'NDS_PREV_ROW_PARITY', N'nds.PreviousApplication', N'Previous applications with mandatory keys are preserved.',
           (SELECT COUNT_BIG(*) FROM stg.PreviousApplication WHERE BatchID = @BatchID AND SK_ID_PREV IS NOT NULL AND SK_ID_CURR IS NOT NULL),
           (SELECT COUNT_BIG(*) FROM nds.PreviousApplication WHERE SourceBatchID = @BatchID),
           CASE WHEN (SELECT COUNT_BIG(*) FROM stg.PreviousApplication WHERE BatchID = @BatchID AND SK_ID_PREV IS NOT NULL AND SK_ID_CURR IS NOT NULL)
                   = (SELECT COUNT_BIG(*) FROM nds.PreviousApplication WHERE SourceBatchID = @BatchID) THEN 'PASS' ELSE 'FAIL' END
    UNION ALL
    SELECT 'NDS_BUREAU_ROW_PARITY', N'nds.BureauCredit', N'Bureau credits with mandatory keys are preserved.',
           (SELECT COUNT_BIG(*) FROM stg.BureauCredit WHERE BatchID = @BatchID AND SK_ID_BUREAU IS NOT NULL AND SK_ID_CURR IS NOT NULL),
           (SELECT COUNT_BIG(*) FROM nds.BureauCredit WHERE SourceBatchID = @BatchID),
           CASE WHEN (SELECT COUNT_BIG(*) FROM stg.BureauCredit WHERE BatchID = @BatchID AND SK_ID_BUREAU IS NOT NULL AND SK_ID_CURR IS NOT NULL)
                   = (SELECT COUNT_BIG(*) FROM nds.BureauCredit WHERE SourceBatchID = @BatchID) THEN 'PASS' ELSE 'FAIL' END
    UNION ALL
    SELECT 'NDS_BUREAU_MONTH_ROW_PARITY', N'nds.BureauMonthlyStatus', N'Bureau monthly rows with mandatory grain are preserved.',
           (SELECT COUNT_BIG(*) FROM stg.BureauBalance WHERE BatchID = @BatchID AND SK_ID_BUREAU IS NOT NULL AND MONTHS_BALANCE IS NOT NULL),
           (SELECT COUNT_BIG(*) FROM nds.BureauMonthlyStatus WHERE SourceBatchID = @BatchID),
           CASE WHEN (SELECT COUNT_BIG(*) FROM stg.BureauBalance WHERE BatchID = @BatchID AND SK_ID_BUREAU IS NOT NULL AND MONTHS_BALANCE IS NOT NULL)
                   = (SELECT COUNT_BIG(*) FROM nds.BureauMonthlyStatus WHERE SourceBatchID = @BatchID) THEN 'PASS' ELSE 'FAIL' END
    UNION ALL
    SELECT 'NDS_INSTALLMENT_ROW_PARITY', N'nds.InstallmentPayment', N'Installment rows with mandatory keys are preserved.',
           (SELECT COUNT_BIG(*) FROM stg.InstallmentPayment WHERE BatchID = @BatchID AND SK_ID_PREV IS NOT NULL AND SK_ID_CURR IS NOT NULL),
           (SELECT COUNT_BIG(*) FROM nds.InstallmentPayment WHERE SourceBatchID = @BatchID),
           CASE WHEN (SELECT COUNT_BIG(*) FROM stg.InstallmentPayment WHERE BatchID = @BatchID AND SK_ID_PREV IS NOT NULL AND SK_ID_CURR IS NOT NULL)
                   = (SELECT COUNT_BIG(*) FROM nds.InstallmentPayment WHERE SourceBatchID = @BatchID) THEN 'PASS' ELSE 'FAIL' END
    UNION ALL
    SELECT 'NDS_POS_ROW_PARITY', N'nds.POSCashMonthly', N'POS/cash monthly rows with mandatory grain are preserved.',
           (SELECT COUNT_BIG(*) FROM stg.POSCashBalance WHERE BatchID = @BatchID AND SK_ID_PREV IS NOT NULL AND SK_ID_CURR IS NOT NULL AND MONTHS_BALANCE IS NOT NULL),
           (SELECT COUNT_BIG(*) FROM nds.POSCashMonthly WHERE SourceBatchID = @BatchID),
           CASE WHEN (SELECT COUNT_BIG(*) FROM stg.POSCashBalance WHERE BatchID = @BatchID AND SK_ID_PREV IS NOT NULL AND SK_ID_CURR IS NOT NULL AND MONTHS_BALANCE IS NOT NULL)
                   = (SELECT COUNT_BIG(*) FROM nds.POSCashMonthly WHERE SourceBatchID = @BatchID) THEN 'PASS' ELSE 'FAIL' END
    UNION ALL
    SELECT 'NDS_CARD_ROW_PARITY', N'nds.CreditCardMonthly', N'Credit-card monthly rows with mandatory grain are preserved.',
           (SELECT COUNT_BIG(*) FROM stg.CreditCardBalance WHERE BatchID = @BatchID AND SK_ID_PREV IS NOT NULL AND SK_ID_CURR IS NOT NULL AND MONTHS_BALANCE IS NOT NULL),
           (SELECT COUNT_BIG(*) FROM nds.CreditCardMonthly WHERE SourceBatchID = @BatchID),
           CASE WHEN (SELECT COUNT_BIG(*) FROM stg.CreditCardBalance WHERE BatchID = @BatchID AND SK_ID_PREV IS NOT NULL AND SK_ID_CURR IS NOT NULL AND MONTHS_BALANCE IS NOT NULL)
                   = (SELECT COUNT_BIG(*) FROM nds.CreditCardMonthly WHERE SourceBatchID = @BatchID) THEN 'PASS' ELSE 'FAIL' END;

    INSERT @Results
    SELECT 'CLEAN_EMPLOYMENT_SENTINEL', N'nds.Applicant', N'Employment sentinel becomes null tenure and remains traceable by flag.',
           (SELECT COUNT_BIG(*) FROM stg.Application WHERE BatchID = @BatchID AND DAYS_EMPLOYED = 365243),
           (SELECT COUNT_BIG(*) FROM nds.Applicant WHERE SourceBatchID = @BatchID AND EmploymentSentinelFlag = 1 AND EmploymentTenureDays IS NULL),
           CASE WHEN (SELECT COUNT_BIG(*) FROM stg.Application WHERE BatchID = @BatchID AND DAYS_EMPLOYED = 365243)
                   = (SELECT COUNT_BIG(*) FROM nds.Applicant WHERE SourceBatchID = @BatchID AND EmploymentSentinelFlag = 1 AND EmploymentTenureDays IS NULL) THEN 'PASS' ELSE 'FAIL' END
    UNION ALL
    SELECT 'CLEAN_PREVIOUS_DATE_SENTINEL', N'nds.PreviousApplication', N'Rows containing any previous-date sentinel are flagged and all sentinel targets are null.',
           (SELECT COUNT_BIG(*) FROM stg.PreviousApplication WHERE BatchID = @BatchID AND
              (DAYS_FIRST_DRAWING = 365243 OR DAYS_FIRST_DUE = 365243 OR DAYS_LAST_DUE_1ST_VERSION = 365243 OR DAYS_LAST_DUE = 365243 OR DAYS_TERMINATION = 365243)),
           (SELECT COUNT_BIG(*) FROM nds.PreviousApplication WHERE SourceBatchID = @BatchID AND DateSentinelFlag = 1
              AND (FirstDrawingDaysRelative IS NULL OR FirstDrawingDaysRelative <> 365243)
              AND (FirstDueDaysRelative IS NULL OR FirstDueDaysRelative <> 365243)
              AND (LastDueFirstVersionDaysRelative IS NULL OR LastDueFirstVersionDaysRelative <> 365243)
              AND (LastDueDaysRelative IS NULL OR LastDueDaysRelative <> 365243)
              AND (TerminationDaysRelative IS NULL OR TerminationDaysRelative <> 365243)),
           CASE WHEN (SELECT COUNT_BIG(*) FROM stg.PreviousApplication WHERE BatchID = @BatchID AND
              (DAYS_FIRST_DRAWING = 365243 OR DAYS_FIRST_DUE = 365243 OR DAYS_LAST_DUE_1ST_VERSION = 365243 OR DAYS_LAST_DUE = 365243 OR DAYS_TERMINATION = 365243))
                   = (SELECT COUNT_BIG(*) FROM nds.PreviousApplication WHERE SourceBatchID = @BatchID AND DateSentinelFlag = 1
                      AND (FirstDrawingDaysRelative IS NULL OR FirstDrawingDaysRelative <> 365243)
                      AND (FirstDueDaysRelative IS NULL OR FirstDueDaysRelative <> 365243)
                      AND (LastDueFirstVersionDaysRelative IS NULL OR LastDueFirstVersionDaysRelative <> 365243)
                      AND (LastDueDaysRelative IS NULL OR LastDueDaysRelative <> 365243)
                      AND (TerminationDaysRelative IS NULL OR TerminationDaysRelative <> 365243)) THEN 'PASS' ELSE 'FAIL' END
    UNION ALL
    SELECT 'CLEAN_MISSING_PAYMENT', N'nds.InstallmentPayment', N'Missing payment date or amount is represented by PaymentRecordedFlag = 0.',
           (SELECT COUNT_BIG(*) FROM stg.InstallmentPayment WHERE BatchID = @BatchID AND (DAYS_ENTRY_PAYMENT IS NULL OR AMT_PAYMENT IS NULL)),
           (SELECT COUNT_BIG(*) FROM nds.InstallmentPayment WHERE SourceBatchID = @BatchID AND PaymentRecordedFlag = 0),
           CASE WHEN (SELECT COUNT_BIG(*) FROM stg.InstallmentPayment WHERE BatchID = @BatchID AND (DAYS_ENTRY_PAYMENT IS NULL OR AMT_PAYMENT IS NULL))
                   = (SELECT COUNT_BIG(*) FROM nds.InstallmentPayment WHERE SourceBatchID = @BatchID AND PaymentRecordedFlag = 0) THEN 'PASS' ELSE 'FAIL' END
    UNION ALL
    SELECT 'CLEAN_NEGATIVE_BUREAU_DEBT', N'nds.BureauCredit', N'Negative debt is retained and flagged rather than deleted.',
           (SELECT COUNT_BIG(*) FROM stg.BureauCredit WHERE BatchID = @BatchID AND AMT_CREDIT_SUM_DEBT < 0),
           (SELECT COUNT_BIG(*) FROM nds.BureauCredit WHERE SourceBatchID = @BatchID AND NegativeDebtFlag = 1),
           CASE WHEN (SELECT COUNT_BIG(*) FROM stg.BureauCredit WHERE BatchID = @BatchID AND AMT_CREDIT_SUM_DEBT < 0)
                   = (SELECT COUNT_BIG(*) FROM nds.BureauCredit WHERE SourceBatchID = @BatchID AND NegativeDebtFlag = 1) THEN 'PASS' ELSE 'FAIL' END
    UNION ALL
    SELECT 'TARGET_DEFAULT_COUNT', N'nds.LoanApplication', N'Train default count is unchanged after cleaning.',
           (SELECT COUNT_BIG(*) FROM stg.Application WHERE BatchID = @BatchID AND DatasetSplit = 'TRAIN' AND TARGET = 1),
           (SELECT COUNT_BIG(*) FROM nds.LoanApplication AS l JOIN nds.Applicant AS a ON a.ApplicationID = l.ApplicationID
              WHERE l.SourceBatchID = @BatchID AND a.DatasetSplit = 'TRAIN' AND l.TargetFlag = 1),
           CASE WHEN (SELECT COUNT_BIG(*) FROM stg.Application WHERE BatchID = @BatchID AND DatasetSplit = 'TRAIN' AND TARGET = 1)
                   = (SELECT COUNT_BIG(*) FROM nds.LoanApplication AS l JOIN nds.Applicant AS a ON a.ApplicationID = l.ApplicationID
                      WHERE l.SourceBatchID = @BatchID AND a.DatasetSplit = 'TRAIN' AND l.TargetFlag = 1) THEN 'PASS' ELSE 'FAIL' END;

    IF @PersistResults = 1
    BEGIN
        DELETE FROM ctl.DataQualityResult
        WHERE BatchID = @BatchID
          AND
          (
              TestCode LIKE 'NDS_%'
              OR TestCode LIKE 'CLEAN_%'
              OR TestCode = 'TARGET_DEFAULT_COUNT'
          );

        INSERT ctl.DataQualityResult
        (BatchID, TestCode, ObjectName, TestDescription, ExpectedValue, ActualValue, TestStatus)
        SELECT @BatchID, TestCode, ObjectName, TestDescription,
               CONVERT(NVARCHAR(200), ExpectedValue), CONVERT(NVARCHAR(200), ActualValue), TestStatus
        FROM @Results;
    END;

    SELECT TestCode, ObjectName, TestDescription, ExpectedValue, ActualValue, TestStatus
    FROM @Results
    ORDER BY CASE TestStatus WHEN 'FAIL' THEN 1 WHEN 'WARN' THEN 2 ELSE 3 END, TestCode;

    IF EXISTS (SELECT 1 FROM @Results WHERE TestStatus = 'FAIL')
        THROW 51020, 'NDS validation failed. Review the returned results and ctl.DataQualityResult.', 1;
END;
GO

/* Example:
EXEC etl.usp_ValidateNDS @BatchID = 1, @PersistResults = 1;
*/
