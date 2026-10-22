/*
Purpose: Load the cleaned Home Credit NDS from one complete staging batch.
Safety: Existing NDS data is replaced only when @ConfirmReplace = 1.
Raw and staging data are never modified.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

CREATE OR ALTER PROCEDURE etl.usp_LoadNDS
    @BatchID BIGINT,
    @ConfirmReplace BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM ctl.ETLBatch WHERE BatchID = @BatchID)
        THROW 51000, 'BatchID does not exist in ctl.ETLBatch.', 1;

    IF NOT EXISTS (SELECT 1 FROM stg.Application WHERE BatchID = @BatchID)
       OR NOT EXISTS (SELECT 1 FROM stg.PreviousApplication WHERE BatchID = @BatchID)
       OR NOT EXISTS (SELECT 1 FROM stg.BureauCredit WHERE BatchID = @BatchID)
       OR NOT EXISTS (SELECT 1 FROM stg.BureauBalance WHERE BatchID = @BatchID)
       OR NOT EXISTS (SELECT 1 FROM stg.InstallmentPayment WHERE BatchID = @BatchID)
       OR NOT EXISTS (SELECT 1 FROM stg.POSCashBalance WHERE BatchID = @BatchID)
       OR NOT EXISTS (SELECT 1 FROM stg.CreditCardBalance WHERE BatchID = @BatchID)
        THROW 51001, 'Selected batch is incomplete; all seven staging tables must contain rows.', 1;

    IF EXISTS
    (
        SELECT 1 FROM stg.Application
        WHERE BatchID = @BatchID
          AND (SK_ID_CURR IS NULL
               OR (DatasetSplit = 'TRAIN' AND (TARGET IS NULL OR TARGET NOT IN (0, 1)))
               OR (DatasetSplit = 'TEST' AND TARGET IS NOT NULL))
    )
       OR EXISTS (SELECT 1 FROM stg.PreviousApplication WHERE BatchID = @BatchID AND (SK_ID_PREV IS NULL OR SK_ID_CURR IS NULL))
       OR EXISTS (SELECT 1 FROM stg.BureauCredit WHERE BatchID = @BatchID AND (SK_ID_BUREAU IS NULL OR SK_ID_CURR IS NULL))
       OR EXISTS (SELECT 1 FROM stg.BureauBalance WHERE BatchID = @BatchID AND (SK_ID_BUREAU IS NULL OR MONTHS_BALANCE IS NULL))
       OR EXISTS (SELECT 1 FROM stg.InstallmentPayment WHERE BatchID = @BatchID AND (SK_ID_PREV IS NULL OR SK_ID_CURR IS NULL))
       OR EXISTS (SELECT 1 FROM stg.POSCashBalance WHERE BatchID = @BatchID AND (SK_ID_PREV IS NULL OR SK_ID_CURR IS NULL OR MONTHS_BALANCE IS NULL))
       OR EXISTS (SELECT 1 FROM stg.CreditCardBalance WHERE BatchID = @BatchID AND (SK_ID_PREV IS NULL OR SK_ID_CURR IS NULL OR MONTHS_BALANCE IS NULL))
        THROW 51006, 'Mandatory key, grain, split, or target validation failed in staging.', 1;

    IF EXISTS
    (
        SELECT ApplicationID
        FROM etl.vw_CleanApplicant
        WHERE SourceBatchID = @BatchID
        GROUP BY ApplicationID
        HAVING COUNT_BIG(*) > 1
    )
        THROW 51002, 'Duplicate ApplicationID exists in the selected staging batch.', 1;

    IF EXISTS
    (
        SELECT PreviousApplicationID
        FROM etl.vw_CleanPreviousApplication
        WHERE SourceBatchID = @BatchID
        GROUP BY PreviousApplicationID
        HAVING COUNT_BIG(*) > 1
    )
        THROW 51003, 'Duplicate PreviousApplicationID exists in the selected staging batch.', 1;

    IF EXISTS
    (
        SELECT BureauCreditID
        FROM etl.vw_CleanBureauCredit
        WHERE SourceBatchID = @BatchID
        GROUP BY BureauCreditID
        HAVING COUNT_BIG(*) > 1
    )
        THROW 51004, 'Duplicate BureauCreditID exists in the selected staging batch.', 1;

    IF
    (
        EXISTS (SELECT 1 FROM nds.Applicant)
        OR EXISTS (SELECT 1 FROM nds.LoanApplication)
        OR EXISTS (SELECT 1 FROM nds.PreviousApplication)
        OR EXISTS (SELECT 1 FROM nds.BureauCredit)
        OR EXISTS (SELECT 1 FROM nds.BureauMonthlyStatus)
        OR EXISTS (SELECT 1 FROM nds.InstallmentPayment)
        OR EXISTS (SELECT 1 FROM nds.POSCashMonthly)
        OR EXISTS (SELECT 1 FROM nds.CreditCardMonthly)
    ) AND @ConfirmReplace = 0
        THROW 51005, 'NDS is not empty. Re-run with @ConfirmReplace = 1 only after verifying the selected batch.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @ConfirmReplace = 1
        BEGIN
            DELETE FROM nds.CreditCardMonthly;
            DELETE FROM nds.POSCashMonthly;
            DELETE FROM nds.InstallmentPayment;
            DELETE FROM nds.BureauMonthlyStatus;
            DELETE FROM nds.BureauCredit;
            DELETE FROM nds.PreviousApplication;
            DELETE FROM nds.LoanApplication;
            DELETE FROM nds.Applicant;
        END;

        INSERT nds.Applicant
        (
            ApplicationID, DatasetSplit, GenderCode, OwnCarFlag, OwnRealtyFlag,
            ChildrenCount, IncomeAmount, IncomeType, EducationType, FamilyStatus,
            HousingType, AgeYears, EmploymentTenureDays, EmploymentSentinelFlag,
            OccupationType, OrganizationType, FamilyMemberCount,
            RegionPopulationRelative, RegionRating, RegionCityRating, CarAgeYears,
            GenderUnknownFlag, SourceBatchID
        )
        SELECT
            ApplicationID, DatasetSplit, GenderCode, OwnCarFlag, OwnRealtyFlag,
            ChildrenCount, IncomeAmount, IncomeType, EducationType, FamilyStatus,
            HousingType, AgeYears, EmploymentTenureDays, EmploymentSentinelFlag,
            OccupationType, OrganizationType, FamilyMemberCount,
            RegionPopulationRelative, RegionRating, RegionCityRating, CarAgeYears,
            GenderUnknownFlag, SourceBatchID
        FROM etl.vw_CleanApplicant
        WHERE SourceBatchID = @BatchID;

        INSERT nds.LoanApplication
        (
            ApplicationID, TargetFlag, ContractType, CreditAmount, AnnuityAmount,
            GoodsPriceAmount, SuiteType, ApplicationWeekday, ApplicationHour,
            ExternalScore1, ExternalScore2, ExternalScore3, MissingAnnuityFlag,
            MissingGoodsPriceFlag, SourceBatchID
        )
        SELECT
            ApplicationID, TargetFlag, ContractType, CreditAmount, AnnuityAmount,
            GoodsPriceAmount, SuiteType, ApplicationWeekday, ApplicationHour,
            ExternalScore1, ExternalScore2, ExternalScore3, MissingAnnuityFlag,
            MissingGoodsPriceFlag, SourceBatchID
        FROM etl.vw_CleanLoanApplication
        WHERE SourceBatchID = @BatchID;

        INSERT nds.PreviousApplication
        (
            PreviousApplicationID, ApplicationID, ContractType, ContractStatus,
            ClientType, PortfolioType, ProductType, ApplicationAmount, CreditAmount,
            AnnuityAmount, DownPaymentAmount, GoodsPriceAmount, DecisionDaysRelative,
            PaymentCount, FirstDrawingDaysRelative, FirstDueDaysRelative,
            LastDueFirstVersionDaysRelative, LastDueDaysRelative,
            TerminationDaysRelative, DateSentinelFlag,
            NonPositivePaymentCountFlag, NegativeAmountFlag, SourceBatchID
        )
        SELECT
            PreviousApplicationID, ApplicationID, ContractType, ContractStatus,
            ClientType, PortfolioType, ProductType, ApplicationAmount, CreditAmount,
            AnnuityAmount, DownPaymentAmount, GoodsPriceAmount, DecisionDaysRelative,
            PaymentCount, FirstDrawingDaysRelative, FirstDueDaysRelative,
            LastDueFirstVersionDaysRelative, LastDueDaysRelative,
            TerminationDaysRelative, DateSentinelFlag,
            NonPositivePaymentCountFlag, NegativeAmountFlag, SourceBatchID
        FROM etl.vw_CleanPreviousApplication
        WHERE SourceBatchID = @BatchID;

        INSERT nds.BureauCredit
        (
            BureauCreditID, ApplicationID, CreditStatus, CreditCurrency, CreditType,
            CreditDaysRelative, CreditEndDaysRelative, ActualEndDaysRelative,
            UpdateDaysRelative, OverdueDays, CreditAmount, DebtAmount,
            CreditLimitAmount, OverdueAmount, MaxOverdueAmount, AnnuityAmount,
            ProlongationCount, NegativeDebtFlag, SourceBatchID
        )
        SELECT
            BureauCreditID, ApplicationID, CreditStatus, CreditCurrency, CreditType,
            CreditDaysRelative, CreditEndDaysRelative, ActualEndDaysRelative,
            UpdateDaysRelative, OverdueDays, CreditAmount, DebtAmount,
            CreditLimitAmount, OverdueAmount, MaxOverdueAmount, AnnuityAmount,
            ProlongationCount, NegativeDebtFlag, SourceBatchID
        FROM etl.vw_CleanBureauCredit
        WHERE SourceBatchID = @BatchID;

        INSERT nds.BureauMonthlyStatus
        (BureauCreditID, RelativeMonth, StatusCode, ParentMissingFlag, SourceRowNumber, SourceBatchID)
        SELECT BureauCreditID, RelativeMonth, StatusCode, ParentMissingFlag, SourceRowNumber, SourceBatchID
        FROM etl.vw_CleanBureauMonthlyStatus
        WHERE SourceBatchID = @BatchID;

        INSERT nds.InstallmentPayment
        (
            PreviousApplicationID, ApplicationID, InstallmentVersion,
            InstallmentNumber, DueDaysRelative, PaymentDaysRelative,
            ScheduledAmount, PaidAmount, PaymentDelayDays, DaysLate,
            PaymentVarianceAmount, PaymentRecordedFlag, ParentMissingFlag,
            SourceRowNumber, SourceBatchID
        )
        SELECT
            PreviousApplicationID, ApplicationID, InstallmentVersion,
            InstallmentNumber, DueDaysRelative, PaymentDaysRelative,
            ScheduledAmount, PaidAmount, PaymentDelayDays, DaysLate,
            PaymentVarianceAmount, PaymentRecordedFlag, ParentMissingFlag,
            SourceRowNumber, SourceBatchID
        FROM etl.vw_CleanInstallmentPayment
        WHERE SourceBatchID = @BatchID;

        INSERT nds.POSCashMonthly
        (
            PreviousApplicationID, ApplicationID, RelativeMonth, InstallmentCount,
            FutureInstallmentCount, ContractStatus, DaysPastDue,
            DaysPastDueTolerance, ParentMissingFlag, SourceRowNumber, SourceBatchID
        )
        SELECT
            PreviousApplicationID, ApplicationID, RelativeMonth, InstallmentCount,
            FutureInstallmentCount, ContractStatus, DaysPastDue,
            DaysPastDueTolerance, ParentMissingFlag, SourceRowNumber, SourceBatchID
        FROM etl.vw_CleanPOSCashMonthly
        WHERE SourceBatchID = @BatchID;

        INSERT nds.CreditCardMonthly
        (
            PreviousApplicationID, ApplicationID, RelativeMonth, BalanceAmount,
            CreditLimitAmount, DrawingsAmount, MinimumInstallmentAmount,
            CurrentPaymentAmount, TotalPaymentAmount, PrincipalReceivableAmount,
            TotalReceivableAmount, ContractStatus, DaysPastDue,
            DaysPastDueTolerance, NegativeLimitFlag, ParentMissingFlag,
            SourceRowNumber, SourceBatchID
        )
        SELECT
            PreviousApplicationID, ApplicationID, RelativeMonth, BalanceAmount,
            CreditLimitAmount, DrawingsAmount, MinimumInstallmentAmount,
            CurrentPaymentAmount, TotalPaymentAmount, PrincipalReceivableAmount,
            TotalReceivableAmount, ContractStatus, DaysPastDue,
            DaysPastDueTolerance, NegativeLimitFlag, ParentMissingFlag,
            SourceRowNumber, SourceBatchID
        FROM etl.vw_CleanCreditCardMonthly
        WHERE SourceBatchID = @BatchID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT N'Applicant' AS ObjectName, COUNT_BIG(*) AS RowCount FROM nds.Applicant WHERE SourceBatchID = @BatchID
    UNION ALL SELECT N'LoanApplication', COUNT_BIG(*) FROM nds.LoanApplication WHERE SourceBatchID = @BatchID
    UNION ALL SELECT N'PreviousApplication', COUNT_BIG(*) FROM nds.PreviousApplication WHERE SourceBatchID = @BatchID
    UNION ALL SELECT N'BureauCredit', COUNT_BIG(*) FROM nds.BureauCredit WHERE SourceBatchID = @BatchID
    UNION ALL SELECT N'BureauMonthlyStatus', COUNT_BIG(*) FROM nds.BureauMonthlyStatus WHERE SourceBatchID = @BatchID
    UNION ALL SELECT N'InstallmentPayment', COUNT_BIG(*) FROM nds.InstallmentPayment WHERE SourceBatchID = @BatchID
    UNION ALL SELECT N'POSCashMonthly', COUNT_BIG(*) FROM nds.POSCashMonthly WHERE SourceBatchID = @BatchID
    UNION ALL SELECT N'CreditCardMonthly', COUNT_BIG(*) FROM nds.CreditCardMonthly WHERE SourceBatchID = @BatchID;
END;
GO

/* Example (review BatchID first):
EXEC etl.usp_LoadNDS @BatchID = 1, @ConfirmReplace = 0;
*/
