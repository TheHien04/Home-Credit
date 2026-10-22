/*
Purpose: Validate DDS grain, TRAIN scope, row reconciliation and KPI invariants.
Dependency: etl.usp_LoadDDS has completed for @BatchID.
*/

SET NOCOUNT ON;
GO

CREATE OR ALTER PROCEDURE etl.usp_ValidateDDS
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

    DECLARE @Expected BIGINT;
    DECLARE @Actual BIGINT;

    SELECT @Expected = COUNT_BIG(*)
    FROM nds.Applicant AS a
    JOIN nds.LoanApplication AS l ON l.ApplicationID = a.ApplicationID
    WHERE a.SourceBatchID = @BatchID AND l.SourceBatchID = @BatchID
      AND a.DatasetSplit = 'TRAIN' AND l.TargetFlag IS NOT NULL;
    SELECT @Actual = COUNT_BIG(*) FROM dds.FactLoanApplication WHERE SourceBatchID = @BatchID;
    INSERT @Results VALUES
        ('DDS_LOAN_ROW_PARITY', N'dds.FactLoanApplication', N'One labeled TRAIN row becomes one current-loan fact.',
         @Expected, @Actual, CASE WHEN @Expected = @Actual THEN 'PASS' ELSE 'FAIL' END);

    SELECT @Expected = COUNT_BIG(*)
    FROM nds.LoanApplication AS l
    JOIN nds.Applicant AS a ON a.ApplicationID = l.ApplicationID
    WHERE l.SourceBatchID = @BatchID AND a.DatasetSplit = 'TRAIN' AND l.TargetFlag = 1;
    SELECT @Actual = COUNT_BIG(*) FROM dds.FactLoanApplication WHERE SourceBatchID = @BatchID AND DefaultFlag = 1;
    INSERT @Results VALUES
        ('DDS_DEFAULT_COUNT_PARITY', N'dds.FactLoanApplication', N'Default numerator is unchanged from NDS.',
         @Expected, @Actual, CASE WHEN @Expected = @Actual THEN 'PASS' ELSE 'FAIL' END);

    SELECT @Expected = COUNT_BIG(*) + 1 FROM nds.Applicant WHERE SourceBatchID = @BatchID AND DatasetSplit = 'TRAIN';
    SELECT @Actual = COUNT_BIG(*) FROM dds.DimApplicant WHERE SourceBatchID = @BatchID;
    INSERT @Results VALUES
        ('DDS_APPLICANT_DIM_PARITY', N'dds.DimApplicant', N'TRAIN applicants plus exactly one unknown member.',
         @Expected, @Actual, CASE WHEN @Expected = @Actual THEN 'PASS' ELSE 'FAIL' END);

    SELECT @Expected = COUNT_BIG(*)
    FROM nds.PreviousApplication AS p
    JOIN nds.Applicant AS a ON a.ApplicationID = p.ApplicationID
    WHERE p.SourceBatchID = @BatchID AND a.DatasetSplit = 'TRAIN';
    SELECT @Actual = COUNT_BIG(*) FROM dds.FactPreviousApplication WHERE SourceBatchID = @BatchID;
    INSERT @Results VALUES
        ('DDS_PREVIOUS_ROW_PARITY', N'dds.FactPreviousApplication', N'Previous applications are limited to TRAIN applicants without row loss.',
         @Expected, @Actual, CASE WHEN @Expected = @Actual THEN 'PASS' ELSE 'FAIL' END);

    SELECT @Expected = COUNT_BIG(*)
    FROM nds.InstallmentPayment AS i
    JOIN nds.Applicant AS a ON a.ApplicationID = i.ApplicationID
    WHERE i.SourceBatchID = @BatchID AND a.DatasetSplit = 'TRAIN';
    SELECT @Actual = COUNT_BIG(*) FROM dds.FactInstallmentPayment WHERE SourceBatchID = @BatchID;
    INSERT @Results VALUES
        ('DDS_INSTALLMENT_ROW_PARITY', N'dds.FactInstallmentPayment', N'Installment payments are limited to TRAIN applicants without row loss.',
         @Expected, @Actual, CASE WHEN @Expected = @Actual THEN 'PASS' ELSE 'FAIL' END);

    SELECT @Expected = COUNT_BIG(*)
    FROM nds.BureauCredit AS b
    JOIN nds.Applicant AS a ON a.ApplicationID = b.ApplicationID
    WHERE b.SourceBatchID = @BatchID AND a.DatasetSplit = 'TRAIN';
    SELECT @Actual = COUNT_BIG(*) FROM dds.FactBureauCredit WHERE SourceBatchID = @BatchID;
    INSERT @Results VALUES
        ('DDS_BUREAU_ROW_PARITY', N'dds.FactBureauCredit', N'Bureau credits are limited to TRAIN applicants without row loss.',
         @Expected, @Actual, CASE WHEN @Expected = @Actual THEN 'PASS' ELSE 'FAIL' END);

    SELECT @Expected = COUNT_BIG(*)
    FROM nds.BureauMonthlyStatus AS m
    LEFT JOIN nds.BureauCredit AS b
      ON b.BureauCreditID = m.BureauCreditID AND b.SourceBatchID = @BatchID
    LEFT JOIN nds.Applicant AS a ON a.ApplicationID = b.ApplicationID
    WHERE m.SourceBatchID = @BatchID
      AND (a.DatasetSplit = 'TRAIN' OR b.BureauCreditID IS NULL);
    SELECT @Actual = COUNT_BIG(*) FROM dds.FactBureauMonthlySnapshot WHERE SourceBatchID = @BatchID;
    INSERT @Results VALUES
        ('DDS_BUREAU_MONTH_ROW_PARITY', N'dds.FactBureauMonthlySnapshot', N'TRAIN-linked and unmatched bureau monthly rows are preserved.',
         @Expected, @Actual, CASE WHEN @Expected = @Actual THEN 'PASS' ELSE 'FAIL' END);

    SELECT @Expected = COUNT_BIG(*)
    FROM nds.POSCashMonthly AS m
    JOIN nds.Applicant AS a ON a.ApplicationID = m.ApplicationID
    WHERE m.SourceBatchID = @BatchID AND a.DatasetSplit = 'TRAIN';
    SELECT @Actual = COUNT_BIG(*) FROM dds.FactPOSCashMonthly WHERE SourceBatchID = @BatchID;
    INSERT @Results VALUES
        ('DDS_POS_ROW_PARITY', N'dds.FactPOSCashMonthly', N'POS/cash monthly snapshots are limited to TRAIN applicants without row loss.',
         @Expected, @Actual, CASE WHEN @Expected = @Actual THEN 'PASS' ELSE 'FAIL' END);

    SELECT @Expected = COUNT_BIG(*)
    FROM nds.CreditCardMonthly AS m
    JOIN nds.Applicant AS a ON a.ApplicationID = m.ApplicationID
    WHERE m.SourceBatchID = @BatchID AND a.DatasetSplit = 'TRAIN';
    SELECT @Actual = COUNT_BIG(*) FROM dds.FactCreditCardMonthly WHERE SourceBatchID = @BatchID;
    INSERT @Results VALUES
        ('DDS_CARD_ROW_PARITY', N'dds.FactCreditCardMonthly', N'Credit-card monthly snapshots are limited to TRAIN applicants without row loss.',
         @Expected, @Actual, CASE WHEN @Expected = @Actual THEN 'PASS' ELSE 'FAIL' END);

    SELECT @Expected = 0;
    SELECT @Actual = COUNT_BIG(*)
    FROM dds.FactLoanApplication
    WHERE SourceBatchID = @BatchID
      AND ((IncomeAmount IS NULL OR IncomeAmount <= 0)
           AND (CreditToIncomeRatio IS NOT NULL OR AnnuityToIncomeRatio IS NOT NULL));
    INSERT @Results VALUES
        ('DDS_RATIO_DENOMINATOR_GUARD', N'dds.FactLoanApplication', N'Ratios remain null when income is missing or non-positive.',
         @Expected, @Actual, CASE WHEN @Expected = @Actual THEN 'PASS' ELSE 'FAIL' END);

    SELECT @Expected = COUNT_BIG(*)
    FROM nds.InstallmentPayment AS i
    JOIN nds.Applicant AS a ON a.ApplicationID = i.ApplicationID
    WHERE i.SourceBatchID = @BatchID AND a.DatasetSplit = 'TRAIN'
      AND i.PaymentRecordedFlag = 1 AND i.DaysLate > 0;
    SELECT @Actual = COUNT_BIG(*)
    FROM dds.FactInstallmentPayment
    WHERE SourceBatchID = @BatchID AND LatePaymentFlag = 1;
    INSERT @Results VALUES
        ('DDS_LATE_PAYMENT_FLAG_PARITY', N'dds.FactInstallmentPayment', N'Late-payment numerator follows the signed-day rule.',
         @Expected, @Actual, CASE WHEN @Expected = @Actual THEN 'PASS' ELSE 'FAIL' END);

    SELECT @Expected = 1;
    SELECT @Actual = COUNT_BIG(*) FROM dds.DimApplicant WHERE SourceBatchID = @BatchID AND IsUnknown = 1;
    INSERT @Results VALUES
        ('DDS_UNKNOWN_APPLICANT_SINGLETON', N'dds.DimApplicant', N'Exactly one unknown applicant member exists.',
         @Expected, @Actual, CASE WHEN @Expected = @Actual THEN 'PASS' ELSE 'FAIL' END);

    IF @PersistResults = 1
    BEGIN
        DELETE FROM ctl.DataQualityResult
        WHERE BatchID = @BatchID AND TestCode LIKE 'DDS_%';

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
        THROW 51120, 'DDS validation failed. Review the returned results and ctl.DataQualityResult.', 1;
END;
GO

/* Example:
EXEC etl.usp_ValidateDDS @BatchID = 1, @PersistResults = 1;
*/
