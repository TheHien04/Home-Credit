/*
Purpose: Create the dimensional data store for Home Credit BI.
Analytical scope: TRAIN applications for risk KPIs; unmatched monthly history is
preserved with the unknown applicant member and ParentMissingFlag = 1.
Safety: Creates objects only; never drops or truncates data.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'dds.DimApplicant', N'U') IS NULL
BEGIN
    CREATE TABLE dds.DimApplicant
    (
        ApplicantKey BIGINT IDENTITY(1,1) NOT NULL,
        ApplicationID BIGINT NULL,
        GenderCode NVARCHAR(20) NOT NULL,
        AgeYears SMALLINT NULL,
        AgeBand NVARCHAR(30) NOT NULL,
        IncomeAmount DECIMAL(19,2) NULL,
        IncomeBand NVARCHAR(30) NOT NULL,
        IncomeType NVARCHAR(100) NOT NULL,
        EducationType NVARCHAR(100) NOT NULL,
        FamilyStatus NVARCHAR(100) NOT NULL,
        HousingType NVARCHAR(100) NOT NULL,
        OccupationType NVARCHAR(100) NOT NULL,
        OrganizationType NVARCHAR(100) NOT NULL,
        OwnCarFlag BIT NULL,
        OwnRealtyFlag BIT NULL,
        ChildrenCount INT NULL,
        FamilyMemberCount DECIMAL(9,2) NULL,
        RegionRating INT NULL,
        RegionCityRating INT NULL,
        IsUnknown BIT NOT NULL,
        SourceBatchID BIGINT NOT NULL,
        LoadedAtUtc DATETIME2(3) NOT NULL
            CONSTRAINT DF_dds_DimApplicant_LoadedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_dds_DimApplicant PRIMARY KEY CLUSTERED (ApplicantKey),
        CONSTRAINT UQ_dds_DimApplicant_ApplicationID UNIQUE (ApplicationID),
        CONSTRAINT FK_dds_DimApplicant_Batch FOREIGN KEY (SourceBatchID)
            REFERENCES ctl.ETLBatch (BatchID)
    );
END;
GO

IF OBJECT_ID(N'dds.DimContract', N'U') IS NULL
BEGIN
    CREATE TABLE dds.DimContract
    (
        ContractKey INT IDENTITY(1,1) NOT NULL,
        ContractType NVARCHAR(100) NOT NULL,
        IsUnknown BIT NOT NULL,
        SourceBatchID BIGINT NOT NULL,
        LoadedAtUtc DATETIME2(3) NOT NULL
            CONSTRAINT DF_dds_DimContract_LoadedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_dds_DimContract PRIMARY KEY CLUSTERED (ContractKey),
        CONSTRAINT UQ_dds_DimContract_Type UNIQUE (ContractType),
        CONSTRAINT FK_dds_DimContract_Batch FOREIGN KEY (SourceBatchID)
            REFERENCES ctl.ETLBatch (BatchID)
    );
END;
GO

IF OBJECT_ID(N'dds.DimApplicationStatus', N'U') IS NULL
BEGIN
    CREATE TABLE dds.DimApplicationStatus
    (
        ApplicationStatusKey INT IDENTITY(1,1) NOT NULL,
        ApplicationStatus NVARCHAR(100) NOT NULL,
        IsApproved BIT NOT NULL,
        IsUnknown BIT NOT NULL,
        SourceBatchID BIGINT NOT NULL,
        LoadedAtUtc DATETIME2(3) NOT NULL
            CONSTRAINT DF_dds_DimApplicationStatus_LoadedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_dds_DimApplicationStatus PRIMARY KEY CLUSTERED (ApplicationStatusKey),
        CONSTRAINT UQ_dds_DimApplicationStatus_Name UNIQUE (ApplicationStatus),
        CONSTRAINT FK_dds_DimApplicationStatus_Batch FOREIGN KEY (SourceBatchID)
            REFERENCES ctl.ETLBatch (BatchID)
    );
END;
GO

IF OBJECT_ID(N'dds.DimCreditStatus', N'U') IS NULL
BEGIN
    CREATE TABLE dds.DimCreditStatus
    (
        CreditStatusKey INT IDENTITY(1,1) NOT NULL,
        CreditStatus NVARCHAR(50) NOT NULL,
        IsActive BIT NOT NULL,
        IsUnknown BIT NOT NULL,
        SourceBatchID BIGINT NOT NULL,
        LoadedAtUtc DATETIME2(3) NOT NULL
            CONSTRAINT DF_dds_DimCreditStatus_LoadedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_dds_DimCreditStatus PRIMARY KEY CLUSTERED (CreditStatusKey),
        CONSTRAINT UQ_dds_DimCreditStatus_Name UNIQUE (CreditStatus),
        CONSTRAINT FK_dds_DimCreditStatus_Batch FOREIGN KEY (SourceBatchID)
            REFERENCES ctl.ETLBatch (BatchID)
    );
END;
GO

IF OBJECT_ID(N'dds.DimRelativeMonth', N'U') IS NULL
BEGIN
    CREATE TABLE dds.DimRelativeMonth
    (
        RelativeMonthKey INT IDENTITY(1,1) NOT NULL,
        RelativeMonth INT NULL,
        MonthBand NVARCHAR(30) NOT NULL,
        IsUnknown BIT NOT NULL,
        SourceBatchID BIGINT NOT NULL,
        LoadedAtUtc DATETIME2(3) NOT NULL
            CONSTRAINT DF_dds_DimRelativeMonth_LoadedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_dds_DimRelativeMonth PRIMARY KEY CLUSTERED (RelativeMonthKey),
        CONSTRAINT UQ_dds_DimRelativeMonth_Value UNIQUE (RelativeMonth),
        CONSTRAINT FK_dds_DimRelativeMonth_Batch FOREIGN KEY (SourceBatchID)
            REFERENCES ctl.ETLBatch (BatchID)
    );
END;
GO

IF OBJECT_ID(N'dds.DimAffordabilityBand', N'U') IS NULL
BEGIN
    CREATE TABLE dds.DimAffordabilityBand
    (
        AffordabilityBandKey INT NOT NULL,
        AffordabilityBand NVARCHAR(40) NOT NULL,
        MinimumRatio DECIMAL(9,4) NULL,
        MaximumRatio DECIMAL(9,4) NULL,
        SortOrder TINYINT NOT NULL,
        IsUnknown BIT NOT NULL,
        CONSTRAINT PK_dds_DimAffordabilityBand PRIMARY KEY CLUSTERED (AffordabilityBandKey),
        CONSTRAINT UQ_dds_DimAffordabilityBand_Name UNIQUE (AffordabilityBand)
    );

    INSERT dds.DimAffordabilityBand
        (AffordabilityBandKey, AffordabilityBand, MinimumRatio, MaximumRatio, SortOrder, IsUnknown)
    VALUES
        (0, N'Unknown',       NULL, NULL, 0, 1),
        (1, N'Low (≤20%)',    0.00, 0.20, 1, 0),
        (2, N'Moderate (20–35%)', 0.20, 0.35, 2, 0),
        (3, N'High (35–50%)', 0.35, 0.50, 3, 0),
        (4, N'Very high (>50%)', 0.50, NULL, 4, 0);
END;
GO

MERGE dds.DimAffordabilityBand AS target
USING
(
    VALUES
        (0, N'Unknown',              CONVERT(DECIMAL(9,4), NULL), CONVERT(DECIMAL(9,4), NULL), 0, 1),
        (1, N'Low (≤20%)',           CONVERT(DECIMAL(9,4), 0.00), CONVERT(DECIMAL(9,4), 0.20), 1, 0),
        (2, N'Moderate (20–35%)',    CONVERT(DECIMAL(9,4), 0.20), CONVERT(DECIMAL(9,4), 0.35), 2, 0),
        (3, N'High (35–50%)',        CONVERT(DECIMAL(9,4), 0.35), CONVERT(DECIMAL(9,4), 0.50), 3, 0),
        (4, N'Very high (>50%)',     CONVERT(DECIMAL(9,4), 0.50), CONVERT(DECIMAL(9,4), NULL), 4, 0)
) AS source (AffordabilityBandKey, AffordabilityBand, MinimumRatio, MaximumRatio, SortOrder, IsUnknown)
ON target.AffordabilityBandKey = source.AffordabilityBandKey
WHEN MATCHED THEN UPDATE SET
    AffordabilityBand = source.AffordabilityBand,
    MinimumRatio = source.MinimumRatio,
    MaximumRatio = source.MaximumRatio,
    SortOrder = source.SortOrder,
    IsUnknown = source.IsUnknown
WHEN NOT MATCHED THEN INSERT
    (AffordabilityBandKey, AffordabilityBand, MinimumRatio, MaximumRatio, SortOrder, IsUnknown)
    VALUES
    (source.AffordabilityBandKey, source.AffordabilityBand, source.MinimumRatio, source.MaximumRatio, source.SortOrder, source.IsUnknown);
GO

IF OBJECT_ID(N'dds.FactLoanApplication', N'U') IS NULL
BEGIN
    CREATE TABLE dds.FactLoanApplication
    (
        LoanApplicationKey BIGINT IDENTITY(1,1) NOT NULL,
        ApplicationID BIGINT NOT NULL,
        ApplicantKey BIGINT NOT NULL,
        ContractKey INT NOT NULL,
        AffordabilityBandKey INT NOT NULL,
        DefaultFlag BIT NOT NULL,
        CreditAmount DECIMAL(19,2) NULL,
        AnnuityAmount DECIMAL(19,2) NULL,
        GoodsPriceAmount DECIMAL(19,2) NULL,
        IncomeAmount DECIMAL(19,2) NULL,
        CreditToIncomeRatio DECIMAL(19,6) NULL,
        AnnuityToIncomeRatio DECIMAL(19,6) NULL,
        ExternalScoreAverage DECIMAL(18,10) NULL,
        MissingAnnuityFlag BIT NOT NULL,
        MissingGoodsPriceFlag BIT NOT NULL,
        SourceBatchID BIGINT NOT NULL,
        LoadedAtUtc DATETIME2(3) NOT NULL
            CONSTRAINT DF_dds_FactLoanApplication_LoadedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_dds_FactLoanApplication PRIMARY KEY CLUSTERED (LoanApplicationKey),
        CONSTRAINT UQ_dds_FactLoanApplication_ApplicationID UNIQUE (ApplicationID),
        CONSTRAINT FK_dds_FactLoanApplication_Applicant FOREIGN KEY (ApplicantKey) REFERENCES dds.DimApplicant (ApplicantKey),
        CONSTRAINT FK_dds_FactLoanApplication_Contract FOREIGN KEY (ContractKey) REFERENCES dds.DimContract (ContractKey),
        CONSTRAINT FK_dds_FactLoanApplication_Affordability FOREIGN KEY (AffordabilityBandKey) REFERENCES dds.DimAffordabilityBand (AffordabilityBandKey),
        CONSTRAINT FK_dds_FactLoanApplication_Batch FOREIGN KEY (SourceBatchID) REFERENCES ctl.ETLBatch (BatchID)
    );

    CREATE INDEX IX_dds_FactLoanApplication_Applicant ON dds.FactLoanApplication (ApplicantKey);
    CREATE INDEX IX_dds_FactLoanApplication_Default ON dds.FactLoanApplication (DefaultFlag);
END;
GO

IF OBJECT_ID(N'dds.FactPreviousApplication', N'U') IS NULL
BEGIN
    CREATE TABLE dds.FactPreviousApplication
    (
        PreviousApplicationFactKey BIGINT IDENTITY(1,1) NOT NULL,
        PreviousApplicationID BIGINT NOT NULL,
        ApplicantKey BIGINT NOT NULL,
        ContractKey INT NOT NULL,
        ApplicationStatusKey INT NOT NULL,
        ApplicationAmount DECIMAL(19,2) NULL,
        CreditAmount DECIMAL(19,2) NULL,
        AnnuityAmount DECIMAL(19,2) NULL,
        DownPaymentAmount DECIMAL(19,2) NULL,
        GoodsPriceAmount DECIMAL(19,2) NULL,
        PaymentCount DECIMAL(12,2) NULL,
        DecisionDaysRelative INT NULL,
        NonPositivePaymentCountFlag BIT NOT NULL,
        NegativeAmountFlag BIT NOT NULL,
        SourceBatchID BIGINT NOT NULL,
        LoadedAtUtc DATETIME2(3) NOT NULL
            CONSTRAINT DF_dds_FactPreviousApplication_LoadedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_dds_FactPreviousApplication PRIMARY KEY CLUSTERED (PreviousApplicationFactKey),
        CONSTRAINT UQ_dds_FactPreviousApplication_ID UNIQUE (PreviousApplicationID),
        CONSTRAINT FK_dds_FactPreviousApplication_Applicant FOREIGN KEY (ApplicantKey) REFERENCES dds.DimApplicant (ApplicantKey),
        CONSTRAINT FK_dds_FactPreviousApplication_Contract FOREIGN KEY (ContractKey) REFERENCES dds.DimContract (ContractKey),
        CONSTRAINT FK_dds_FactPreviousApplication_Status FOREIGN KEY (ApplicationStatusKey) REFERENCES dds.DimApplicationStatus (ApplicationStatusKey),
        CONSTRAINT FK_dds_FactPreviousApplication_Batch FOREIGN KEY (SourceBatchID) REFERENCES ctl.ETLBatch (BatchID)
    );

    CREATE INDEX IX_dds_FactPreviousApplication_Applicant ON dds.FactPreviousApplication (ApplicantKey);
    CREATE INDEX IX_dds_FactPreviousApplication_Status ON dds.FactPreviousApplication (ApplicationStatusKey);
END;
GO

IF OBJECT_ID(N'dds.FactInstallmentPayment', N'U') IS NULL
BEGIN
    CREATE TABLE dds.FactInstallmentPayment
    (
        InstallmentPaymentFactKey BIGINT IDENTITY(1,1) NOT NULL,
        ApplicantKey BIGINT NOT NULL,
        PreviousApplicationID BIGINT NOT NULL,
        InstallmentVersion DECIMAL(12,2) NULL,
        InstallmentNumber INT NULL,
        DueDaysRelative INT NULL,
        PaymentDaysRelative INT NULL,
        ScheduledAmount DECIMAL(19,2) NULL,
        PaidAmount DECIMAL(19,2) NULL,
        PaymentVarianceAmount DECIMAL(19,2) NULL,
        PaymentDelayDays INT NULL,
        DaysLate INT NULL,
        LatePaymentFlag BIT NOT NULL,
        PaymentRecordedFlag BIT NOT NULL,
        ParentMissingFlag BIT NOT NULL,
        SourceRowNumber BIGINT NOT NULL,
        SourceBatchID BIGINT NOT NULL,
        LoadedAtUtc DATETIME2(3) NOT NULL
            CONSTRAINT DF_dds_FactInstallmentPayment_LoadedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_dds_FactInstallmentPayment PRIMARY KEY CLUSTERED (InstallmentPaymentFactKey),
        CONSTRAINT UQ_dds_FactInstallmentPayment_Source UNIQUE (SourceBatchID, SourceRowNumber),
        CONSTRAINT FK_dds_FactInstallmentPayment_Applicant FOREIGN KEY (ApplicantKey) REFERENCES dds.DimApplicant (ApplicantKey),
        CONSTRAINT FK_dds_FactInstallmentPayment_Batch FOREIGN KEY (SourceBatchID) REFERENCES ctl.ETLBatch (BatchID)
    );

    CREATE INDEX IX_dds_FactInstallmentPayment_Applicant ON dds.FactInstallmentPayment (ApplicantKey);
    CREATE INDEX IX_dds_FactInstallmentPayment_Late ON dds.FactInstallmentPayment (LatePaymentFlag, PaymentRecordedFlag);
END;
GO

IF OBJECT_ID(N'dds.FactBureauCredit', N'U') IS NULL
BEGIN
    CREATE TABLE dds.FactBureauCredit
    (
        BureauCreditFactKey BIGINT IDENTITY(1,1) NOT NULL,
        BureauCreditID BIGINT NOT NULL,
        ApplicantKey BIGINT NOT NULL,
        CreditStatusKey INT NOT NULL,
        CreditType NVARCHAR(100) NOT NULL,
        CreditCurrency NVARCHAR(50) NOT NULL,
        CreditAmount DECIMAL(19,2) NULL,
        DebtAmount DECIMAL(19,2) NULL,
        CreditLimitAmount DECIMAL(19,2) NULL,
        OverdueAmount DECIMAL(19,2) NULL,
        MaxOverdueAmount DECIMAL(19,2) NULL,
        AnnuityAmount DECIMAL(19,2) NULL,
        OverdueDays INT NULL,
        ProlongationCount INT NULL,
        NegativeDebtFlag BIT NOT NULL,
        SourceBatchID BIGINT NOT NULL,
        LoadedAtUtc DATETIME2(3) NOT NULL
            CONSTRAINT DF_dds_FactBureauCredit_LoadedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_dds_FactBureauCredit PRIMARY KEY CLUSTERED (BureauCreditFactKey),
        CONSTRAINT UQ_dds_FactBureauCredit_ID UNIQUE (BureauCreditID),
        CONSTRAINT FK_dds_FactBureauCredit_Applicant FOREIGN KEY (ApplicantKey) REFERENCES dds.DimApplicant (ApplicantKey),
        CONSTRAINT FK_dds_FactBureauCredit_Status FOREIGN KEY (CreditStatusKey) REFERENCES dds.DimCreditStatus (CreditStatusKey),
        CONSTRAINT FK_dds_FactBureauCredit_Batch FOREIGN KEY (SourceBatchID) REFERENCES ctl.ETLBatch (BatchID)
    );

    CREATE INDEX IX_dds_FactBureauCredit_Applicant ON dds.FactBureauCredit (ApplicantKey);
    CREATE INDEX IX_dds_FactBureauCredit_Status ON dds.FactBureauCredit (CreditStatusKey);
END;
GO

IF OBJECT_ID(N'dds.FactBureauMonthlySnapshot', N'U') IS NULL
BEGIN
    CREATE TABLE dds.FactBureauMonthlySnapshot
    (
        BureauMonthlyFactKey BIGINT IDENTITY(1,1) NOT NULL,
        ApplicantKey BIGINT NOT NULL,
        RelativeMonthKey INT NOT NULL,
        BureauCreditID BIGINT NOT NULL,
        StatusCode VARCHAR(20) NOT NULL,
        ParentMissingFlag BIT NOT NULL,
        SourceRowNumber BIGINT NOT NULL,
        SourceBatchID BIGINT NOT NULL,
        LoadedAtUtc DATETIME2(3) NOT NULL
            CONSTRAINT DF_dds_FactBureauMonthlySnapshot_LoadedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_dds_FactBureauMonthlySnapshot PRIMARY KEY CLUSTERED (BureauMonthlyFactKey),
        CONSTRAINT UQ_dds_FactBureauMonthlySnapshot_Source UNIQUE (SourceBatchID, SourceRowNumber),
        CONSTRAINT FK_dds_FactBureauMonthlySnapshot_Applicant FOREIGN KEY (ApplicantKey) REFERENCES dds.DimApplicant (ApplicantKey),
        CONSTRAINT FK_dds_FactBureauMonthlySnapshot_Month FOREIGN KEY (RelativeMonthKey) REFERENCES dds.DimRelativeMonth (RelativeMonthKey),
        CONSTRAINT FK_dds_FactBureauMonthlySnapshot_Batch FOREIGN KEY (SourceBatchID) REFERENCES ctl.ETLBatch (BatchID)
    );

    CREATE INDEX IX_dds_FactBureauMonthlySnapshot_BureauMonth ON dds.FactBureauMonthlySnapshot (BureauCreditID, RelativeMonthKey);
END;
GO

IF OBJECT_ID(N'dds.FactPOSCashMonthly', N'U') IS NULL
BEGIN
    CREATE TABLE dds.FactPOSCashMonthly
    (
        POSCashMonthlyFactKey BIGINT IDENTITY(1,1) NOT NULL,
        ApplicantKey BIGINT NOT NULL,
        RelativeMonthKey INT NOT NULL,
        PreviousApplicationID BIGINT NOT NULL,
        InstallmentCount DECIMAL(12,2) NULL,
        FutureInstallmentCount DECIMAL(12,2) NULL,
        ContractStatus NVARCHAR(100) NOT NULL,
        DaysPastDue INT NULL,
        DaysPastDueTolerance INT NULL,
        ParentMissingFlag BIT NOT NULL,
        SourceRowNumber BIGINT NOT NULL,
        SourceBatchID BIGINT NOT NULL,
        LoadedAtUtc DATETIME2(3) NOT NULL
            CONSTRAINT DF_dds_FactPOSCashMonthly_LoadedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_dds_FactPOSCashMonthly PRIMARY KEY CLUSTERED (POSCashMonthlyFactKey),
        CONSTRAINT UQ_dds_FactPOSCashMonthly_Source UNIQUE (SourceBatchID, SourceRowNumber),
        CONSTRAINT FK_dds_FactPOSCashMonthly_Applicant FOREIGN KEY (ApplicantKey) REFERENCES dds.DimApplicant (ApplicantKey),
        CONSTRAINT FK_dds_FactPOSCashMonthly_Month FOREIGN KEY (RelativeMonthKey) REFERENCES dds.DimRelativeMonth (RelativeMonthKey),
        CONSTRAINT FK_dds_FactPOSCashMonthly_Batch FOREIGN KEY (SourceBatchID) REFERENCES ctl.ETLBatch (BatchID)
    );

    CREATE INDEX IX_dds_FactPOSCashMonthly_ApplicantMonth ON dds.FactPOSCashMonthly (ApplicantKey, RelativeMonthKey);
END;
GO

IF OBJECT_ID(N'dds.FactCreditCardMonthly', N'U') IS NULL
BEGIN
    CREATE TABLE dds.FactCreditCardMonthly
    (
        CreditCardMonthlyFactKey BIGINT IDENTITY(1,1) NOT NULL,
        ApplicantKey BIGINT NOT NULL,
        RelativeMonthKey INT NOT NULL,
        PreviousApplicationID BIGINT NOT NULL,
        BalanceAmount DECIMAL(19,2) NULL,
        CreditLimitAmount DECIMAL(19,2) NULL,
        DrawingsAmount DECIMAL(19,2) NULL,
        MinimumInstallmentAmount DECIMAL(19,2) NULL,
        CurrentPaymentAmount DECIMAL(19,2) NULL,
        TotalPaymentAmount DECIMAL(19,2) NULL,
        PrincipalReceivableAmount DECIMAL(19,2) NULL,
        TotalReceivableAmount DECIMAL(19,2) NULL,
        ContractStatus NVARCHAR(100) NOT NULL,
        DaysPastDue INT NULL,
        DaysPastDueTolerance INT NULL,
        NegativeLimitFlag BIT NOT NULL,
        ParentMissingFlag BIT NOT NULL,
        SourceRowNumber BIGINT NOT NULL,
        SourceBatchID BIGINT NOT NULL,
        LoadedAtUtc DATETIME2(3) NOT NULL
            CONSTRAINT DF_dds_FactCreditCardMonthly_LoadedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_dds_FactCreditCardMonthly PRIMARY KEY CLUSTERED (CreditCardMonthlyFactKey),
        CONSTRAINT UQ_dds_FactCreditCardMonthly_Source UNIQUE (SourceBatchID, SourceRowNumber),
        CONSTRAINT FK_dds_FactCreditCardMonthly_Applicant FOREIGN KEY (ApplicantKey) REFERENCES dds.DimApplicant (ApplicantKey),
        CONSTRAINT FK_dds_FactCreditCardMonthly_Month FOREIGN KEY (RelativeMonthKey) REFERENCES dds.DimRelativeMonth (RelativeMonthKey),
        CONSTRAINT FK_dds_FactCreditCardMonthly_Batch FOREIGN KEY (SourceBatchID) REFERENCES ctl.ETLBatch (BatchID)
    );

    CREATE INDEX IX_dds_FactCreditCardMonthly_ApplicantMonth ON dds.FactCreditCardMonthly (ApplicantKey, RelativeMonthKey);
END;
GO
