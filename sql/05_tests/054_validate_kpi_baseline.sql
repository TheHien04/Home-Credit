/*
Purpose: Compare deployed DDS populations and core KPI numerators with the
independently computed complete-file baseline from 22/10/2026.
*/

SET NOCOUNT ON;
GO

CREATE OR ALTER PROCEDURE etl.usp_ValidateKPIBaseline
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
        ExpectedValue BIGINT NOT NULL,
        ActualValue BIGINT NOT NULL,
        TestStatus VARCHAR(10) NOT NULL
    );

    INSERT @Results
    SELECT 'KPI_TOTAL_APPLICATIONS', N'dds.FactLoanApplication', N'Labeled TRAIN application denominator.',
           307511, COUNT_BIG(*), CASE WHEN COUNT_BIG(*) = 307511 THEN 'PASS' ELSE 'FAIL' END
    FROM dds.FactLoanApplication WHERE SourceBatchID = @BatchID
    UNION ALL
    SELECT 'KPI_DEFAULT_APPLICATIONS', N'dds.FactLoanApplication', N'Default numerator.',
           24825, COUNT_BIG(*), CASE WHEN COUNT_BIG(*) = 24825 THEN 'PASS' ELSE 'FAIL' END
    FROM dds.FactLoanApplication WHERE SourceBatchID = @BatchID AND DefaultFlag = 1
    UNION ALL
    SELECT 'KPI_PREVIOUS_APPLICATIONS', N'dds.FactPreviousApplication', N'TRAIN-linked previous-application denominator.',
           1413701, COUNT_BIG(*), CASE WHEN COUNT_BIG(*) = 1413701 THEN 'PASS' ELSE 'FAIL' END
    FROM dds.FactPreviousApplication WHERE SourceBatchID = @BatchID
    UNION ALL
    SELECT 'KPI_APPROVED_PREVIOUS', N'dds.FactPreviousApplication', N'Approved previous-application numerator.',
           886099, COUNT_BIG(*), CASE WHEN COUNT_BIG(*) = 886099 THEN 'PASS' ELSE 'FAIL' END
    FROM dds.FactPreviousApplication AS f
    JOIN dds.DimApplicationStatus AS s ON s.ApplicationStatusKey = f.ApplicationStatusKey
    WHERE f.SourceBatchID = @BatchID AND s.IsApproved = 1
    UNION ALL
    SELECT 'KPI_INSTALLMENT_ROWS', N'dds.FactInstallmentPayment', N'TRAIN-linked installment-payment population.',
           11591592, COUNT_BIG(*), CASE WHEN COUNT_BIG(*) = 11591592 THEN 'PASS' ELSE 'FAIL' END
    FROM dds.FactInstallmentPayment WHERE SourceBatchID = @BatchID
    UNION ALL
    SELECT 'KPI_RECORDED_PAYMENTS', N'dds.FactInstallmentPayment', N'Recorded-payment denominator.',
           11589009, COUNT_BIG(*), CASE WHEN COUNT_BIG(*) = 11589009 THEN 'PASS' ELSE 'FAIL' END
    FROM dds.FactInstallmentPayment WHERE SourceBatchID = @BatchID AND PaymentRecordedFlag = 1
    UNION ALL
    SELECT 'KPI_LATE_PAYMENTS', N'dds.FactInstallmentPayment', N'Late-payment numerator.',
           993629, COUNT_BIG(*), CASE WHEN COUNT_BIG(*) = 993629 THEN 'PASS' ELSE 'FAIL' END
    FROM dds.FactInstallmentPayment WHERE SourceBatchID = @BatchID AND LatePaymentFlag = 1
    UNION ALL
    SELECT 'KPI_BUREAU_CREDITS', N'dds.FactBureauCredit', N'TRAIN-linked bureau-credit population.',
           1465325, COUNT_BIG(*), CASE WHEN COUNT_BIG(*) = 1465325 THEN 'PASS' ELSE 'FAIL' END
    FROM dds.FactBureauCredit WHERE SourceBatchID = @BatchID
    UNION ALL
    SELECT 'KPI_ACTIVE_BUREAU_CREDITS', N'dds.FactBureauCredit', N'Active bureau-credit numerator.',
           541919, COUNT_BIG(*), CASE WHEN COUNT_BIG(*) = 541919 THEN 'PASS' ELSE 'FAIL' END
    FROM dds.FactBureauCredit AS f
    JOIN dds.DimCreditStatus AS s ON s.CreditStatusKey = f.CreditStatusKey
    WHERE f.SourceBatchID = @BatchID AND s.IsActive = 1
    UNION ALL
    SELECT 'KPI_BUREAU_MONTH_ROWS', N'dds.FactBureauMonthlySnapshot', N'TRAIN-linked plus unmatched bureau-month DDS scope.',
           17821796, COUNT_BIG(*), CASE WHEN COUNT_BIG(*) = 17821796 THEN 'PASS' ELSE 'FAIL' END
    FROM dds.FactBureauMonthlySnapshot WHERE SourceBatchID = @BatchID
    UNION ALL
    SELECT 'KPI_POS_MONTH_ROWS', N'dds.FactPOSCashMonthly', N'TRAIN-linked POS/cash monthly population.',
           8543375, COUNT_BIG(*), CASE WHEN COUNT_BIG(*) = 8543375 THEN 'PASS' ELSE 'FAIL' END
    FROM dds.FactPOSCashMonthly WHERE SourceBatchID = @BatchID
    UNION ALL
    SELECT 'KPI_CARD_MONTH_ROWS', N'dds.FactCreditCardMonthly', N'TRAIN-linked credit-card monthly population.',
           3227965, COUNT_BIG(*), CASE WHEN COUNT_BIG(*) = 3227965 THEN 'PASS' ELSE 'FAIL' END
    FROM dds.FactCreditCardMonthly WHERE SourceBatchID = @BatchID;

    IF @PersistResults = 1
    BEGIN
        DELETE FROM ctl.DataQualityResult
        WHERE BatchID = @BatchID AND TestCode LIKE 'KPI_%';

        INSERT ctl.DataQualityResult
            (BatchID, TestCode, ObjectName, TestDescription, ExpectedValue, ActualValue, TestStatus)
        SELECT @BatchID, TestCode, ObjectName, TestDescription,
               CONVERT(NVARCHAR(200), ExpectedValue), CONVERT(NVARCHAR(200), ActualValue), TestStatus
        FROM @Results;
    END;

    SELECT TestCode, ObjectName, TestDescription, ExpectedValue, ActualValue, TestStatus
    FROM @Results
    ORDER BY CASE TestStatus WHEN 'FAIL' THEN 1 ELSE 2 END, TestCode;

    IF EXISTS (SELECT 1 FROM @Results WHERE TestStatus = 'FAIL')
        THROW 51400, 'KPI baseline validation failed. DDS does not match the independent full-file scan.', 1;
END;
GO

/* Example:
EXEC etl.usp_ValidateKPIBaseline @BatchID = 1, @PersistResults = 1;
*/
