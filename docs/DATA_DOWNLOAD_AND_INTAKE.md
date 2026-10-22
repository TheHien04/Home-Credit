# Data download and intake

_Hướng dẫn đưa dữ liệu Home Credit vào workspace an toàn_

---

## 📥 Tải dữ liệu

1. Đăng nhập trang [Home Credit Default Risk](https://www.kaggle.com/competitions/home-credit-default-risk/data).
2. Chấp nhận Competition Rules bằng tài khoản Kaggle của bạn.
3. Chọn **Download All**.
4. Giải nén vào thư mục `home-credit-default-risk/` ở project root.
5. Không đổi tên hoặc chỉnh sửa các file CSV gốc.

> 🔐 **Bảo mật:** Không gửi username, password, API token hoặc file `kaggle.json`. Project chỉ cần các CSV đã tải.

## 📋 File cần có

| File | Mức ưu tiên | Mục đích |
| --- | --- | --- |
| `application_train.csv` | Core | Hồ sơ vay hiện tại và `TARGET` |
| `previous_application.csv` | Core | Đơn vay Home Credit trước đó |
| `bureau.csv` | Core | Tín dụng tại tổ chức khác |
| `bureau_balance.csv` | Core | Trạng thái bureau theo tháng |
| `installments_payments.csv` | Core | Lịch sử trả góp |
| `HomeCredit_columns_description.csv` | Core | Metadata và diễn giải cột |
| `POS_CASH_balance.csv` | Extension | Số dư POS/cash theo tháng |
| `credit_card_balance.csv` | Extension | Số dư thẻ theo tháng |
| `application_test.csv` | Không phân tích | Kaggle test set không có `TARGET` |
| `sample_submission.csv` | Không phân tích | Mẫu submission Kaggle |

## ✅ Kiểm tra sau khi giải nén

Chạy tại thư mục project:

```bash
python3 scripts/check_home_credit_data.py
```

Script chỉ đọc tên file, kích thước, header và số dòng; không in dữ liệu cá nhân hoặc các dòng thô. Kết quả `READY_FOR_CORE_PROFILE` nghĩa là đủ dữ liệu cho core scope.

## ⚠️ Quy tắc dữ liệu gốc

- Không mở rồi lưu lại CSV bằng Excel
- Không xóa null hoặc sửa category trong `home-credit-default-risk/`
- Không commit CSV lên Git
- Mọi sample hoặc dữ liệu dẫn xuất đặt ở `data/staging/` hoặc `data/processed/`
- Kết quả profiling phải ghi rõ giới hạn số dòng nếu chỉ quét một phần
- `HomeCredit_columns_description.csv` dùng encoding `cp1252`; các file nghiệp vụ được kiểm tra nghiêm ngặt dưới UTF-8/UTF-8-BOM
