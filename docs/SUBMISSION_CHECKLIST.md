# Submission checklist — Home Credit BI

_Nhóm 8 · 4 thành viên · cập nhật ngày 29/10/2026_

---

## ✅ Phần đã sẵn sàng để chuyển sang máy Windows

**Owner phần đã thực hiện trên MacBook:** Nguyễn Thế Hiển (22127107).

- [x] 10 CSV có manifest SHA-256 và giữ nguyên bản gốc
- [x] Full DQ scan trên 58.441.149 dòng nghiệp vụ
- [x] Full KPI baseline và aggregate reconciliation
- [x] DDL cho control, STG, NDS và DDS
- [x] Transaction-safe NDS/DDS load procedures
- [x] STG, NDS, DDS, schema và KPI validators
- [x] Semantic SQL views và canonical DAX measures
- [x] SSIS specification cho 5 packages
- [x] Báo cáo kỹ thuật Chương 1–7 có runtime placeholders
- [x] Local project validator
- [x] Repository inventory và MVP scope cho 30/10
- [x] Application mapping/profile tập trung
- [x] TRAIN/TEST samples 5.000 dòng và SHA-256 test oracle
- [x] Progress status matrix và speaker notes 2–3 phút

Chạy trước khi sao chép project:

```bash
python3 scripts/validate_kpi_baseline.py
python3 scripts/validate_project_artifacts.py
```

Hai lệnh phải cùng trả về `PASS`.

## 🪟 Công việc bắt buộc trên Windows

| Gate | Owner chính | Điều kiện hoàn tất | Evidence bắt buộc |
| --- | --- | --- | --- |
| W01A ETL toolchain | Nguyễn Trường Duy | VS, SSDT/SSIS và SQL connection mở được | Ảnh version và SSIS Designer |
| W01B Integration host | Nguyễn Văn Hộp | Canonical SQL Server, `sqlcmd` và SSIS solution sẵn sàng | Ảnh version và connection |
| W01C BI toolchain | Nguyễn Quốc Bảo | Power BI Desktop kết nối được canonical database | Ảnh version và connection |
| W02 SQL deploy | Nguyễn Văn Hộp | Smoke test tìm đủ 59 objects | Result grid `PASS` |
| W03 STG load | Nguyễn Trường Duy | Package được tích hợp và chạy trên canonical host; 7 bảng STG đúng nguồn | SSIS tree và row counts |
| W04 NDS/DDS load | Nguyễn Văn Hộp | 12 NDS + 12 DDS tests `PASS` | Result grids và batch ID |
| W05 KPI reconcile | Nguyễn Văn Hộp | 12 KPI baseline tests `PASS` | Result grid `KPI_%` |
| W06 Power BI | Nguyễn Quốc Bảo | 5 pages, SQL = DAX | Screenshots từng page |
| W07 Rerun | Nguyễn Trường Duy | Chạy lại không duplicate | Before/after counts |
| W08 Final package | Nguyễn Quốc Bảo | Report, PBIX, SSIS, SQL và evidence đủ | Cả nhóm kiểm tra chéo |

Không đánh dấu một gate là hoàn tất nếu chỉ có source code mà chưa có result grid hoặc screenshot tương ứng.

## ▶️ Trình tự bàn giao một lần

1. Copy nguyên project và dataset sang máy tích hợp của Hộp; dành ít nhất 10 GB trống.
2. Cả ba máy Windows cài đúng công cụ mình dùng và thống nhất SQL Server/SSIS target version.
3. Hộp chạy `scripts/Deploy-HomeCreditSql.ps1` trên canonical database; lưu smoke-test evidence.
4. Duy dựng staging package; Hộp nhập package vào final solution và chạy lại trên canonical host.
5. Dùng duy nhất một canonical `BatchID` cho STG, NDS, DDS, validator và Power BI evidence.
6. Chạy `etl.usp_ValidateKPIBaseline`; mọi `KPI_%` phải `PASS`.
7. Dựng Power BI theo `powerbi/MODEL_SPEC.md` và nhập `powerbi/MEASURES_DAX.md`.
8. Điền `[RUNTIME-01]` đến `[RUNTIME-05]` trong báo cáo, sau đó review chéo.

## 📁 Quy ước evidence

```text
evidence/
├── 01_tool_versions/
├── 02_sql_deploy/
├── 03_ssis_staging/
├── 04_nds_dds_tests/
├── 05_kpi_reconciliation/
├── 06_powerbi/
└── 07_rerun/
```

Tên file nên bắt đầu bằng test ID hoặc gate ID, ví dụ `W05_KPI_baseline_batch_1.png`. Ảnh phải hiển thị batch ID, test code, expected, actual và status; không chụp credential hoặc Kaggle token.

## 📦 Gói nộp cuối

- [ ] `Nhom08_HomeCreditBI_Report.docx` và bản PDF
- [ ] `Nhom08_HomeCreditBI_Slides.pptx`
- [ ] `Nhom08_HomeCreditBI_YYYYMMDD.pbix`
- [ ] SSIS solution có năm package `.dtsx`
- [ ] Thư mục `sql/` và `scripts/`
- [ ] Evidence theo cấu trúc phía trên
- [ ] README có hướng dẫn chạy và danh sách thành viên
- [ ] Không có password, token, connection string nhạy cảm hoặc CSV lớn trong gói mã nguồn

Dataset chỉ đính kèm khi quy định môn học yêu cầu; nếu không, dẫn nguồn Kaggle và cung cấp manifest SHA-256 để tái lập.

## 🔍 Review chéo cuối cùng

| Người thực hiện | Người review | Phạm vi |
| --- | --- | --- |
| Nguyễn Thế Hiển | Nguyễn Quốc Bảo | Mac artifacts: profiling, DQ rules, KPI baseline, report source |
| Nguyễn Trường Duy | Nguyễn Văn Hộp | Windows environment, STG, reject flow và rerun evidence |
| Nguyễn Văn Hộp | Nguyễn Trường Duy | NDS/DDS packages, SQL tests, KPI và performance |
| Nguyễn Quốc Bảo | Nguyễn Thế Hiển | Power BI filters, DAX, evidence và presentation |

Reviewer xác nhận công thức, population và evidence; không chỉ kiểm tra giao diện.
