# Canonical Power BI measures

Create these measures once and reuse them across visuals. Names below are the official KPI names for the report.

```DAX
Total Applications =
COUNTROWS ( FactLoanApplication )

Default Applications =
SUM ( FactLoanApplication[DefaultFlag] )

Default Rate =
DIVIDE ( [Default Applications], [Total Applications] )

Average Credit Amount =
AVERAGE ( FactLoanApplication[CreditAmount] )

Average Annuity Amount =
AVERAGE ( FactLoanApplication[AnnuityAmount] )

Average Income Amount =
AVERAGE ( FactLoanApplication[IncomeAmount] )

Average Credit-to-Income =
AVERAGE ( FactLoanApplication[CreditToIncomeRatio] )

Average Annuity-to-Income =
AVERAGE ( FactLoanApplication[AnnuityToIncomeRatio] )

Total Previous Applications =
COUNTROWS ( FactPreviousApplication )

Approved Previous Applications =
CALCULATE (
    [Total Previous Applications],
    DimApplicationStatus[IsApproved] = TRUE ()
)

Previous Approval Rate =
DIVIDE ( [Approved Previous Applications], [Total Previous Applications] )

Recorded Payment Rows =
CALCULATE (
    COUNTROWS ( FactInstallmentPayment ),
    FactInstallmentPayment[PaymentRecordedFlag] = TRUE ()
)

Late Payment Rows =
CALCULATE (
    COUNTROWS ( FactInstallmentPayment ),
    FactInstallmentPayment[LatePaymentFlag] = TRUE ()
)

Late Payment Rate =
DIVIDE ( [Late Payment Rows], [Recorded Payment Rows] )

Average Days Late =
CALCULATE (
    AVERAGE ( FactInstallmentPayment[DaysLate] ),
    FactInstallmentPayment[LatePaymentFlag] = TRUE ()
)

Total Scheduled Amount =
SUM ( FactInstallmentPayment[ScheduledAmount] )

Total Paid Amount =
SUM ( FactInstallmentPayment[PaidAmount] )

Payment Variance =
[Total Paid Amount] - [Total Scheduled Amount]

Total Bureau Credits =
COUNTROWS ( FactBureauCredit )

Active Bureau Credits =
CALCULATE (
    [Total Bureau Credits],
    DimCreditStatus[IsActive] = TRUE ()
)

Active Bureau Debt =
CALCULATE (
    SUM ( FactBureauCredit[DebtAmount] ),
    DimCreditStatus[IsActive] = TRUE ()
)

Total Bureau Overdue Amount =
SUM ( FactBureauCredit[OverdueAmount] )

Missing Payment Rows =
CALCULATE (
    COUNTROWS ( FactInstallmentPayment ),
    FactInstallmentPayment[PaymentRecordedFlag] = FALSE ()
)

Missing Payment Rate =
DIVIDE ( [Missing Payment Rows], COUNTROWS ( FactInstallmentPayment ) )

Unmatched Installment Rows =
CALCULATE (
    COUNTROWS ( FactInstallmentPayment ),
    FactInstallmentPayment[ParentMissingFlag] = TRUE ()
)

Negative Bureau Debt Rows =
CALCULATE (
    COUNTROWS ( FactBureauCredit ),
    FactBureauCredit[NegativeDebtFlag] = TRUE ()
)
```

## Validation targets

- `Total Applications` must equal **307,511**.
- `Default Applications` must equal **24,825**.
- `Default Rate` must equal approximately **8.0729%**.
- DAX values must match `sql/06_analytics/061_kpi_reconciliation.sql` under the same filters.
