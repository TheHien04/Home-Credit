/*
Purpose: Fail deployment when a required schema object or seed set is missing.
This smoke test does not require source data.
*/

SET NOCOUNT ON;
GO

DECLARE @Expected TABLE
(
    SchemaName SYSNAME NOT NULL,
    ObjectName SYSNAME NOT NULL,
    ObjectType CHAR(2) NOT NULL
);

INSERT @Expected (SchemaName, ObjectName, ObjectType)
VALUES
    ('ctl', 'ETLBatch', 'U'),
    ('ctl', 'SourceFile', 'U'),
    ('ctl', 'ETLFileLoad', 'U'),
    ('ctl', 'RejectedRow', 'U'),
    ('ctl', 'DataQualityResult', 'U'),
    ('stg', 'Application', 'U'),
    ('stg', 'PreviousApplication', 'U'),
    ('stg', 'BureauCredit', 'U'),
    ('stg', 'BureauBalance', 'U'),
    ('stg', 'InstallmentPayment', 'U'),
    ('stg', 'POSCashBalance', 'U'),
    ('stg', 'CreditCardBalance', 'U'),
    ('nds', 'Applicant', 'U'),
    ('nds', 'LoanApplication', 'U'),
    ('nds', 'PreviousApplication', 'U'),
    ('nds', 'BureauCredit', 'U'),
    ('nds', 'BureauMonthlyStatus', 'U'),
    ('nds', 'InstallmentPayment', 'U'),
    ('nds', 'POSCashMonthly', 'U'),
    ('nds', 'CreditCardMonthly', 'U'),
    ('dds', 'DimApplicant', 'U'),
    ('dds', 'DimContract', 'U'),
    ('dds', 'DimApplicationStatus', 'U'),
    ('dds', 'DimCreditStatus', 'U'),
    ('dds', 'DimRelativeMonth', 'U'),
    ('dds', 'DimAffordabilityBand', 'U'),
    ('dds', 'FactLoanApplication', 'U'),
    ('dds', 'FactPreviousApplication', 'U'),
    ('dds', 'FactInstallmentPayment', 'U'),
    ('dds', 'FactBureauCredit', 'U'),
    ('dds', 'FactBureauMonthlySnapshot', 'U'),
    ('dds', 'FactPOSCashMonthly', 'U'),
    ('dds', 'FactCreditCardMonthly', 'U'),
    ('etl', 'vw_CleanApplicant', 'V'),
    ('etl', 'vw_CleanLoanApplication', 'V'),
    ('etl', 'vw_CleanPreviousApplication', 'V'),
    ('etl', 'vw_CleanBureauCredit', 'V'),
    ('etl', 'vw_CleanBureauMonthlyStatus', 'V'),
    ('etl', 'vw_CleanInstallmentPayment', 'V'),
    ('etl', 'vw_CleanPOSCashMonthly', 'V'),
    ('etl', 'vw_CleanCreditCardMonthly', 'V'),
    ('dds', 'vw_ApplicationAnalytics', 'V'),
    ('dds', 'vw_PreviousApplicationAnalytics', 'V'),
    ('dds', 'vw_InstallmentPaymentAnalytics', 'V'),
    ('dds', 'vw_BureauCreditAnalytics', 'V'),
    ('dds', 'vw_ExecutiveKPI', 'V'),
    ('dds', 'vw_PreviousApplicationKPI', 'V'),
    ('dds', 'vw_PaymentKPI', 'V'),
    ('dds', 'vw_BureauKPI', 'V'),
    ('ctl', 'usp_StartETLBatch', 'P'),
    ('ctl', 'usp_StartFileLoad', 'P'),
    ('ctl', 'usp_EndFileLoad', 'P'),
    ('ctl', 'usp_EndETLBatch', 'P'),
    ('ctl', 'usp_ValidateHomeCreditStaging', 'P'),
    ('etl', 'usp_LoadNDS', 'P'),
    ('etl', 'usp_ValidateNDS', 'P'),
    ('etl', 'usp_LoadDDS', 'P'),
    ('etl', 'usp_ValidateDDS', 'P'),
    ('etl', 'usp_ValidateKPIBaseline', 'P');

SELECT e.SchemaName, e.ObjectName, e.ObjectType
FROM @Expected AS e
LEFT JOIN sys.schemas AS s ON s.name = e.SchemaName
LEFT JOIN sys.objects AS o
  ON o.schema_id = s.schema_id
 AND o.name = e.ObjectName
 AND o.type = e.ObjectType
WHERE o.object_id IS NULL;

IF EXISTS
(
    SELECT 1
    FROM @Expected AS e
    LEFT JOIN sys.schemas AS s ON s.name = e.SchemaName
    LEFT JOIN sys.objects AS o
      ON o.schema_id = s.schema_id
     AND o.name = e.ObjectName
     AND o.type = e.ObjectType
    WHERE o.object_id IS NULL
)
    THROW 51300, 'Schema smoke test failed: one or more required objects are missing.', 1;

IF
(
    SELECT COUNT(*)
    FROM ctl.SourceFile
    WHERE FileName IN
    (
        N'application_train.csv', N'application_test.csv', N'previous_application.csv',
        N'bureau.csv', N'bureau_balance.csv', N'installments_payments.csv',
        N'POS_CASH_balance.csv', N'credit_card_balance.csv',
        N'HomeCredit_columns_description.csv', N'sample_submission.csv'
    )
) <> 10
    THROW 51301, 'Source-file registry is missing one or more required Home Credit files.', 1;

IF (SELECT COUNT(*) FROM dds.DimAffordabilityBand) <> 5
    THROW 51302, 'Affordability dimension must contain exactly 5 seeded bands.', 1;

SELECT
    N'PASS' AS SmokeTestStatus,
    (SELECT COUNT(*) FROM @Expected) AS RequiredObjectsFound,
    (SELECT COUNT(*) FROM ctl.SourceFile) AS RegisteredSourceFiles,
    (SELECT COUNT(*) FROM dds.DimAffordabilityBand) AS AffordabilityBands;
GO
