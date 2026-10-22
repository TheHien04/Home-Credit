/*
Purpose: Seed the Home Credit source-file registry.
Dependency: sql/00_admin/001_create_control_layer.sql
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

MERGE ctl.SourceFile AS target
USING
(
    VALUES
        (N'application_train.csv',              'CORE',      N'One current loan application',           N'SK_ID_CURR'),
        (N'previous_application.csv',           'CORE',      N'One previous Home Credit application',   N'SK_ID_PREV'),
        (N'bureau.csv',                         'CORE',      N'One external bureau credit',              N'SK_ID_BUREAU'),
        (N'bureau_balance.csv',                 'CORE',      N'One bureau credit in one relative month', N'SK_ID_BUREAU + MONTHS_BALANCE'),
        (N'installments_payments.csv',          'CORE',      N'One payment record for an installment',  N'To be confirmed by profiling'),
        (N'HomeCredit_columns_description.csv', 'METADATA',  N'One source-column description',          N'Table + Row'),
        (N'POS_CASH_balance.csv',               'EXTENSION', N'One POS/cash loan in one relative month',N'To be confirmed by profiling'),
        (N'credit_card_balance.csv',            'EXTENSION', N'One credit card in one relative month',  N'To be confirmed by profiling'),
        (N'application_test.csv',               'EXCLUDED',  N'One unlabeled Kaggle test application',  N'SK_ID_CURR'),
        (N'sample_submission.csv',              'EXCLUDED',  N'One Kaggle prediction output row',       N'SK_ID_CURR')
) AS source (FileName, ScopeName, ExpectedGrain, NaturalKeyRule)
ON target.FileName = source.FileName
WHEN MATCHED THEN
    UPDATE SET
        ScopeName = source.ScopeName,
        ExpectedGrain = source.ExpectedGrain,
        NaturalKeyRule = source.NaturalKeyRule,
        IsActive = 1
WHEN NOT MATCHED THEN
    INSERT (FileName, ScopeName, ExpectedGrain, NaturalKeyRule)
    VALUES (source.FileName, source.ScopeName, source.ExpectedGrain, source.NaturalKeyRule);
GO
