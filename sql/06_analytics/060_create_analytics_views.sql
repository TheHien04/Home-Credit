/*
Purpose: Stable semantic views for SQL validation and Power BI import.
All default-related views are already limited to labeled TRAIN applications by DDS load.
*/

SET NOCOUNT ON;
GO

CREATE OR ALTER VIEW dds.vw_ApplicationAnalytics
AS
SELECT
    f.LoanApplicationKey,
    f.ApplicationID,
    f.DefaultFlag,
    f.CreditAmount,
    f.AnnuityAmount,
    f.GoodsPriceAmount,
    f.IncomeAmount,
    f.CreditToIncomeRatio,
    f.AnnuityToIncomeRatio,
    f.ExternalScoreAverage,
    f.MissingAnnuityFlag,
    f.MissingGoodsPriceFlag,
    a.ApplicantKey,
    a.GenderCode,
    a.AgeYears,
    a.AgeBand,
    a.IncomeBand,
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
    c.ContractType,
    af.AffordabilityBand,
    af.SortOrder AS AffordabilitySortOrder,
    f.SourceBatchID
FROM dds.FactLoanApplication AS f
JOIN dds.DimApplicant AS a ON a.ApplicantKey = f.ApplicantKey
JOIN dds.DimContract AS c ON c.ContractKey = f.ContractKey
JOIN dds.DimAffordabilityBand AS af ON af.AffordabilityBandKey = f.AffordabilityBandKey;
GO

CREATE OR ALTER VIEW dds.vw_PreviousApplicationAnalytics
AS
SELECT
    f.PreviousApplicationFactKey,
    f.PreviousApplicationID,
    f.ApplicantKey,
    a.ApplicationID,
    c.ContractType,
    s.ApplicationStatus,
    s.IsApproved,
    f.ApplicationAmount,
    f.CreditAmount,
    f.AnnuityAmount,
    f.DownPaymentAmount,
    f.GoodsPriceAmount,
    f.PaymentCount,
    f.DecisionDaysRelative,
    f.NonPositivePaymentCountFlag,
    f.NegativeAmountFlag,
    f.SourceBatchID
FROM dds.FactPreviousApplication AS f
JOIN dds.DimApplicant AS a ON a.ApplicantKey = f.ApplicantKey
JOIN dds.DimContract AS c ON c.ContractKey = f.ContractKey
JOIN dds.DimApplicationStatus AS s ON s.ApplicationStatusKey = f.ApplicationStatusKey;
GO

CREATE OR ALTER VIEW dds.vw_InstallmentPaymentAnalytics
AS
SELECT
    f.InstallmentPaymentFactKey,
    f.ApplicantKey,
    a.ApplicationID,
    f.PreviousApplicationID,
    f.InstallmentVersion,
    f.InstallmentNumber,
    f.DueDaysRelative,
    f.PaymentDaysRelative,
    f.ScheduledAmount,
    f.PaidAmount,
    f.PaymentVarianceAmount,
    f.PaymentDelayDays,
    f.DaysLate,
    f.LatePaymentFlag,
    f.PaymentRecordedFlag,
    f.ParentMissingFlag,
    f.SourceBatchID
FROM dds.FactInstallmentPayment AS f
JOIN dds.DimApplicant AS a ON a.ApplicantKey = f.ApplicantKey;
GO

CREATE OR ALTER VIEW dds.vw_BureauCreditAnalytics
AS
SELECT
    f.BureauCreditFactKey,
    f.BureauCreditID,
    f.ApplicantKey,
    a.ApplicationID,
    s.CreditStatus,
    s.IsActive,
    f.CreditType,
    f.CreditCurrency,
    f.CreditAmount,
    f.DebtAmount,
    f.CreditLimitAmount,
    f.OverdueAmount,
    f.MaxOverdueAmount,
    f.AnnuityAmount,
    f.OverdueDays,
    f.ProlongationCount,
    f.NegativeDebtFlag,
    f.SourceBatchID
FROM dds.FactBureauCredit AS f
JOIN dds.DimApplicant AS a ON a.ApplicantKey = f.ApplicantKey
JOIN dds.DimCreditStatus AS s ON s.CreditStatusKey = f.CreditStatusKey;
GO

