# Data workspace

_Dữ liệu Kaggle chỉ lưu cục bộ và không commit vào repository_

---

## 📁 Cấu trúc

```text
data/
├── raw/        # File CSV gốc, không chỉnh sửa
├── staging/    # File tạm hoặc sample phục vụ phát triển
└── processed/  # Output kiểm tra nếu cần
```

## ✅ Quy tắc

- Giữ nguyên tên và checksum của file gốc
- Không chỉnh sửa trực tiếp file trong `raw/`
- Ghi nguồn, ngày tải và phiên bản trong inventory
- Không đưa token Kaggle hoặc thông tin đăng nhập vào repository
- Dùng sample có seed cố định khi cần phát triển nhanh
- Đối chiếu CSV gốc bằng `shasum -a 256 -c docs/RAW_DATA_SHA256.txt` từ project root

## 📋 Inventory cần lập

| File | Shape (rows × columns) | Grain | Key | Status |
| --- | --- | --- | --- | --- |
| `application_train.csv` | 307.511 × 122 | Một hồ sơ hiện tại | `SK_ID_CURR` | Profiled |
| `previous_application.csv` | 1.670.214 × 37 | Một đơn vay trước | `SK_ID_PREV` | Profiled |
| `bureau.csv` | 1.716.428 × 17 | Một khoản bureau | `SK_ID_BUREAU` | Profiled |
| `bureau_balance.csv` | 27.299.925 × 3 | Khoản bureau/tháng | Composite | Profiled |
| `installments_payments.csv` | 13.605.401 × 8 | Giao dịch/kỳ trả | Surrogate | Profiled |
