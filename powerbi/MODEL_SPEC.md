# Power BI semantic model specification

## Import tables

Import the physical DDS dimensions and facts rather than joining them in Power Query. Use the analytical views only for SQL reconciliation or a simplified prototype.

### Core tables

- `dds.DimApplicant`
- `dds.DimContract`
- `dds.DimApplicationStatus`
- `dds.DimCreditStatus`
- `dds.DimRelativeMonth`
- `dds.DimAffordabilityBand`
- `dds.FactLoanApplication`
- `dds.FactPreviousApplication`
- `dds.FactInstallmentPayment`
- `dds.FactBureauCredit`

### Extension tables

- `dds.FactBureauMonthlySnapshot`
- `dds.FactPOSCashMonthly`
- `dds.FactCreditCardMonthly`

## Relationships

All relationships are `1 → *`, active and single-direction from dimension to fact.

| From | Column | To | Column |
| --- | --- | --- | --- |
| DimApplicant | `ApplicantKey` | FactLoanApplication | `ApplicantKey` |
| DimApplicant | `ApplicantKey` | FactPreviousApplication | `ApplicantKey` |
| DimApplicant | `ApplicantKey` | FactInstallmentPayment | `ApplicantKey` |
| DimApplicant | `ApplicantKey` | FactBureauCredit | `ApplicantKey` |
| DimApplicant | `ApplicantKey` | FactBureauMonthlySnapshot | `ApplicantKey` |
| DimApplicant | `ApplicantKey` | FactPOSCashMonthly | `ApplicantKey` |
| DimApplicant | `ApplicantKey` | FactCreditCardMonthly | `ApplicantKey` |
| DimContract | `ContractKey` | FactLoanApplication | `ContractKey` |
| DimContract | `ContractKey` | FactPreviousApplication | `ContractKey` |
| DimApplicationStatus | `ApplicationStatusKey` | FactPreviousApplication | `ApplicationStatusKey` |
| DimCreditStatus | `CreditStatusKey` | FactBureauCredit | `CreditStatusKey` |
| DimRelativeMonth | `RelativeMonthKey` | Three monthly facts | `RelativeMonthKey` |
| DimAffordabilityBand | `AffordabilityBandKey` | FactLoanApplication | `AffordabilityBandKey` |

Do not create fact-to-fact relationships. Do not enable bidirectional filtering merely to make a visual work.

## Sort and display settings

- Sort `DimAffordabilityBand[AffordabilityBand]` by `SortOrder`.
- Sort relative-month charts by `DimRelativeMonth[RelativeMonth]` ascending.
- Format rate measures as percentage with two decimals.
- Format monetary measures with thousands separators and no more than two decimals.
- Hide surrogate keys, `SourceBatchID`, `LoadedAtUtc` and `SourceRowNumber` from report view.
- Put all measures in a dedicated display folder or measure table named `_Measures`.

## Required report filters

- Exclude `DimApplicant[IsUnknown] = TRUE` from applicant segmentation visuals.
- On bureau-month visuals, expose `ParentMissingFlag` as a data-quality filter.
- Default KPIs require no train/test filter because DDS current-loan facts already contain labeled TRAIN rows only.
- Never calculate default rate from a joined history table; always use `FactLoanApplication`.

## Page-to-table mapping

| Page | Primary facts | Main dimensions |
| --- | --- | --- |
| Executive overview | FactLoanApplication | Applicant, Contract, Affordability |
| Credit risk profile | FactLoanApplication | Applicant, Contract, Affordability |
| Payment behavior | FactInstallmentPayment | Applicant |
| Credit history | FactPreviousApplication, FactBureauCredit | Applicant, Status, Contract |
| Data quality | All facts + `ctl.DataQualityResult` | Batch/test status |
