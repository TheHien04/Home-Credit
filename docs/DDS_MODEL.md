# DDS dimensional model — Home Credit BI

_Logical and physical design of the dimensional data store used by SQL Server and Power BI_

---

## 🎯 Modeling principles

- Declare one exact grain for every fact table before selecting measures
- Keep current applications and one-to-many credit histories in separate facts
- Reuse conformed dimensions for applicant, contract, status, and relative month
- Resolve missing lookups to explicit unknown members instead of dropping facts
- Preserve source business identifiers as degenerate keys where drill-through is required
- Calculate default KPIs only from `FactLoanApplication`

The source does not provide real calendar dates. `DimRelativeMonth` therefore represents anonymized month offsets and must not be presented as a conventional calendar dimension.

## 📊 Bus matrix

| Business process | Applicant | Contract | Application status | Credit status | Relative month | Affordability |
| --- | :---: | :---: | :---: | :---: | :---: | :---: |
| Current loan application | ✓ | ✓ |  |  |  | ✓ |
| Previous application | ✓ | ✓ | ✓ |  |  |  |
| Installment payment | ✓ |  |  |  |  |  |
| Bureau credit | ✓ |  |  | ✓ |  |  |
| Bureau monthly status | ✓/Unknown |  |  |  | ✓ |  |
| POS/cash monthly snapshot | ✓ |  |  |  | ✓ |  |
| Credit-card monthly snapshot | ✓ |  |  |  | ✓ |  |

## 🏗️ Current and previous application star

```mermaid
erDiagram
    accTitle: Application Analytics Star Schema
    accDescr: Core dimensional model for current and previous Home Credit applications, including applicant, contract, status, and affordability dimensions with primary and foreign keys.

    DIM_APPLICANT ||--o| FACT_LOAN_APPLICATION : "describes"
    DIM_APPLICANT ||--o{ FACT_PREVIOUS_APPLICATION : "submits"
    DIM_CONTRACT ||--o{ FACT_LOAN_APPLICATION : "classifies"
    DIM_CONTRACT ||--o{ FACT_PREVIOUS_APPLICATION : "classifies"
    DIM_AFFORDABILITY_BAND ||--o{ FACT_LOAN_APPLICATION : "bands"
    DIM_APPLICATION_STATUS ||--o{ FACT_PREVIOUS_APPLICATION : "records decision"

    DIM_APPLICANT {
        bigint ApplicantKey PK "Surrogate key"
        bigint ApplicationID UK "Source SK_ID_CURR"
        string GenderCode "Normalized category"
        smallint AgeYears "Derived age"
        string AgeBand "Reporting band"
        decimal IncomeAmount "Applicant income"
        string IncomeBand "Reporting band"
        boolean IsUnknown "Unknown member flag"
    }

    DIM_CONTRACT {
        int ContractKey PK "Surrogate key"
        string ContractType UK "Normalized type"
        boolean IsUnknown "Unknown member flag"
    }

    DIM_AFFORDABILITY_BAND {
        int AffordabilityBandKey PK "Fixed key"
        string AffordabilityBand UK "Ratio band"
        decimal MinimumRatio "Inclusive lower bound"
        decimal MaximumRatio "Exclusive upper bound"
        tinyint SortOrder "Display order"
    }

    DIM_APPLICATION_STATUS {
        int ApplicationStatusKey PK "Surrogate key"
        string ApplicationStatus UK "Previous decision"
        boolean IsApproved "Approval classifier"
        boolean IsUnknown "Unknown member flag"
    }

    FACT_LOAN_APPLICATION {
        bigint LoanApplicationKey PK "Fact surrogate key"
        bigint ApplicationID UK "Degenerate business key"
        bigint ApplicantKey FK "Applicant lookup"
        int ContractKey FK "Contract lookup"
        int AffordabilityBandKey FK "Affordability lookup"
        boolean DefaultFlag "TARGET measure"
        decimal CreditAmount "Approved credit"
        decimal AnnuityToIncomeRatio "Protected ratio"
    }

    FACT_PREVIOUS_APPLICATION {
        bigint PreviousApplicationFactKey PK "Fact surrogate key"
        bigint PreviousApplicationID UK "Source SK_ID_PREV"
        bigint ApplicantKey FK "Applicant lookup"
        int ContractKey FK "Contract lookup"
        int ApplicationStatusKey FK "Decision lookup"
        decimal ApplicationAmount "Requested amount"
        decimal CreditAmount "Approved amount"
        boolean NegativeAmountFlag "Quality flag"
    }
```

