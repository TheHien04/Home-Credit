# Data profile report — Home Credit Default Risk

_Phân tích ban đầu cho đồ án BI/DW Nhóm 8 — ngày 21/10/2026_

---

## 📋 Phạm vi kiểm tra

Phân tích này giữ nguyên dữ liệu gốc và chỉ tạo artifact dẫn xuất trong `data/staging/` và `data/processed/`.

| Hạng mục | Phạm vi |
| --- | --- |
| Inventory | Toàn bộ 10 CSV |
| Row count | Toàn bộ file |
| Key integrity | Toàn bộ khóa chính và khóa ngoại trọng yếu |
| Missingness/schema | 100.000 dòng đầu mỗi bảng nghiệp vụ |
| Raw rows emitted | Không |
| Train/test overlap | Kiểm tra toàn bộ `SK_ID_CURR` |

> ⚠️ **Giới hạn:** Missingness và phân phối cột là kết quả mẫu có giới hạn 100.000 dòng, không phải chứng nhận toàn bộ file. Row count và các phép kiểm tra khóa ghi rõ “toàn bộ” mới là kết quả full scan.

## 📊 Inventory dữ liệu

| File | Data rows | Columns | Vai trò |
| --- | ---: | ---: | --- |
| `application_train.csv` | 307.511 | 122 | Hồ sơ hiện tại có `TARGET` |
| `application_test.csv` | 48.744 | 121 | Hồ sơ Kaggle không có nhãn |
| `bureau.csv` | 1.716.428 | 17 | Khoản tín dụng bên ngoài |
| `bureau_balance.csv` | 27.299.925 | 3 | Trạng thái bureau theo tháng |
| `previous_application.csv` | 1.670.214 | 37 | Đơn vay Home Credit trước |
| `POS_CASH_balance.csv` | 10.001.358 | 8 | POS/cash balance theo tháng |
| `credit_card_balance.csv` | 3.840.312 | 23 | Credit-card balance theo tháng |
| `installments_payments.csv` | 13.605.401 | 8 | Lịch sử trả góp |
| `HomeCredit_columns_description.csv` | 219 | 5 | Metadata cột |
| `sample_submission.csv` | 48.744 | 2 | Mẫu submission, không phân tích |

Tổng cộng có **58.538.856 data rows** trên 10 file. Dataset chính thức mô tả các bảng ở nhiều grain như hồ sơ hiện tại, khoản vay, thanh toán và snapshot theo tháng.[^1]

## 🎯 Nhãn default

### Phân phối toàn bộ application train

| TARGET | Hồ sơ | Tỷ lệ |
| ---: | ---: | ---: |
| 0 | 282.686 | 91,93% |
| 1 | 24.825 | 8,07% |
| Tổng | 307.511 | 100,00% |

### Diễn giải

- `TARGET` chỉ tồn tại ở grain của hồ sơ vay hiện tại
- Không được sao chép `TARGET` xuống từng dòng payment/monthly balance rồi tính trung bình, vì khách hàng có nhiều lịch sử sẽ bị tăng trọng số
- KPI default rate phải tính trên `FactLoanApplication` hoặc distinct `SK_ID_CURR`
- Mất cân bằng 8,07% cần được lưu ý nếu nhóm mở rộng sang machine learning

## 🔗 Kiểm tra khóa và quan hệ

### Khóa chính xác nhận toàn bộ

| Bảng và khóa | Rows | Distinct | Duplicate | Missing |
| --- | ---: | ---: | ---: | ---: |
| `application_train.SK_ID_CURR` | 307.511 | 307.511 | 0 | 0 |
| `application_test.SK_ID_CURR` | 48.744 | 48.744 | 0 | 0 |
| `previous_application.SK_ID_PREV` | 1.670.214 | 1.670.214 | 0 | 0 |
| `bureau.SK_ID_BUREAU` | 1.716.428 | 1.716.428 | 0 | 0 |

Train và test không có `SK_ID_CURR` trùng nhau.

### Coverage theo SK_ID_CURR

Tất cả dòng của năm bảng lịch sử có `SK_ID_CURR` đều khớp train hoặc test; không có missing hay unknown customer key.

