# Repository inventory

_Nhóm 8 · kiểm kê phục vụ mốc trình bày 30/10/2026_

---

## Trạng thái tổng hợp

| Khu vực | Trạng thái | Bằng chứng | Việc còn lại |
| --- | --- | --- | --- |
| README và cấu trúc Git | EXIST | `README.md`, CI workflow | Cập nhật sau mỗi runtime gate |
| Raw intake và checksum | EXIST | `DATA_DOWNLOAD_AND_INTAKE.md`, `RAW_DATA_SHA256.txt` | Không đưa raw CSV lên Git |
| Profiling và DQ | EXIST | `DATA_PROFILE_REPORT.md`, `DATA_CLEANING_RULES.md` | Chụp SQL runtime results |
| Source-to-target mapping | EXIST | `SOURCE_TO_TARGET_MAPPING.md`, `MAPPING_APPLICATION_V01.md` | Reviewer ký xác nhận |
| SQL Server DDL | EXIST | `sql/00_admin` đến `sql/03_dds` | Deploy trên canonical host |
| SQL ETL và tests | EXIST | `sql/04_etl`, `sql/05_tests` | Chạy theo một `BatchID` |
| SSIS design | EXIST | `ssis/PACKAGE_BUILD_SPEC.md` | Hoàn thiện đủ năm package |
| SSIS application staging source | EXIST | `ssis/HomeCredit_BI/HomeCredit_ETL/` | Parameterize, build và chạy trên canonical Windows host |
| KPI baseline | VERIFIED LOCAL | `KPI_BASELINE_FULL_SCAN.md` | Đối soát SQL và DAX |
| Power BI specification | EXIST | `powerbi/MODEL_SPEC.md`, `MEASURES_DAX.md` | Tạo và refresh PBIX |
| Report và team plan | EXIST LOCAL | `latex/report`, `latex/team-plan` | Render và chèn runtime evidence |
| Runtime evidence | MISSING | Chưa có thư mục evidence chính thức | Duy/Hộp/Bảo thực hiện trên Windows |

## Quyết định phạm vi

- SSIS là công cụ ETL/orchestration chính theo thông báo mới của giảng viên.
- SQL Server là canonical database cho STG, NDS, DDS và audit.
- Power BI chỉ đọc DDS/analytics views đã qua validation.
- Mốc 30/10 ưu tiên vertical slice `application_train` và `application_test`; history sources là phần tiếp theo.
- Không đánh dấu runtime `PASS` từ source code hoặc mockup.

## Commit cơ sở

Kiểm kê này áp dụng từ commit chuyển lại kiến trúc SSIS trở đi. Khi nhóm thu evidence, mỗi artifact phải ghi commit hash và `BatchID` tương ứng.
