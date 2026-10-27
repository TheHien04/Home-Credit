/*
Purpose: Full-load the TRAIN analytical star schema from one validated NDS batch.
Safety: Existing DDS data is replaced only when @ConfirmReplace = 1.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

CREATE OR ALTER PROCEDURE etl.usp_LoadDDS
    @BatchID BIGINT,
    @ConfirmReplace BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS
    (
        SELECT 1
        FROM nds.Applicant AS a
        JOIN nds.LoanApplication AS l ON l.ApplicationID = a.ApplicationID
        WHERE a.SourceBatchID = @BatchID
          AND l.SourceBatchID = @BatchID
          AND a.DatasetSplit = 'TRAIN'
          AND l.TargetFlag IS NOT NULL
    )
        THROW 51100, 'Validated TRAIN data for this batch is not available in NDS.', 1;

    IF
    (
        EXISTS (SELECT 1 FROM dds.FactLoanApplication)
        OR EXISTS (SELECT 1 FROM dds.FactPreviousApplication)
        OR EXISTS (SELECT 1 FROM dds.FactInstallmentPayment)
        OR EXISTS (SELECT 1 FROM dds.FactBureauCredit)
        OR EXISTS (SELECT 1 FROM dds.FactBureauMonthlySnapshot)
        OR EXISTS (SELECT 1 FROM dds.FactPOSCashMonthly)
        OR EXISTS (SELECT 1 FROM dds.FactCreditCardMonthly)
        OR EXISTS (SELECT 1 FROM dds.DimApplicant)
    ) AND @ConfirmReplace = 0
        THROW 51101, 'DDS is not empty. Re-run with @ConfirmReplace = 1 only after validating the batch.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @ConfirmReplace = 1
        BEGIN
            DELETE FROM dds.FactCreditCardMonthly;
            DELETE FROM dds.FactPOSCashMonthly;
            DELETE FROM dds.FactBureauMonthlySnapshot;
            DELETE FROM dds.FactBureauCredit;
            DELETE FROM dds.FactInstallmentPayment;
            DELETE FROM dds.FactPreviousApplication;
            DELETE FROM dds.FactLoanApplication;
            DELETE FROM dds.DimRelativeMonth;
            DELETE FROM dds.DimCreditStatus;
            DELETE FROM dds.DimApplicationStatus;
            DELETE FROM dds.DimContract;
            DELETE FROM dds.DimApplicant;
        END;

        INSERT dds.DimApplicant
        (
            ApplicationID, GenderCode, AgeYears, AgeBand, IncomeAmount, IncomeBand,
            IncomeType, EducationType, FamilyStatus, HousingType, OccupationType,
            OrganizationType, OwnCarFlag, OwnRealtyFlag, ChildrenCount,
            FamilyMemberCount, RegionRating, RegionCityRating, IsUnknown, SourceBatchID
        )
        VALUES
        (
            NULL, N'Unknown', NULL, N'Unknown', NULL, N'Unknown', N'Unknown', N'Unknown',
            N'Unknown', N'Unknown', N'Unknown', N'Unknown', NULL, NULL, NULL, NULL,
            NULL, NULL, 1, @BatchID
        );

        INSERT dds.DimApplicant
        (
            ApplicationID, GenderCode, AgeYears, AgeBand, IncomeAmount, IncomeBand,
            IncomeType, EducationType, FamilyStatus, HousingType, OccupationType,
            OrganizationType, OwnCarFlag, OwnRealtyFlag, ChildrenCount,
            FamilyMemberCount, RegionRating, RegionCityRating, IsUnknown, SourceBatchID
        )
        SELECT
            a.ApplicationID,
            a.GenderCode,
            a.AgeYears,
            CASE
                WHEN a.AgeYears IS NULL THEN N'Unknown'
                WHEN a.AgeYears < 25 THEN N'Under 25'
                WHEN a.AgeYears < 35 THEN N'25–34'
                WHEN a.AgeYears < 45 THEN N'35–44'
                WHEN a.AgeYears < 55 THEN N'45–54'
                WHEN a.AgeYears < 65 THEN N'55–64'
                ELSE N'65+'
            END,
            a.IncomeAmount,
            CASE
                WHEN a.IncomeAmount IS NULL THEN N'Unknown'
                WHEN a.IncomeAmount < 100000 THEN N'Under 100k'
                WHEN a.IncomeAmount < 150000 THEN N'100k–149k'
                WHEN a.IncomeAmount < 250000 THEN N'150k–249k'
                ELSE N'250k+'
            END,
            a.IncomeType,
            a.EducationType,
            a.FamilyStatus,
            a.HousingType,
            a.OccupationType,
            a.OrganizationType,
            a.OwnCarFlag,
            a.OwnRealtyFlag,
            a.ChildrenCount,
            a.FamilyMemberCount,
            a.RegionRating,
            a.RegionCityRating,
            0,
            @BatchID
        FROM nds.Applicant AS a
        WHERE a.SourceBatchID = @BatchID
          AND a.DatasetSplit = 'TRAIN';

        INSERT dds.DimContract (ContractType, IsUnknown, SourceBatchID)
        VALUES (N'Unknown', 1, @BatchID);

        INSERT dds.DimContract (ContractType, IsUnknown, SourceBatchID)
        SELECT ContractType, 0, @BatchID
        FROM
        (
            SELECT l.ContractType
            FROM nds.LoanApplication AS l
            JOIN nds.Applicant AS a ON a.ApplicationID = l.ApplicationID
            WHERE l.SourceBatchID = @BatchID AND a.DatasetSplit = 'TRAIN'
            UNION
            SELECT p.ContractType
            FROM nds.PreviousApplication AS p
            JOIN nds.Applicant AS a ON a.ApplicationID = p.ApplicationID
            WHERE p.SourceBatchID = @BatchID AND a.DatasetSplit = 'TRAIN'
        ) AS c
        WHERE c.ContractType <> N'Unknown';

        INSERT dds.DimApplicationStatus
            (ApplicationStatus, IsApproved, IsUnknown, SourceBatchID)
        VALUES (N'Unknown', 0, 1, @BatchID);

        INSERT dds.DimApplicationStatus
            (ApplicationStatus, IsApproved, IsUnknown, SourceBatchID)
        SELECT DISTINCT
            p.ContractStatus,
            CONVERT(BIT, CASE WHEN UPPER(p.ContractStatus) = N'APPROVED' THEN 1 ELSE 0 END),
            0,
            @BatchID
        FROM nds.PreviousApplication AS p
        JOIN nds.Applicant AS a ON a.ApplicationID = p.ApplicationID
        WHERE p.SourceBatchID = @BatchID
          AND a.DatasetSplit = 'TRAIN'
          AND p.ContractStatus <> N'Unknown';

        INSERT dds.DimCreditStatus
            (CreditStatus, IsActive, IsUnknown, SourceBatchID)
        VALUES (N'Unknown', 0, 1, @BatchID);

        INSERT dds.DimCreditStatus
            (CreditStatus, IsActive, IsUnknown, SourceBatchID)
        SELECT DISTINCT
            b.CreditStatus,
            CONVERT(BIT, CASE WHEN UPPER(b.CreditStatus) = N'ACTIVE' THEN 1 ELSE 0 END),
            0,
            @BatchID
        FROM nds.BureauCredit AS b
        JOIN nds.Applicant AS a ON a.ApplicationID = b.ApplicationID
        WHERE b.SourceBatchID = @BatchID
          AND a.DatasetSplit = 'TRAIN'
          AND b.CreditStatus <> N'Unknown';

        INSERT dds.DimRelativeMonth (RelativeMonth, MonthBand, IsUnknown, SourceBatchID)
        VALUES (NULL, N'Unknown', 1, @BatchID);

        INSERT dds.DimRelativeMonth (RelativeMonth, MonthBand, IsUnknown, SourceBatchID)
        SELECT
            m.RelativeMonth,
            CASE
                WHEN m.RelativeMonth >= -12 THEN N'Last 12 months'
                WHEN m.RelativeMonth >= -24 THEN N'13–24 months ago'
                WHEN m.RelativeMonth >= -60 THEN N'25–60 months ago'
                ELSE N'More than 60 months ago'
            END,
            0,
            @BatchID
        FROM
        (
            SELECT RelativeMonth FROM nds.BureauMonthlyStatus WHERE SourceBatchID = @BatchID
            UNION
            SELECT RelativeMonth FROM nds.POSCashMonthly WHERE SourceBatchID = @BatchID
            UNION
            SELECT RelativeMonth FROM nds.CreditCardMonthly WHERE SourceBatchID = @BatchID
        ) AS m;

        DECLARE @UnknownApplicantKey BIGINT =
            (SELECT ApplicantKey FROM dds.DimApplicant WHERE IsUnknown = 1);
        DECLARE @UnknownContractKey INT =
            (SELECT ContractKey FROM dds.DimContract WHERE IsUnknown = 1);
        DECLARE @UnknownApplicationStatusKey INT =
            (SELECT ApplicationStatusKey FROM dds.DimApplicationStatus WHERE IsUnknown = 1);
        DECLARE @UnknownCreditStatusKey INT =
            (SELECT CreditStatusKey FROM dds.DimCreditStatus WHERE IsUnknown = 1);

        INSERT dds.FactLoanApplication
        (
            ApplicationID, ApplicantKey, ContractKey, AffordabilityBandKey,
            DefaultFlag, CreditAmount, AnnuityAmount, GoodsPriceAmount, IncomeAmount,
            CreditToIncomeRatio, AnnuityToIncomeRatio, ExternalScoreAverage,
            MissingAnnuityFlag, MissingGoodsPriceFlag, SourceBatchID
        )
        SELECT
            l.ApplicationID,
            da.ApplicantKey,
            COALESCE(dc.ContractKey, @UnknownContractKey),
            CASE
                WHEN a.IncomeAmount IS NULL OR a.IncomeAmount <= 0 OR l.AnnuityAmount IS NULL THEN 0
                WHEN l.AnnuityAmount / NULLIF(a.IncomeAmount, 0) <= 0.20 THEN 1
                WHEN l.AnnuityAmount / NULLIF(a.IncomeAmount, 0) <= 0.35 THEN 2
                WHEN l.AnnuityAmount / NULLIF(a.IncomeAmount, 0) <= 0.50 THEN 3
                ELSE 4
            END,
            l.TargetFlag,
            l.CreditAmount,
            l.AnnuityAmount,
            l.GoodsPriceAmount,
            a.IncomeAmount,
            CONVERT(DECIMAL(19,6), l.CreditAmount / NULLIF(a.IncomeAmount, 0)),
            CONVERT(DECIMAL(19,6), l.AnnuityAmount / NULLIF(a.IncomeAmount, 0)),
            CONVERT(DECIMAL(18,10),
                (COALESCE(l.ExternalScore1, 0) + COALESCE(l.ExternalScore2, 0) + COALESCE(l.ExternalScore3, 0)) /
                NULLIF(CONVERT(DECIMAL(10,2),
                    CASE WHEN l.ExternalScore1 IS NULL THEN 0 ELSE 1 END +
                    CASE WHEN l.ExternalScore2 IS NULL THEN 0 ELSE 1 END +
                    CASE WHEN l.ExternalScore3 IS NULL THEN 0 ELSE 1 END), 0)),
            l.MissingAnnuityFlag,
            l.MissingGoodsPriceFlag,
            @BatchID
        FROM nds.LoanApplication AS l
        JOIN nds.Applicant AS a ON a.ApplicationID = l.ApplicationID
        JOIN dds.DimApplicant AS da ON da.ApplicationID = l.ApplicationID
        LEFT JOIN dds.DimContract AS dc ON dc.ContractType = l.ContractType
        WHERE l.SourceBatchID = @BatchID
          AND a.SourceBatchID = @BatchID
          AND a.DatasetSplit = 'TRAIN'
          AND l.TargetFlag IS NOT NULL;

        INSERT dds.FactPreviousApplication
        (
            PreviousApplicationID, ApplicantKey, ContractKey, ApplicationStatusKey,
            ApplicationAmount, CreditAmount, AnnuityAmount, DownPaymentAmount,
            GoodsPriceAmount, PaymentCount, DecisionDaysRelative,
            NonPositivePaymentCountFlag, NegativeAmountFlag, SourceBatchID
        )
        SELECT
            p.PreviousApplicationID,
            da.ApplicantKey,
            COALESCE(dc.ContractKey, @UnknownContractKey),
            COALESCE(ds.ApplicationStatusKey, @UnknownApplicationStatusKey),
            p.ApplicationAmount,
            p.CreditAmount,
            p.AnnuityAmount,
            p.DownPaymentAmount,
            p.GoodsPriceAmount,
            p.PaymentCount,
            p.DecisionDaysRelative,
            p.NonPositivePaymentCountFlag,
            p.NegativeAmountFlag,
            @BatchID
        FROM nds.PreviousApplication AS p
        JOIN dds.DimApplicant AS da ON da.ApplicationID = p.ApplicationID
        LEFT JOIN dds.DimContract AS dc ON dc.ContractType = p.ContractType
        LEFT JOIN dds.DimApplicationStatus AS ds ON ds.ApplicationStatus = p.ContractStatus
        WHERE p.SourceBatchID = @BatchID;

        INSERT dds.FactInstallmentPayment
        (
            ApplicantKey, PreviousApplicationID, InstallmentVersion,
            InstallmentNumber, DueDaysRelative, PaymentDaysRelative,
            ScheduledAmount, PaidAmount, PaymentVarianceAmount, PaymentDelayDays,
            DaysLate, LatePaymentFlag, PaymentRecordedFlag, ParentMissingFlag,
            SourceRowNumber, SourceBatchID
        )
        SELECT
            da.ApplicantKey,
            i.PreviousApplicationID,
            i.InstallmentVersion,
            i.InstallmentNumber,
            i.DueDaysRelative,
            i.PaymentDaysRelative,
            i.ScheduledAmount,
            i.PaidAmount,
            i.PaymentVarianceAmount,
            i.PaymentDelayDays,
            i.DaysLate,
            CONVERT(BIT, CASE WHEN i.PaymentRecordedFlag = 1 AND i.DaysLate > 0 THEN 1 ELSE 0 END),
            i.PaymentRecordedFlag,
            i.ParentMissingFlag,
            i.SourceRowNumber,
            @BatchID
        FROM nds.InstallmentPayment AS i
        JOIN dds.DimApplicant AS da ON da.ApplicationID = i.ApplicationID
        WHERE i.SourceBatchID = @BatchID;

        INSERT dds.FactBureauCredit
        (
            BureauCreditID, ApplicantKey, CreditStatusKey, CreditType,
            CreditCurrency, CreditAmount, DebtAmount, CreditLimitAmount,
            OverdueAmount, MaxOverdueAmount, AnnuityAmount, OverdueDays,
            ProlongationCount, NegativeDebtFlag, SourceBatchID
        )
        SELECT
            b.BureauCreditID,
            da.ApplicantKey,
            COALESCE(ds.CreditStatusKey, @UnknownCreditStatusKey),
            b.CreditType,
            b.CreditCurrency,
            b.CreditAmount,
            b.DebtAmount,
            b.CreditLimitAmount,
            b.OverdueAmount,
            b.MaxOverdueAmount,
            b.AnnuityAmount,
            b.OverdueDays,
            b.ProlongationCount,
            b.NegativeDebtFlag,
            @BatchID
        FROM nds.BureauCredit AS b
        JOIN dds.DimApplicant AS da ON da.ApplicationID = b.ApplicationID
        LEFT JOIN dds.DimCreditStatus AS ds ON ds.CreditStatus = b.CreditStatus
        WHERE b.SourceBatchID = @BatchID;

        INSERT dds.FactBureauMonthlySnapshot
        (
            ApplicantKey, RelativeMonthKey, BureauCreditID, StatusCode,
            ParentMissingFlag, SourceRowNumber, SourceBatchID
        )
        SELECT
            COALESCE(da.ApplicantKey, @UnknownApplicantKey),
            dm.RelativeMonthKey,
            m.BureauCreditID,
            m.StatusCode,
            m.ParentMissingFlag,
            m.SourceRowNumber,
            @BatchID
        FROM nds.BureauMonthlyStatus AS m
        LEFT JOIN nds.BureauCredit AS b
          ON b.BureauCreditID = m.BureauCreditID AND b.SourceBatchID = @BatchID
        LEFT JOIN dds.DimApplicant AS da ON da.ApplicationID = b.ApplicationID
        JOIN dds.DimRelativeMonth AS dm ON dm.RelativeMonth = m.RelativeMonth
        WHERE m.SourceBatchID = @BatchID
          AND (da.ApplicantKey IS NOT NULL OR b.BureauCreditID IS NULL);

        INSERT dds.FactPOSCashMonthly
        (
            ApplicantKey, RelativeMonthKey, PreviousApplicationID,
            InstallmentCount, FutureInstallmentCount, ContractStatus,
            DaysPastDue, DaysPastDueTolerance, ParentMissingFlag,
            SourceRowNumber, SourceBatchID
        )
        SELECT
            da.ApplicantKey,
            dm.RelativeMonthKey,
            m.PreviousApplicationID,
            m.InstallmentCount,
            m.FutureInstallmentCount,
            m.ContractStatus,
            m.DaysPastDue,
            m.DaysPastDueTolerance,
            m.ParentMissingFlag,
            m.SourceRowNumber,
            @BatchID
        FROM nds.POSCashMonthly AS m
        JOIN dds.DimApplicant AS da ON da.ApplicationID = m.ApplicationID
        JOIN dds.DimRelativeMonth AS dm ON dm.RelativeMonth = m.RelativeMonth
        WHERE m.SourceBatchID = @BatchID;

        INSERT dds.FactCreditCardMonthly
        (
            ApplicantKey, RelativeMonthKey, PreviousApplicationID,
            BalanceAmount, CreditLimitAmount, DrawingsAmount,
            MinimumInstallmentAmount, CurrentPaymentAmount, TotalPaymentAmount,
            PrincipalReceivableAmount, TotalReceivableAmount, ContractStatus,
            DaysPastDue, DaysPastDueTolerance, NegativeLimitFlag,
            ParentMissingFlag, SourceRowNumber, SourceBatchID
        )
        SELECT
            da.ApplicantKey,
            dm.RelativeMonthKey,
            m.PreviousApplicationID,
            m.BalanceAmount,
            m.CreditLimitAmount,
            m.DrawingsAmount,
            m.MinimumInstallmentAmount,
            m.CurrentPaymentAmount,
            m.TotalPaymentAmount,
            m.PrincipalReceivableAmount,
            m.TotalReceivableAmount,
            m.ContractStatus,
            m.DaysPastDue,
            m.DaysPastDueTolerance,
            m.NegativeLimitFlag,
            m.ParentMissingFlag,
            m.SourceRowNumber,
            @BatchID
        FROM nds.CreditCardMonthly AS m
        JOIN dds.DimApplicant AS da ON da.ApplicationID = m.ApplicationID
        JOIN dds.DimRelativeMonth AS dm ON dm.RelativeMonth = m.RelativeMonth
        WHERE m.SourceBatchID = @BatchID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    SELECT N'FactLoanApplication' AS ObjectName, COUNT_BIG(*) AS [RowCount] FROM dds.FactLoanApplication WHERE SourceBatchID = @BatchID
    UNION ALL SELECT N'FactPreviousApplication', COUNT_BIG(*) FROM dds.FactPreviousApplication WHERE SourceBatchID = @BatchID
    UNION ALL SELECT N'FactInstallmentPayment', COUNT_BIG(*) FROM dds.FactInstallmentPayment WHERE SourceBatchID = @BatchID
    UNION ALL SELECT N'FactBureauCredit', COUNT_BIG(*) FROM dds.FactBureauCredit WHERE SourceBatchID = @BatchID
    UNION ALL SELECT N'FactBureauMonthlySnapshot', COUNT_BIG(*) FROM dds.FactBureauMonthlySnapshot WHERE SourceBatchID = @BatchID
    UNION ALL SELECT N'FactPOSCashMonthly', COUNT_BIG(*) FROM dds.FactPOSCashMonthly WHERE SourceBatchID = @BatchID
    UNION ALL SELECT N'FactCreditCardMonthly', COUNT_BIG(*) FROM dds.FactCreditCardMonthly WHERE SourceBatchID = @BatchID;
END;
GO

/* Example:
EXEC etl.usp_LoadDDS @BatchID = 1, @ConfirmReplace = 0;
*/