| File | Train rows | Test rows | Unknown rows |
| --- | ---: | ---: | ---: |
| `bureau.csv` | 1.465.325 | 251.103 | 0 |
| `previous_application.csv` | 1.413.701 | 256.513 | 0 |
| `POS_CASH_balance.csv` | 8.543.375 | 1.457.983 | 0 |
| `credit_card_balance.csv` | 3.227.965 | 612.347 | 0 |
| `installments_payments.csv` | 11.591.592 | 2.013.809 | 0 |

> 📌 **Quyết định ETL:** STG và NDS giữ cả train/test để bảo toàn dữ liệu và tách bằng `DatasetSplit`. DDS phục vụ KPI default chỉ semi-join train; test rows không được đi vào mẫu số KPI có `TARGET`.

### Coverage theo khoản vay lịch sử

| Child key | Unmatched rows | Total rows | Tỷ lệ |
| --- | ---: | ---: | ---: |
| `POS_CASH.SK_ID_PREV` | 340.561 | 10.001.358 | 3,41% |
| `credit_card.SK_ID_PREV` | 1.082.816 | 3.840.312 | 28,20% |
| `installments.SK_ID_PREV` | 1.250.826 | 13.605.401 | 9,19% |
| `bureau_balance.SK_ID_BUREAU` | 3.120.184 | 27.299.925 | 11,43% |

“Unmatched” chỉ có nghĩa khóa không xuất hiện trong bảng cha được cung cấp; chưa đủ bằng chứng để kết luận bản ghi sai.

### Ảnh hưởng lên thiết kế

- Không đặt foreign key bắt buộc trực tiếp từ mọi balance/payment row sang `previous_application`
- Giữ `SK_ID_PREV` và `SK_ID_BUREAU` như business/degenerate key để truy vết
- Dùng unknown member khi lookup dimension không tìm thấy
- Liên kết fact lịch sử trực tiếp với Applicant/Application bằng `SK_ID_CURR` khi cột này tồn tại
- Ghi số unmatched vào `ctl.DataQualityResult` dưới trạng thái `WARN`, không tự động reject

## 🔍 Missingness và sentinel

### Kết quả mẫu 100.000 dòng

| Bảng | Cột có missing | Cột missing ≥50% | Missing cao nhất |
| --- | ---: | ---: | ---: |
| `application_train` | 67 | 41 | 69,73% |
| `previous_application` | 15 | 4 | 99,66% |
| `bureau` | 6 | 2 | 77,89% |
| `credit_card_balance` | 9 | 0 | 22,23% |
| `POS_CASH_balance` | 2 | 0 | 0,25% |
| `bureau_balance` | 0 | 0 | 0,00% |
| `installments_payments` | 0 | 0 | 0,00% trong sample |

Các nhóm missing cao đáng chú ý:

- Thuộc tính tòa nhà trong `application_train` thường thiếu khoảng 50–70%
- `EXT_SOURCE_1` thiếu khoảng 56,28% trong sample
- `OWN_CAR_AGE` thiếu khoảng 66,02% trong sample
- `RATE_INTEREST_PRIMARY` và `RATE_INTEREST_PRIVILEGED` thiếu khoảng 99,66%
- `bureau.AMT_ANNUITY` thiếu khoảng 77,89%

### Sentinel và category bất thường

Full scan của `application_train` xác nhận:

- `DAYS_EMPLOYED = 365243` xuất hiện 55.374 lần
- `CODE_GENDER = XNA` xuất hiện 4 lần
- `AMT_ANNUITY` thiếu 12 lần

`DAYS_EMPLOYED = 365243` không được hiểu là hơn 1.000 năm làm việc. ETL cần chuyển thành unknown/null có cờ chất lượng riêng, giữ raw value ở staging để truy vết.

### Chính sách xử lý đề xuất