## 💳 Payment and bureau stars

```mermaid
erDiagram
    accTitle: Payment And Bureau Stars
    accDescr: Fact constellations for installment payments, bureau credit, and bureau monthly history sharing applicant, credit-status, and relative-month dimensions.

    DIM_APPLICANT ||--o{ FACT_INSTALLMENT_PAYMENT : "makes"
    DIM_APPLICANT ||--o{ FACT_BUREAU_CREDIT : "owns"
    DIM_CREDIT_STATUS ||--o{ FACT_BUREAU_CREDIT : "classifies"
    DIM_APPLICANT ||--o{ FACT_BUREAU_MONTHLY : "links or defaults"
    DIM_RELATIVE_MONTH ||--o{ FACT_BUREAU_MONTHLY : "positions"

    DIM_APPLICANT {
        bigint ApplicantKey PK "Surrogate key"
        bigint ApplicationID UK "Source SK_ID_CURR"
        boolean IsUnknown "Unknown member flag"
    }

    DIM_CREDIT_STATUS {
        int CreditStatusKey PK "Surrogate key"
        string CreditStatus UK "Bureau status"
        boolean IsActive "Active classifier"
    }

    DIM_RELATIVE_MONTH {
        int RelativeMonthKey PK "Surrogate key"
        int RelativeMonth UK "Anonymized month offset"
        string MonthBand "Reporting band"
    }

    FACT_INSTALLMENT_PAYMENT {
        bigint InstallmentPaymentFactKey PK "Fact surrogate key"
        bigint ApplicantKey FK "Applicant lookup"
        bigint PreviousApplicationID "Degenerate parent ID"
        int PaymentDelayDays "Signed delay"
        int DaysLate "Positive delay"
        decimal ScheduledAmount "Expected payment"
        decimal PaidAmount "Recorded payment"
        boolean LatePaymentFlag "Late classifier"
        boolean ParentMissingFlag "Quality flag"
    }

    FACT_BUREAU_CREDIT {
        bigint BureauCreditFactKey PK "Fact surrogate key"
        bigint BureauCreditID UK "Source SK_ID_BUREAU"
        bigint ApplicantKey FK "Applicant lookup"
        int CreditStatusKey FK "Status lookup"
        decimal CreditAmount "Credit amount"
        decimal DebtAmount "Current debt"
        decimal OverdueAmount "Overdue amount"
        boolean NegativeDebtFlag "Quality flag"
    }

    FACT_BUREAU_MONTHLY {
        bigint BureauMonthlyFactKey PK "Fact surrogate key"
        bigint ApplicantKey FK "Applicant or unknown"
        int RelativeMonthKey FK "Month lookup"
        bigint BureauCreditID "Degenerate parent ID"
        string BureauStatusCode "Monthly status"
        boolean ParentMissingFlag "Quality flag"
    }
```

`PreviousApplicationID` and `BureauCreditID` remain degenerate identifiers in child facts. The model deliberately avoids fact-to-fact relationships; Power BI filters facts through dimensions and uses the identifiers only for audit or drill-through.

## 📅 Monthly snapshot stars

