# SQL workspace

_Script SQL được chạy theo thứ tự số ở đầu tên file_

**Owner runtime trên Windows:** Nguyễn Văn Hộp (23127192). Nguyễn Thế Hiển hỗ trợ đối chiếu source logic và expected baseline từ Mac.

---

## 📁 Cấu trúc đề xuất

```text
sql/
├── 00_admin/       # Database, schema, roles
├── 01_staging/     # STG tables and audit
├── 02_nds/         # Normalized data store
├── 03_dds/         # Dimensions and facts
├── 04_etl/         # Stored procedures and merge logic
├── 05_tests/       # Data-quality and reconciliation queries
└── 06_analytics/   # KPI validation queries
```

## ✅ Quy ước

- Script phải chạy lại được hoặc kiểm tra object trước khi tạo
- Mỗi bảng có comment về grain và business key
- Không dùng `SELECT *` trong ETL production
- Mọi phép chia dùng `NULLIF` để tránh chia cho 0
- Mọi fact load phải kiểm tra duplicate theo grain
- Tên surrogate key dùng hậu tố `Key`; business key giữ tên nguồn khi phù hợp

## 🚀 Script đã triển khai

Nếu dùng **SQLCMD mode**, mở terminal tại thư mục `sql` và chạy `000_deploy_all.sql`; file này triển khai toàn bộ object theo đúng dependency rồi chạy smoke test. Trong SSMS cần bật **Query → SQLCMD Mode** trước khi chạy file tổng.

| Thứ tự | Script | Mục đích |
| ---: | --- | --- |
| 1 | `00_admin/000_create_database.sql` | Tạo database `HomeCreditBI` nếu chưa có |
| 2 | `00_admin/001_create_control_layer.sql` | Tạo schema và bảng audit/control |
| 3 | `00_admin/002_seed_source_files.sql` | Khởi tạo danh mục file nguồn |
| 4 | `00_admin/003_create_batch_procedures.sql` | Tạo procedures quản lý vòng đời batch/file load |
| 5 | `01_staging/010_create_staging_tables.sql` | Tạo 7 bảng staging từ schema đã profile |
| 6 | `02_nds/020_create_nds_tables.sql` | Tạo 8 bảng NDS và các cờ chất lượng |
| 7 | `03_dds/030_create_dds_tables.sql` | Tạo 6 dimensions và 7 facts theo star schema |
| 8 | `04_etl/040_create_clean_views.sql` | Chuẩn hóa sentinel, category, missing và anomaly thành clean views |
| 9 | `04_etl/041_load_nds.sql` | Tạo procedure nạp NDS có transaction và khóa an toàn |
| 10 | `04_etl/042_load_dds.sql` | Tạo procedure full-load DDS, unknown members và train scope |
| 11 | `05_tests/050_validate_staging.sql` | Tạo procedure kiểm tra staging theo batch |
| 12 | `05_tests/051_validate_nds.sql` | Đối soát row count, sentinel, flags và target sau clean |
| 13 | `05_tests/052_validate_dds.sql` | Kiểm tra grain, scope, row parity và KPI invariants của DDS |
| 14 | `05_tests/054_validate_kpi_baseline.sql` | So DDS với expected counts từ independent full-file scan |
| 15 | `06_analytics/060_create_analytics_views.sql` | Tạo semantic/KPI views ổn định cho SQL và Power BI |
| 16 | `06_analytics/061_kpi_reconciliation.sql` | Truy vấn bằng chứng KPI; sửa `@BatchID` trước khi chạy |
| 17 | `06_analytics/062_data_dictionary_query.sql` | Xuất technical dictionary từ SQL Server catalogs |
| Verify | `05_tests/053_smoke_test_schema.sql` | Xác nhận object và seed data sau deploy |

Chạy các script trên trong database Home Credit đã chọn. Script tạo object không xóa dữ liệu. Riêng
`etl.usp_LoadNDS` chỉ thay toàn bộ NDS khi người chạy chủ động truyền `@ConfirmReplace = 1`; raw và STG
không bị thay đổi.

## ▶️ Lệnh chạy sau khi SSIS đã load STG

```sql
EXEC ctl.usp_ValidateHomeCreditStaging @BatchID = 1;
EXEC etl.usp_LoadNDS @BatchID = 1, @ConfirmReplace = 0;
EXEC etl.usp_ValidateNDS @BatchID = 1, @PersistResults = 1;
EXEC etl.usp_LoadDDS @BatchID = 1, @ConfirmReplace = 0;
EXEC etl.usp_ValidateDDS @BatchID = 1, @PersistResults = 1;
EXEC etl.usp_ValidateKPIBaseline @BatchID = 1, @PersistResults = 1;
```

Nếu NDS/DDS đã có dữ liệu và batch mới đã được xác nhận, chạy lại loader tương ứng với
`@ConfirmReplace = 1`. Không dùng `1` trước khi staging validation đạt.
