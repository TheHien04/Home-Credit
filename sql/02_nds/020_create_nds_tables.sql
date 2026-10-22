/*
Purpose: Create the curated normalized data store for Home Credit.
Dependency: ctl.ETLBatch and schemas from 00_admin/001_create_control_layer.sql.
Safety: Creates objects only; never drops or truncates data.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'nds.Applicant', N'U') IS NULL
BEGIN
    CREATE TABLE nds.Applicant
    (
        ApplicationID BIGINT NOT NULL,
        DatasetSplit VARCHAR(5) NOT NULL,
        GenderCode VARCHAR(20) NOT NULL,
        OwnCarFlag BIT NULL,
        OwnRealtyFlag BIT NULL,
        ChildrenCount INT NULL,
        IncomeAmount DECIMAL(19,2) NULL,
        IncomeType NVARCHAR(100) NOT NULL,
        EducationType NVARCHAR(100) NOT NULL,
        FamilyStatus NVARCHAR(100) NOT NULL,
        HousingType NVARCHAR(100) NOT NULL,
        AgeYears SMALLINT NULL,
        EmploymentTenureDays INT NULL,
        EmploymentSentinelFlag BIT NOT NULL,
        OccupationType NVARCHAR(100) NOT NULL,
        OrganizationType NVARCHAR(100) NOT NULL,
        FamilyMemberCount DECIMAL(9,2) NULL,
        RegionPopulationRelative DECIMAL(18,10) NULL,
        RegionRating INT NULL,
        RegionCityRating INT NULL,
        CarAgeYears INT NULL,
        GenderUnknownFlag BIT NOT NULL,
        SourceBatchID BIGINT NOT NULL,
        LoadedAtUtc DATETIME2(3) NOT NULL
            CONSTRAINT DF_nds_Applicant_LoadedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_nds_Applicant PRIMARY KEY CLUSTERED (ApplicationID),
        CONSTRAINT CK_nds_Applicant_Split CHECK (DatasetSplit IN ('TRAIN', 'TEST')),
        CONSTRAINT FK_nds_Applicant_Batch FOREIGN KEY (SourceBatchID)
            REFERENCES ctl.ETLBatch (BatchID)
    );
END;
GO

IF OBJECT_ID(N'nds.LoanApplication', N'U') IS NULL
BEGIN
    CREATE TABLE nds.LoanApplication
    (
        ApplicationID BIGINT NOT NULL,
        TargetFlag BIT NULL,
        ContractType NVARCHAR(100) NOT NULL,
        CreditAmount DECIMAL(19,2) NULL,
        AnnuityAmount DECIMAL(19,2) NULL,
        GoodsPriceAmount DECIMAL(19,2) NULL,
        SuiteType NVARCHAR(100) NOT NULL,
        ApplicationWeekday VARCHAR(20) NULL,
        ApplicationHour TINYINT NULL,
        ExternalScore1 DECIMAL(18,10) NULL,
        ExternalScore2 DECIMAL(18,10) NULL,
        ExternalScore3 DECIMAL(18,10) NULL,
        MissingAnnuityFlag BIT NOT NULL,
        MissingGoodsPriceFlag BIT NOT NULL,
        SourceBatchID BIGINT NOT NULL,
        LoadedAtUtc DATETIME2(3) NOT NULL
            CONSTRAINT DF_nds_LoanApplication_LoadedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_nds_LoanApplication PRIMARY KEY CLUSTERED (ApplicationID),
        CONSTRAINT FK_nds_LoanApplication_Applicant FOREIGN KEY (ApplicationID)
            REFERENCES nds.Applicant (ApplicationID),
        CONSTRAINT FK_nds_LoanApplication_Batch FOREIGN KEY (SourceBatchID)
            REFERENCES ctl.ETLBatch (BatchID),
        CONSTRAINT CK_nds_LoanApplication_Target CHECK (TargetFlag IN (0, 1) OR TargetFlag IS NULL)
    );
END;
GO

IF OBJECT_ID(N'nds.PreviousApplication', N'U') IS NULL
BEGIN
    CREATE TABLE nds.PreviousApplication
    (
        PreviousApplicationID BIGINT NOT NULL,
        ApplicationID BIGINT NOT NULL,
        ContractType NVARCHAR(100) NOT NULL,
        ContractStatus NVARCHAR(100) NOT NULL,
        ClientType NVARCHAR(100) NOT NULL,
        PortfolioType NVARCHAR(100) NOT NULL,
        ProductType NVARCHAR(100) NOT NULL,
        ApplicationAmount DECIMAL(19,2) NULL,
        CreditAmount DECIMAL(19,2) NULL,
        AnnuityAmount DECIMAL(19,2) NULL,
        DownPaymentAmount DECIMAL(19,2) NULL,
        GoodsPriceAmount DECIMAL(19,2) NULL,
        DecisionDaysRelative INT NULL,
        PaymentCount DECIMAL(12,2) NULL,
        FirstDrawingDaysRelative INT NULL,
        FirstDueDaysRelative INT NULL,
        LastDueFirstVersionDaysRelative INT NULL,
        LastDueDaysRelative INT NULL,
        TerminationDaysRelative INT NULL,
        DateSentinelFlag BIT NOT NULL,
        NonPositivePaymentCountFlag BIT NOT NULL,
        NegativeAmountFlag BIT NOT NULL,
        SourceBatchID BIGINT NOT NULL,
        LoadedAtUtc DATETIME2(3) NOT NULL
            CONSTRAINT DF_nds_PreviousApplication_LoadedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_nds_PreviousApplication PRIMARY KEY CLUSTERED (PreviousApplicationID),
        CONSTRAINT FK_nds_PreviousApplication_Applicant FOREIGN KEY (ApplicationID)
            REFERENCES nds.Applicant (ApplicationID),
        CONSTRAINT FK_nds_PreviousApplication_Batch FOREIGN KEY (SourceBatchID)
            REFERENCES ctl.ETLBatch (BatchID)
    );

    CREATE INDEX IX_nds_PreviousApplication_ApplicationID
        ON nds.PreviousApplication (ApplicationID);
END;
GO

IF OBJECT_ID(N'nds.BureauCredit', N'U') IS NULL
BEGIN
    CREATE TABLE nds.BureauCredit
    (
        BureauCreditID BIGINT NOT NULL,
        ApplicationID BIGINT NOT NULL,
        CreditStatus NVARCHAR(50) NOT NULL,
        CreditCurrency NVARCHAR(50) NOT NULL,
        CreditType NVARCHAR(100) NOT NULL,
        CreditDaysRelative INT NULL,
        CreditEndDaysRelative INT NULL,
        ActualEndDaysRelative INT NULL,
        UpdateDaysRelative INT NULL,
        OverdueDays INT NULL,
        CreditAmount DECIMAL(19,2) NULL,
        DebtAmount DECIMAL(19,2) NULL,
        CreditLimitAmount DECIMAL(19,2) NULL,
        OverdueAmount DECIMAL(19,2) NULL,
        MaxOverdueAmount DECIMAL(19,2) NULL,
        AnnuityAmount DECIMAL(19,2) NULL,
        ProlongationCount INT NULL,
        NegativeDebtFlag BIT NOT NULL,
        SourceBatchID BIGINT NOT NULL,
        LoadedAtUtc DATETIME2(3) NOT NULL
            CONSTRAINT DF_nds_BureauCredit_LoadedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_nds_BureauCredit PRIMARY KEY CLUSTERED (BureauCreditID),
        CONSTRAINT FK_nds_BureauCredit_Applicant FOREIGN KEY (ApplicationID)
            REFERENCES nds.Applicant (ApplicationID),
        CONSTRAINT FK_nds_BureauCredit_Batch FOREIGN KEY (SourceBatchID)
            REFERENCES ctl.ETLBatch (BatchID)
    );

    CREATE INDEX IX_nds_BureauCredit_ApplicationID
        ON nds.BureauCredit (ApplicationID);
END;
GO

IF OBJECT_ID(N'nds.BureauMonthlyStatus', N'U') IS NULL
BEGIN
    CREATE TABLE nds.BureauMonthlyStatus
    (
        BureauMonthlyStatusKey BIGINT IDENTITY(1,1) NOT NULL,
        BureauCreditID BIGINT NOT NULL,
        RelativeMonth INT NOT NULL,
        StatusCode VARCHAR(20) NOT NULL,
        ParentMissingFlag BIT NOT NULL,
        SourceRowNumber BIGINT NOT NULL,
        SourceBatchID BIGINT NOT NULL,
        LoadedAtUtc DATETIME2(3) NOT NULL
            CONSTRAINT DF_nds_BureauMonthlyStatus_LoadedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_nds_BureauMonthlyStatus PRIMARY KEY CLUSTERED (BureauMonthlyStatusKey),
        CONSTRAINT FK_nds_BureauMonthlyStatus_Batch FOREIGN KEY (SourceBatchID)
            REFERENCES ctl.ETLBatch (BatchID)
    );

    CREATE INDEX IX_nds_BureauMonthlyStatus_BusinessKey
        ON nds.BureauMonthlyStatus (BureauCreditID, RelativeMonth);
END;
GO

IF OBJECT_ID(N'nds.InstallmentPayment', N'U') IS NULL
BEGIN
    CREATE TABLE nds.InstallmentPayment
    (
        InstallmentPaymentKey BIGINT IDENTITY(1,1) NOT NULL,
        PreviousApplicationID BIGINT NOT NULL,
        ApplicationID BIGINT NOT NULL,
        InstallmentVersion DECIMAL(12,2) NULL,
        InstallmentNumber INT NULL,
        DueDaysRelative INT NULL,
        PaymentDaysRelative INT NULL,
        ScheduledAmount DECIMAL(19,2) NULL,
        PaidAmount DECIMAL(19,2) NULL,
        PaymentDelayDays INT NULL,
        DaysLate INT NULL,
        PaymentVarianceAmount DECIMAL(19,2) NULL,
        PaymentRecordedFlag BIT NOT NULL,
        ParentMissingFlag BIT NOT NULL,
        SourceRowNumber BIGINT NOT NULL,
        SourceBatchID BIGINT NOT NULL,
        LoadedAtUtc DATETIME2(3) NOT NULL
            CONSTRAINT DF_nds_InstallmentPayment_LoadedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_nds_InstallmentPayment PRIMARY KEY CLUSTERED (InstallmentPaymentKey),
        CONSTRAINT FK_nds_InstallmentPayment_Applicant FOREIGN KEY (ApplicationID)
            REFERENCES nds.Applicant (ApplicationID),
        CONSTRAINT FK_nds_InstallmentPayment_Batch FOREIGN KEY (SourceBatchID)
            REFERENCES ctl.ETLBatch (BatchID)
    );

    CREATE INDEX IX_nds_InstallmentPayment_ApplicationID
        ON nds.InstallmentPayment (ApplicationID);
    CREATE INDEX IX_nds_InstallmentPayment_PreviousID
        ON nds.InstallmentPayment (PreviousApplicationID);
END;
GO

IF OBJECT_ID(N'nds.POSCashMonthly', N'U') IS NULL
BEGIN
    CREATE TABLE nds.POSCashMonthly
    (
        POSCashMonthlyKey BIGINT IDENTITY(1,1) NOT NULL,
        PreviousApplicationID BIGINT NOT NULL,
        ApplicationID BIGINT NOT NULL,
        RelativeMonth INT NOT NULL,
        InstallmentCount DECIMAL(12,2) NULL,
        FutureInstallmentCount DECIMAL(12,2) NULL,
        ContractStatus NVARCHAR(100) NOT NULL,
        DaysPastDue INT NULL,
        DaysPastDueTolerance INT NULL,
        ParentMissingFlag BIT NOT NULL,
        SourceRowNumber BIGINT NOT NULL,
        SourceBatchID BIGINT NOT NULL,
        LoadedAtUtc DATETIME2(3) NOT NULL
            CONSTRAINT DF_nds_POSCashMonthly_LoadedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_nds_POSCashMonthly PRIMARY KEY CLUSTERED (POSCashMonthlyKey),
        CONSTRAINT FK_nds_POSCashMonthly_Applicant FOREIGN KEY (ApplicationID)
            REFERENCES nds.Applicant (ApplicationID),
        CONSTRAINT FK_nds_POSCashMonthly_Batch FOREIGN KEY (SourceBatchID)
            REFERENCES ctl.ETLBatch (BatchID)
    );

    CREATE INDEX IX_nds_POSCashMonthly_BusinessKey
        ON nds.POSCashMonthly (PreviousApplicationID, RelativeMonth);
END;
GO

IF OBJECT_ID(N'nds.CreditCardMonthly', N'U') IS NULL
BEGIN
    CREATE TABLE nds.CreditCardMonthly
    (
        CreditCardMonthlyKey BIGINT IDENTITY(1,1) NOT NULL,
        PreviousApplicationID BIGINT NOT NULL,
        ApplicationID BIGINT NOT NULL,
        RelativeMonth INT NOT NULL,
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
            CONSTRAINT DF_nds_CreditCardMonthly_LoadedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_nds_CreditCardMonthly PRIMARY KEY CLUSTERED (CreditCardMonthlyKey),
        CONSTRAINT FK_nds_CreditCardMonthly_Applicant FOREIGN KEY (ApplicationID)
            REFERENCES nds.Applicant (ApplicationID),
        CONSTRAINT FK_nds_CreditCardMonthly_Batch FOREIGN KEY (SourceBatchID)
            REFERENCES ctl.ETLBatch (BatchID)
    );

    CREATE INDEX IX_nds_CreditCardMonthly_BusinessKey
        ON nds.CreditCardMonthly (PreviousApplicationID, RelativeMonth);
END;
GO