CREATE OR ALTER VIEW dds.vw_ExecutiveKPI
AS
SELECT
    f.SourceBatchID,
    COUNT_BIG(*) AS TotalApplications,
    SUM(CONVERT(BIGINT, f.DefaultFlag)) AS DefaultApplications,
    CONVERT(DECIMAL(19,6), AVG(CONVERT(DECIMAL(19,6), f.DefaultFlag))) AS DefaultRate,
    CONVERT(DECIMAL(19,2), AVG(f.CreditAmount)) AS AverageCreditAmount,
    CONVERT(DECIMAL(19,2), AVG(f.AnnuityAmount)) AS AverageAnnuityAmount,
    CONVERT(DECIMAL(19,2), AVG(f.IncomeAmount)) AS AverageIncomeAmount,
    CONVERT(DECIMAL(19,6), AVG(f.CreditToIncomeRatio)) AS AverageCreditToIncome,
    CONVERT(DECIMAL(19,6), AVG(f.AnnuityToIncomeRatio)) AS AverageAnnuityToIncome
FROM dds.FactLoanApplication AS f
GROUP BY f.SourceBatchID;
GO

CREATE OR ALTER VIEW dds.vw_PreviousApplicationKPI
AS
SELECT
    f.SourceBatchID,
    COUNT_BIG(*) AS TotalPreviousApplications,
    SUM(CONVERT(BIGINT, s.IsApproved)) AS ApprovedPreviousApplications,
    CONVERT(DECIMAL(19,6), AVG(CONVERT(DECIMAL(19,6), s.IsApproved))) AS PreviousApprovalRate,
    CONVERT(DECIMAL(19,2), AVG(f.ApplicationAmount)) AS AveragePreviousApplicationAmount,
    CONVERT(DECIMAL(19,2), AVG(f.CreditAmount)) AS AveragePreviousCreditAmount
FROM dds.FactPreviousApplication AS f
JOIN dds.DimApplicationStatus AS s ON s.ApplicationStatusKey = f.ApplicationStatusKey
GROUP BY f.SourceBatchID;
GO

CREATE OR ALTER VIEW dds.vw_PaymentKPI
AS
SELECT
    f.SourceBatchID,
    COUNT_BIG(*) AS TotalPaymentRows,
    SUM(CASE WHEN f.PaymentRecordedFlag = 1 THEN CONVERT(BIGINT, 1) ELSE 0 END) AS RecordedPaymentRows,
    SUM(CONVERT(BIGINT, f.LatePaymentFlag)) AS LatePaymentRows,
    CONVERT(DECIMAL(19,6),
        SUM(CONVERT(DECIMAL(19,6), f.LatePaymentFlag)) /
        NULLIF(SUM(CASE WHEN f.PaymentRecordedFlag = 1 THEN CONVERT(DECIMAL(19,6), 1) ELSE 0 END), 0)) AS LatePaymentRate,
    CONVERT(DECIMAL(19,2), AVG(CASE WHEN f.LatePaymentFlag = 1 THEN CONVERT(DECIMAL(19,2), f.DaysLate) END)) AS AverageDaysLate,
    SUM(f.ScheduledAmount) AS TotalScheduledAmount,
    SUM(f.PaidAmount) AS TotalPaidAmount
FROM dds.FactInstallmentPayment AS f
GROUP BY f.SourceBatchID;
GO

CREATE OR ALTER VIEW dds.vw_BureauKPI
AS
SELECT
    f.SourceBatchID,
    COUNT_BIG(*) AS TotalBureauCredits,
    SUM(CASE WHEN s.IsActive = 1 THEN CONVERT(BIGINT, 1) ELSE 0 END) AS ActiveBureauCredits,
    SUM(CASE WHEN s.IsActive = 1 THEN f.DebtAmount ELSE 0 END) AS ActiveBureauDebt,
    SUM(f.OverdueAmount) AS TotalBureauOverdueAmount,
    SUM(CASE WHEN f.OverdueDays > 0 OR f.OverdueAmount > 0 THEN CONVERT(BIGINT, 1) ELSE 0 END) AS BureauCreditsWithOverdue
FROM dds.FactBureauCredit AS f
JOIN dds.DimCreditStatus AS s ON s.CreditStatusKey = f.CreditStatusKey
GROUP BY f.SourceBatchID;
GO
