# Data cleaning rules — Home Credit

_Quy tắc làm sạch từ STG sang NDS, cập nhật sau full scan ngày 22/10/2026_

---

## 📋 Nguyên tắc

- Raw CSV và STG giữ nguyên giá trị nguồn
- NDS chuẩn hóa kiểu dữ liệu, sentinel và category
- Không thay missing bằng 0 khi 0 có ý nghĩa nghiệp vụ khác
- Không cắt ngọn hoặc xóa outlier tự động
- Giá trị tài chính bất thường nhưng có thể hợp lệ được giữ và gắn cờ
- Chỉ reject dòng thiếu khóa bắt buộc hoặc vi phạm miền bắt buộc chắc chắn
- Mọi rule phải có mã, action, số dòng tác động và test xác nhận

## 🎯 Kết quả full-scan

| Rule | Rows | Tỷ lệ | Action |
| --- | ---: | ---: | --- |
| `APP_EMPLOYED_SENTINEL` | 55.374 | 18,01% | Chuyển tenure thành null, bật cờ |
| `APP_GENDER_UNKNOWN` | 4 | <0,01% | Map `Unknown` |
| `APP_MISSING_ANNUITY` | 12 | <0,01% | Giữ null |
| `APP_MISSING_GOODS_PRICE` | 278 | 0,09% | Giữ null |
| `PREV_DATE_SENTINEL` | 997.144 | 59,70% | Chuyển từng ngày sentinel thành null |
| `PREV_NONPOS_PAYMENT_COUNT` | 144.985 | 8,68% | Giữ và bật cờ structural |
| `PREV_NEGATIVE_AMOUNT` | 2 | <0,01% | Giữ và đưa vào review |
| `BUREAU_NEGATIVE_DEBT` | 8.418 | 0,49% | Giữ và bật cờ |
| `INST_MISSING_PAYMENT_DATE` | 2.905 | 0,02% | Giữ null, đánh dấu chưa thanh toán |
| `INST_MISSING_PAYMENT_AMOUNT` | 2.905 | 0,02% | Giữ null, đánh dấu chưa thanh toán |

Full scan không phát hiện:

- Khóa bắt buộc bị thiếu trong bảy bảng nghiệp vụ
- `TARGET` ngoài miền `0/1`
- Income hoặc credit hiện tại không dương
- `DAYS_BIRTH` không âm
- `EXT_SOURCE_1/2/3` ngoài khoảng `[0,1]`
- `MONTHS_BALANCE > 0`
- Status bureau monthly ngoài `0–5, C, X`
- DPD âm hoặc amount installment/payment âm

## ⚙️ Rule catalog

### Application

| Source | NDS target | Transformation |
| --- | --- | --- |
| `CODE_GENDER` | `GenderCode` | `XNA`/blank → `Unknown` |
| `FLAG_OWN_CAR` | `OwnCarFlag` | `Y→1`, `N→0`, khác → null |
| `FLAG_OWN_REALTY` | `OwnRealtyFlag` | `Y→1`, `N→0`, khác → null |
| `DAYS_BIRTH` | `AgeYears` | `FLOOR(-DAYS_BIRTH / 365.25)` |
| `DAYS_EMPLOYED` | `EmploymentTenureDays` | Negative → absolute days; `365243` → null |
| `XNA` category | Curated category | `Unknown` |
| `XAP` category | Curated category | `Not applicable` |
| Missing amount | Same amount | Giữ null, không điền 0 |

### Previous applications

| Source | NDS target | Transformation |
| --- | --- | --- |
| Relative date = `365243` | Relative date | Chuyển null |
| `CNT_PAYMENT <= 0` | Same + flag | Giữ giá trị, bật `NonPositivePaymentCountFlag` |
| Negative amount | Same + flag | Giữ giá trị, bật `NegativeAmountFlag` |
| Blank/`XNA` category | Curated category | `Unknown` |
| `XAP` category | Curated category | `Not applicable` |

### Bureau

| Source | NDS target | Transformation |
| --- | --- | --- |
| Negative debt | Same + flag | Giữ giá trị, bật `NegativeDebtFlag` |
| Missing annuity | Same | Giữ null |
| Relative days | Same | Giữ relative day; không đổi thành ngày lịch giả |

### Installments

| Source | NDS target | Transformation |
| --- | --- | --- |
| Missing entry date/amount | `PaymentRecordedFlag` | Giữ null, flag = 0 |
| Entry day − due day | `PaymentDelayDays` | Signed difference nếu đủ dữ liệu |
| Positive delay | `DaysLate` | `MAX(delay, 0)` |
| Payment − scheduled | `PaymentVarianceAmount` | Chỉ tính khi cả hai amount có dữ liệu |
| Missing parent `SK_ID_PREV` | `ParentMissingFlag` | Giữ fact, dùng unknown parent ở DDS |

### Monthly balances

| Source | NDS target | Transformation |
| --- | --- | --- |
| `MONTHS_BALANCE` | `RelativeMonth` | Giữ số tháng tương đối |
| Missing parent key | `ParentMissingFlag` | Giữ snapshot và bật cờ |
| DPD | Same | Giữ nguyên; không clamp |
| Bureau status `X` | Status | Giữ `Unknown/no status` riêng với missing |

## ✅ Acceptance criteria

- [ ] Raw row count không thay đổi ở STG
- [ ] Reject count bằng 0 cho dữ liệu hiện tại ở các rule bắt buộc
- [ ] 55.374 employment sentinel được chuyển tenure null
- [ ] 997.144 previous rows có ít nhất một sentinel date được chuẩn hóa
- [ ] 2.905 installment rows được đánh dấu payment chưa ghi nhận
- [ ] Negative bureau debt được giữ và có flag
- [ ] Unknown categories không còn dùng chung với SQL null
- [ ] Train/test được giữ tách biệt
- [ ] Default rate sau clean vẫn bằng 8,0729%
- [ ] Không mất unmatched history rows

## ⚠️ Không tự động thực hiện

- Không mean/median imputation
- Không winsorize income/credit
- Không xóa bureau debt âm
- Không xóa installment chưa thanh toán
- Không suy diễn ngày lịch từ ngày tương đối
- Không dùng thuộc tính demographic để kết luận nguyên nhân default
