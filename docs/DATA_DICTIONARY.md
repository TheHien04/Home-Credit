# Data dictionary — curated layers

## Table-level dictionary

| Layer | Table | Grain | Primary/business key | Purpose |
| --- | --- | --- | --- | --- |
| NDS | `Applicant` | One current applicant/application ID | `ApplicationID` | Clean demographic and profile attributes |
| NDS | `LoanApplication` | One current loan application | `ApplicationID` | Amounts, target and external scores |
| NDS | `PreviousApplication` | One previous application | `PreviousApplicationID` | Previous decision and requested/approved amounts |
| NDS | `BureauCredit` | One bureau credit | `BureauCreditID` | External credit, debt and overdue data |
| NDS | `BureauMonthlyStatus` | One source bureau-month row | Surrogate + source row | Monthly bureau status, including unmatched parents |
| NDS | `InstallmentPayment` | One source payment row | Surrogate + source row | Due/payment timing and amounts |
| NDS | `POSCashMonthly` | One source POS/cash-month row | Surrogate + source row | POS/cash monthly contract status and DPD |
| NDS | `CreditCardMonthly` | One source card-month row | Surrogate + source row | Credit-card balance, payment and receivable snapshot |
| DDS | `DimApplicant` | One TRAIN applicant + unknown | `ApplicantKey`; `ApplicationID` | Conformed applicant segmentation |
| DDS | `DimContract` | One normalized contract type | `ContractKey` | Shared current/previous contract category |
| DDS | `DimApplicationStatus` | One previous-decision status | `ApplicationStatusKey` | Approval classification |
| DDS | `DimCreditStatus` | One bureau status | `CreditStatusKey` | Active/non-active classification |
| DDS | `DimRelativeMonth` | One relative month + unknown | `RelativeMonthKey` | Shared monthly axis |
| DDS | `DimAffordabilityBand` | One annuity/income band | Fixed key | Descriptive burden band |
| DDS | `FactLoanApplication` | One labeled TRAIN application | Fact key; unique `ApplicationID` | Default and portfolio KPIs |
| DDS | `FactPreviousApplication` | One previous application for TRAIN applicant | Fact key; unique previous ID | Approval and history KPIs |
| DDS | `FactInstallmentPayment` | One source installment-payment row for TRAIN applicant | Fact key; batch + source row | Payment behavior KPIs |
| DDS | `FactBureauCredit` | One bureau credit for TRAIN applicant | Fact key; unique bureau ID | Active debt and overdue KPIs |
| DDS | `FactBureauMonthlySnapshot` | TRAIN-linked or unmatched bureau-month row | Fact key; batch + source row | Bureau status history |
| DDS | `FactPOSCashMonthly` | One POS/cash-month row for TRAIN applicant | Fact key; batch + source row | Monthly POS behavior |
| DDS | `FactCreditCardMonthly` | One card-month row for TRAIN applicant | Fact key; batch + source row | Monthly card utilization/payment behavior |

## Common technical columns

| Column | Meaning |
| --- | --- |
| `*Key` | DDS surrogate key or NDS technical fact key |
| `ApplicationID` | Source `SK_ID_CURR` business identifier |
| `PreviousApplicationID` | Source `SK_ID_PREV` business identifier |
| `BureauCreditID` | Source `SK_ID_BUREAU` business identifier |
| `SourceBatchID` | ETL lineage to `ctl.ETLBatch` |
| `SourceRowNumber` | One-based row position in the source data flow |
| `LoadedAtUtc` | Warehouse insert timestamp in UTC |
| `ParentMissingFlag` | Supplied parent record could not be found; row retained |
| `IsUnknown` | DDS unknown member used for failed/not-applicable lookup |

## Derived measures and flags

| Column | Formula/meaning |
| --- | --- |
| `AgeYears` | `FLOOR(-DAYS_BIRTH / 365.25)` |
| `EmploymentTenureDays` | Absolute negative employment days; sentinel → null |
| `PaymentDelayDays` | Payment relative day − due relative day |
| `DaysLate` | Positive part of payment delay |
| `PaymentVarianceAmount` | Paid amount − scheduled amount |
| `PaymentRecordedFlag` | Both payment day and payment amount exist |
| `LatePaymentFlag` | Recorded payment and `DaysLate > 0` |
| `CreditToIncomeRatio` | Current credit / income when income > 0 |
| `AnnuityToIncomeRatio` | Current annuity / income when income > 0 |
| `ExternalScoreAverage` | Mean of available external scores; null when all missing |
| `NegativeDebtFlag` | Bureau debt is below zero; value remains unchanged |

For the exact SQL type, nullability, PK and FK of every deployed column, run `sql/06_analytics/062_data_dictionary_query.sql` after database creation.