```mermaid
erDiagram
    accTitle: Monthly Snapshot Star Schemas
    accDescr: POS cash and credit-card monthly facts share applicant and relative-month dimensions while preserving source contract identifiers and parent-quality flags.

    DIM_APPLICANT ||--o{ FACT_POS_CASH_MONTHLY : "owns"
    DIM_APPLICANT ||--o{ FACT_CREDIT_CARD_MONTHLY : "owns"
    DIM_RELATIVE_MONTH ||--o{ FACT_POS_CASH_MONTHLY : "positions"
    DIM_RELATIVE_MONTH ||--o{ FACT_CREDIT_CARD_MONTHLY : "positions"

    DIM_APPLICANT {
        bigint ApplicantKey PK "Surrogate key"
        bigint ApplicationID UK "Source SK_ID_CURR"
        boolean IsUnknown "Unknown member flag"
    }

    DIM_RELATIVE_MONTH {
        int RelativeMonthKey PK "Surrogate key"
        int RelativeMonth UK "Anonymized month offset"
        string MonthBand "Reporting band"
    }

    FACT_POS_CASH_MONTHLY {
        bigint POSCashMonthlyFactKey PK "Fact surrogate key"
        bigint ApplicantKey FK "Applicant lookup"
        int RelativeMonthKey FK "Month lookup"
        bigint PreviousApplicationID "Degenerate contract ID"
        decimal InstallmentCount "Scheduled installments"
        int DaysPastDue "Observed DPD"
        boolean ParentMissingFlag "Quality flag"
    }

    FACT_CREDIT_CARD_MONTHLY {
        bigint CreditCardMonthlyFactKey PK "Fact surrogate key"
        bigint ApplicantKey FK "Applicant lookup"
        int RelativeMonthKey FK "Month lookup"
        bigint PreviousApplicationID "Degenerate contract ID"
        decimal BalanceAmount "Statement balance"
        decimal CreditLimitAmount "Credit limit"
        decimal TotalPaymentAmount "Payment flow"
        boolean NegativeLimitFlag "Quality flag"
        boolean ParentMissingFlag "Quality flag"
    }
```

## 📏 Fact grain and additivity

| Fact | Exact grain | Additive measures | Non-additive or semi-additive |
| --- | --- | --- | --- |
| `FactLoanApplication` | One labeled TRAIN application | Credit, annuity, goods price, income | Default rate, affordability ratios |
| `FactPreviousApplication` | One previous application linked to a TRAIN applicant | Requested, credit, down-payment amounts | Approval rate |
| `FactInstallmentPayment` | One source payment row linked to a TRAIN applicant | Scheduled, paid, variance amounts | Late-payment rate, average delay |
| `FactBureauCredit` | One bureau credit linked to a TRAIN applicant | Credit, debt, overdue amounts | Active-credit rate |
| `FactBureauMonthlySnapshot` | One source bureau-month row in DDS scope | Row count | Status distribution over time |
| `FactPOSCashMonthly` | One source POS/cash contract-month row | Row count | Balance-like snapshot values |
| `FactCreditCardMonthly` | One source credit-card contract-month row | Payments within a month | Balance, limit, utilization snapshots |

Monthly balances and debt-like values must not be summed across relative months as though they were transaction flows. Ratios must be recalculated from their numerators and denominators or aggregated with an explicitly approved method.

## 🔑 Key and relationship policy

| Rule | Implementation |
| --- | --- |
| Dimension primary key | Integer or bigint surrogate key |
| Source identity | Retained as a business or degenerate key |
| Relationship direction | One-way dimension-to-fact in Power BI |
| Fact-to-fact relationship | Prohibited |
| Missing category lookup | Resolve to the dimension's unknown member |
| Missing source parent | Preserve the fact and set `ParentMissingFlag = 1` |
| Batch lineage | Every mutable dimension and fact references `ctl.ETLBatch` |
| Duplicate protection | Unique constraint or batch-plus-source-row grain check |

## 🔄 History strategy

The current implementation uses a reproducible full-load strategy. Dimensions represent the latest normalized source state within a canonical batch; they do not implement Slowly Changing Dimension Type 2 because the dataset is a static competition snapshot without reliable business-effective dates.

If incremental sources become available, the next design step is to add `ValidFromUtc`, `ValidToUtc`, and `IsCurrent` to historized dimensions, define change-detection hashes, and document late-arriving-dimension handling. These features are intentionally outside the current MVP rather than silently simulated.

## ⚠️ Interpretation guardrails

- `DefaultRate`, approval rate, and late-payment rate are ratios and cannot be added across groups
- `ExternalScoreAverage` is a descriptive feature, not a calibrated probability of default
- Negative financial values remain in the warehouse with quality flags because they may represent adjustments
- Unknown members preserve population counts but must be visible in data-quality reporting
- Default-risk visuals must use `FactLoanApplication`, never a joined history table

For exact SQL types, nullability, indexes, constraints, and deployed foreign keys, use `sql/03_dds/030_create_dds_tables.sql` and run `sql/06_analytics/062_data_dictionary_query.sql` after deployment.
