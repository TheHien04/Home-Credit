# DDS model — Home Credit BI

## Bus matrix

| Business process | Applicant | Contract | App status | Credit status | Relative month | Affordability |
| --- | :---: | :---: | :---: | :---: | :---: | :---: |
| Current loan application | ✓ | ✓ |  |  |  | ✓ |
| Previous application | ✓ | ✓ | ✓ |  |  |  |
| Installment payment | ✓ |  |  |  |  |  |
| Bureau credit | ✓ |  |  | ✓ |  |  |
| Bureau monthly status | ✓/Unknown |  |  |  | ✓ |  |
| POS/cash monthly | ✓ |  |  |  | ✓ |  |
| Credit-card monthly | ✓ |  |  |  | ✓ |  |

## Fact grain

| Fact | Exact grain | Additive measures |
| --- | --- | --- |
| `FactLoanApplication` | Một labeled train application | Credit, annuity, goods price, income |
| `FactPreviousApplication` | Một previous application | Application/credit/down-payment amounts |
| `FactInstallmentPayment` | Một source payment row của một installment | Scheduled, paid, variance |
| `FactBureauCredit` | Một bureau credit | Credit, debt, overdue |
| `FactBureauMonthlySnapshot` | Một source bureau-month row | Row count |
| `FactPOSCashMonthly` | Một source POS/cash-month row | DPD, installment counts |
| `FactCreditCardMonthly` | Một source credit-card-month row | Balance, limit, payment, receivable |

## Semi-additive/non-additive cautions

- `DefaultRate`, approval rate và late-payment rate là ratio; không cộng giữa nhóm.
- Monthly balance/debt là snapshot; không cộng qua thời gian để diễn giải như flow.
- `CreditToIncomeRatio` và `AnnuityToIncomeRatio` nên average/median theo hồ sơ, không cộng.
- `ExternalScoreAverage` là feature mô tả, không phải xác suất default đã hiệu chỉnh.
- Tổng debt âm vẫn được giữ; dashboard phải cung cấp DQ flag hoặc dùng tooltip giải thích.

## Unknown-member policy

- Mỗi dimension có một member `IsUnknown = 1` được tạo trong full load.
- Lookup category không thấy sẽ dùng unknown key thay vì làm mất fact.
- Bureau monthly thiếu parent được giữ với unknown applicant.
- POS/card/installment có `SK_ID_CURR`, nên vẫn lookup được applicant ngay cả khi thiếu `SK_ID_PREV` parent.
