# KPI dictionary — Home Credit BI

_Một định nghĩa chính thức cho SQL, Power BI và báo cáo_

| KPI | Business definition | Numerator / expression | Denominator / population | Null and filter rules |
| --- | --- | --- | --- | --- |
| Total applications | Số hồ sơ vay hiện tại có nhãn | Count current-loan fact rows | Labeled TRAIN applications | DDS đã loại test |
| Default applications | Số hồ sơ có `TARGET=1` | Sum `DefaultFlag` | Labeled TRAIN applications | Không suy diễn nguyên nhân |
| Default rate | Tỷ lệ hồ sơ default | Default applications | Total applications | `DIVIDE`; hiển thị 2 decimals |
| Average credit amount | Credit trung bình mỗi hồ sơ | Average `CreditAmount` | Rows có credit | Không thay null bằng 0 |
| Credit-to-income | Quy mô credit so với income năm | `CreditAmount / IncomeAmount` từng hồ sơ | Income > 0 | Average ratio theo hồ sơ |
| Annuity-to-income | Gánh nặng annuity so với income | `AnnuityAmount / IncomeAmount` từng hồ sơ | Income > 0 và annuity có dữ liệu | Dùng affordability band, không gọi là khả năng default |
| Previous approval rate | Tỷ lệ previous applications được approved | Count status Approved | All previous applications thuộc train applicants | Unknown status nằm trong denominator, không trong numerator |
| Recorded payment rows | Payment rows đủ ngày và amount thực trả | Count `PaymentRecordedFlag=1` | Installment rows thuộc train applicants | Không coi missing payment là payment bằng 0 |
| Late payment rate | Tỷ lệ payment ghi nhận bị trả trễ | Count recorded rows có `DaysLate>0` | Recorded payment rows | Trả sớm/đúng hạn không vào numerator |
| Average days late | Số ngày trễ trung bình trong các lần trễ | Average positive `DaysLate` | Late payment rows | Không average cả zero/early rows |
| Active bureau debt | Tổng debt của bureau credits đang Active | Sum `DebtAmount` where status active | Active bureau credits | Debt âm được giữ và DQ flag |
| Bureau overdue amount | Tổng amount quá hạn được bureau báo cáo | Sum `OverdueAmount` | Bureau credits thuộc train applicants | Không cộng monthly snapshot |
| Missing payment rate | Tỷ lệ installment rows chưa đủ payment record | Count `PaymentRecordedFlag=0` | All installment rows | KPI data quality, không phải default |
| Parent-missing rate | Tỷ lệ history rows thiếu parent record cung cấp | Count `ParentMissingFlag=1` | Từng fact history | Báo riêng từng nguồn |

## Baseline phải khớp

| Metric | Expected full-data value |
| --- | ---: |
| Total applications | 307.511 |
| Default applications | 24.825 |
| Non-default applications | 282.686 |
| Default rate | 8,0729% |

Các KPI khác đã có expected baseline từ full CSV scan; số liệu warehouse chính thức chỉ được chốt sau khi full ETL chạy trên SQL Server và `etl.usp_ValidateDDS` không có `FAIL`.

Baseline đối soát trước SQL Server đã được tính bằng full-file streaming scan tại
[`KPI_BASELINE_FULL_SCAN.md`](KPI_BASELINE_FULL_SCAN.md). Các số này là expected values cho SQL và Power BI, nhưng chỉ được đánh dấu runtime Pass sau khi hai nền tảng trả cùng kết quả.

## Interpretation guardrails

- So sánh phân khúc là mô tả association, không chứng minh quan hệ nhân quả.
- Nhóm ít hồ sơ phải hiển thị sample size cùng tỷ lệ.
- Demographic attributes không được dùng làm căn cứ duy nhất để khuyến nghị từ chối tín dụng.
- Snapshot balance không được cộng qua tháng như doanh thu hoặc payment flow.
- Test applications không có target và không nằm trong default-rate population.