| Trường hợp | STG | NDS | DDS |
| --- | --- | --- | --- |
| Empty field | Giữ raw null | Chuẩn hóa null | Unknown/blank tùy dimension |
| Sentinel 365243 | Giữ nguyên | Null + quality flag | Không dùng tính thâm niên |
| XNA/XAP | Giữ nguyên | Map Unknown/Not applicable riêng | Unknown member phù hợp |
| High-missing column | Giữ | Giữ nếu có nghiệp vụ | Không đưa vào core dimension mặc định |
| Unmatched business key | Giữ | Gắn trạng thái unmatched | Unknown surrogate key |

## 💾 Grain được chốt

| Bảng/Fact | Grain |
| --- | --- |
| `application_train` | Một hồ sơ vay hiện tại |
| `previous_application` | Một đơn vay Home Credit trước |
| `bureau` | Một khoản tín dụng do bureau báo cáo |
| `bureau_balance` | Một khoản bureau trong một tháng tương đối |
| `POS_CASH_balance` | Một hợp đồng POS/cash trong một tháng tương đối |
| `credit_card_balance` | Một hợp đồng thẻ trong một tháng tương đối |
| `installments_payments` | Một payment record của một kỳ trả; có thể có nhiều payment cho cùng kỳ |

Không giả định `installments_payments` có khóa tự nhiên duy nhất từ số kỳ trả. DDS nên dùng surrogate fact key và giữ các cột nguồn để đối soát.

## ⚠️ Rủi ro phân tích

- Join nhiều bảng one-to-many trước khi tính default rate sẽ nhân bản hồ sơ
- Dùng test rows trong dashboard default sẽ làm sai mẫu số vì test không có `TARGET`
- Tự thay missing bằng 0 sẽ trộn “không có dữ liệu” với “giá trị thực bằng 0”
- Xóa unmatched `SK_ID_PREV`/`SK_ID_BUREAU` sẽ làm mất lượng lớn lịch sử hợp lệ
- Các biến demographic chỉ nên dùng để giám sát phân khúc/fairness, không suy ra quan hệ nhân quả
- Các ngày là thời gian tương đối, không phải ngày lịch hoàn chỉnh

## ✅ Quyết định cho bước modeling

1. Staging tải toàn bộ file và thêm `BatchID`, `SourceRowNumber`, `IngestedAtUtc`
2. NDS tách train/test bằng `DatasetSplit`
3. DDS phân tích default chỉ lấy train
4. Fact history liên kết `ApplicantKey` trực tiếp khi có `SK_ID_CURR`
5. Lookup không thấy parent sẽ dùng unknown key, đồng thời ghi cảnh báo DQ
6. Các thuộc tính missing cao không nằm trong MVP dashboard trừ khi có câu hỏi nghiệp vụ rõ
7. KPI default luôn lấy từ `FactLoanApplication`

## 🔗 Artifact và tái lập

- `data/processed/eda/*.profile.json`: profile 100.000 dòng mỗi bảng
- `data/processed/eda/relationship_coverage.json`: full scan coverage theo `SK_ID_CURR`
- `data/processed/eda/core_key_integrity.json`: full scan khóa chính/khóa ngoại
- `scripts/create_bounded_csv_sample.py`: tạo sample dẫn xuất
- `scripts/profile_home_credit_relationships.py`: kiểm tra train/test coverage
- `scripts/profile_core_keys.py`: kiểm tra key integrity
- `data/processed/eda/full_data_quality_rules.json`: full scan rule counts
- `scripts/profile_data_quality_rules.py`: tái lập full scan chất lượng dữ liệu
- `sql/04_etl/040_create_clean_views.sql`: transformations STG → NDS
- `sql/05_tests/051_validate_nds.sql`: acceptance tests sau clean

Quy trình EDA áp dụng nguyên tắc dữ liệu gốc bất biến, báo cáo rõ phạm vi quét và không tự động xóa/impute dữ liệu.[^2]

## 🔗 Tài liệu tham khảo

[^1]: Home Credit Group. (2018). "Home Credit Default Risk — Data." _Kaggle_. https://www.kaggle.com/competitions/home-credit-default-risk/data

[^2]: Kassis, T., Agarwal, V., He, Y., Patel, D., & Brueckner, A. M. (2026). "Scientific Agent Skills: A Library of Procedural Knowledge for Research Agents." _arXiv_. https://doi.org/10.48550/arXiv.2609.00065
