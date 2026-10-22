# Source-to-target mapping

_Mapping chính thức cho luồng Source → STG → NDS → DDS_

## Quy ước chung

| Rule | Nội dung |
| --- | --- |
| Audit | Mọi dòng STG có `BatchID`, `SourceRowNumber`, `LoadedAtUtc` |
| Raw null | Empty field được nạp SQL `NULL`, không tự đổi thành 0 |
| Category | Blank/`XNA` → `Unknown`; `XAP` → `Not applicable` tại NDS |
| Mandatory key | Null key/grain → reject và làm batch thất bại |
| Unmatched parent | Giữ row, bật `ParentMissingFlag`; DDS dùng unknown member khi cần |
| Analytical scope | DDS default analytics chỉ lấy `DatasetSplit = TRAIN` |

## Application

| Source | STG | NDS | DDS | Transformation |
| --- | --- | --- | --- | --- |
| `SK_ID_CURR` | `stg.Application.SK_ID_CURR` | `ApplicationID` | Applicant/Application business key | Bắt buộc, duy nhất |
| file name | `DatasetSplit` | `DatasetSplit` | Filter load | train → `TRAIN`, test → `TEST` |
| `TARGET` | `TARGET` | `TargetFlag` | `DefaultFlag` | Train `0/1`; test null; DDS chỉ train |
| `CODE_GENDER` | giữ nguồn | `GenderCode` | `DimApplicant.GenderCode` | Blank/`XNA` → `Unknown` |
| `DAYS_BIRTH` | giữ nguồn | `AgeYears` | Age and `AgeBand` | `FLOOR(-days/365.25)` |
| `DAYS_EMPLOYED` | giữ nguồn | `EmploymentTenureDays` | Không đưa vào fact MVP | `365243` → null + flag; ngày âm → số ngày dương |
| `AMT_INCOME_TOTAL` | giữ nguồn | `IncomeAmount` | Applicant + loan fact | Giữ null; dùng làm mẫu số nếu >0 |
| `AMT_CREDIT` | giữ nguồn | `CreditAmount` | Loan fact | Decimal(19,2) |
| `AMT_ANNUITY` | giữ nguồn | `AnnuityAmount` | Loan fact | Null được giữ và flag |
| `AMT_GOODS_PRICE` | giữ nguồn | `GoodsPriceAmount` | Loan fact | Null được giữ và flag |
| `EXT_SOURCE_1/2/3` | giữ nguồn | ba score | `ExternalScoreAverage` | Trung bình các score có dữ liệu |
| Contract/category columns | giữ nguồn | normalized category | Dimensions/attributes | Trim và chuẩn hóa unknown |

## Previous application

| Source | NDS/DDS target | Transformation |
| --- | --- | --- |
| `SK_ID_PREV` | `PreviousApplicationID` | Business key bắt buộc, duy nhất |
| `SK_ID_CURR` | Applicant lookup | Chỉ train applicant vào DDS |
| `NAME_CONTRACT_STATUS` | `DimApplicationStatus` | `Approved` → `IsApproved = 1` |
| `NAME_CONTRACT_TYPE` | `DimContract` | Conformed với current application |
| Amount columns | Previous fact | Giữ null và giá trị âm; negative flag |
| `CNT_PAYMENT` | Previous fact | `<=0` giữ nguyên và bật flag |
| Five sentinel date columns | NDS relative dates | `365243` → null + `DateSentinelFlag` |

## Installment payment

| Source | NDS/DDS target | Transformation |
| --- | --- | --- |
| `SK_ID_PREV`, `SK_ID_CURR` | Degenerate key + applicant lookup | Bắt buộc |
| `DAYS_INSTALMENT` | `DueDaysRelative` | Giữ ngày tương đối |
| `DAYS_ENTRY_PAYMENT` | `PaymentDaysRelative` | Missing được giữ null |
| payment day − due day | `PaymentDelayDays` | Signed difference |
| positive delay | `DaysLate` | `MAX(delay,0)` |
| `AMT_INSTALMENT` | `ScheduledAmount` | Decimal(19,2) |
| `AMT_PAYMENT` | `PaidAmount` | Missing được giữ null |
| payment − scheduled | `PaymentVarianceAmount` | Chỉ tính khi đủ hai amount |
| derived | `PaymentRecordedFlag` | 1 khi cả ngày và amount payment có dữ liệu |
| derived | `LatePaymentFlag` | 1 khi recorded và `DaysLate > 0` |

## Bureau

| Source | NDS/DDS target | Transformation |
| --- | --- | --- |
| `SK_ID_BUREAU` | `BureauCreditID` | Business key bắt buộc, duy nhất |
| `SK_ID_CURR` | Applicant lookup | Chỉ train applicant vào DDS |
| `CREDIT_ACTIVE` | `DimCreditStatus` | `Active` → `IsActive = 1` |
| `AMT_CREDIT_SUM` | `CreditAmount` | Giữ null |
| `AMT_CREDIT_SUM_DEBT` | `DebtAmount` | Debt âm được giữ và bật flag |
| `AMT_CREDIT_SUM_OVERDUE` | `OverdueAmount` | Giữ null |
| bureau balance `MONTHS_BALANCE` | `DimRelativeMonth` | Giữ số tháng tương đối |
| bureau balance unmatched | Monthly fact unknown applicant | Không reject; bật parent-missing flag |

## POS/cash và credit card monthly

| Source rule | Target rule |
| --- | --- |
| `MONTHS_BALANCE` | Lookup `DimRelativeMonth` |
| `SK_ID_CURR` | Lookup train `DimApplicant` |
| unmatched `SK_ID_PREV` | Giữ fact và bật `ParentMissingFlag` |
| `SK_DPD`, `SK_DPD_DEF` | Giữ nguyên, không clamp |
| Credit-card negative limit | Giữ và bật `NegativeLimitFlag` |

## Reconciliation contract

- Source rows = STG accepted + STG rejected.
- NDS count = STG rows có mandatory grain hợp lệ.
- Current DDS count = labeled TRAIN application count.
- History DDS counts = NDS rows liên kết TRAIN applicant, trừ bureau monthly orphan được giữ bằng unknown member.
- Default numerator và denominator phải bất biến từ application train đến DDS và Power BI.
