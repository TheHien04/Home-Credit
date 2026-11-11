# Hộp — bàn giao theo lịch 09–12/11/2026

Cập nhật 11/11/2026. Phạm vi: SQL nền, ba nguồn Credit History và NDS.
Nguồn yêu cầu: [timeline của nhóm](https://bi-miniproject-new-schedule.netlify.app/).
Tài liệu này cập nhật phần Hộp; các tỷ lệ và phân công trong tài liệu tháng 10
là thông tin lịch sử.

## Tiêu chí theo ngày

| Ngày | Yêu cầu | Trạng thái và bằng chứng |
| --- | --- | --- |
| 1 — 09/11 | SQL deploy/smoke, backup hợp lệ, project, batch chung | PASS kiểm tra hiện tại: 59 objects, 10 nguồn, backup CHECKSUM + VERIFYONLY hợp lệ, project mở/build được; batch tích hợp 4 |
| 2 — 10/11 | Full ba CSV, audit/count và đối soát | PASS: cả ba nguồn full đối soát đúng 30.686.567 dòng, ordinal duy nhất, không thiếu khóa bắt buộc, 0 reject; đối chiếu mọi trường trên mẫu 1.000 dòng/nguồn không sai lệch |
| 3 — 11/11 | NDS có dữ liệu, 12 tests PASS, audit chính xác | CHƯA HOÀN THÀNH: thiếu Application và Payment History cùng database/batch |
| 4 — 12/11 | Regression NDS, review/merge PR, bàn giao NDS READY | CHƯA HOÀN THÀNH: công cụ regression và review đã có; cần NDS thực, peer review/merge và kiểm tra sau tích hợp |

Không đánh dấu ngày 3 hoặc 4 PASS khi chỉ có source/metadata validation.
Không đóng batch chung khi các phần của Duy/Bảo chưa hoàn tất.

Draft PR: [#3 — Credit History và guarded NDS handoff](https://github.com/TheHien04/Home-Credit/pull/3).
Snapshot source `9f9991659542519e6d6b1b5a7ae563fde0bb00cd` được commit sau
khi thu runtime evidence. PR chưa merge; cần thành viên khác review và nghiệm
thu phần tích hợp còn thiếu trước khi chuyển ready.

## Full Credit History — audit thực tế batch 4

| File | FileLoadID | RowsRead = RowsAccepted | RowsRejected | Trạng thái |
| --- | ---: | ---: | ---: | --- |
| `bureau_balance.csv` | 9 | 27.299.925 | 0 | SUCCEEDED |
| `bureau.csv` | 10 | 1.716.428 | 0 | SUCCEEDED |
| `previous_application.csv` | 11 | 1.670.214 | 0 | SUCCEEDED |

Batch 4 thuộc `HomeCreditBI` trên instance hiện tại, pipeline
`HomeCredit_Team_FULL_20261111`. Nếu nhóm chuyển host, tạo/nhận batch chung ở
host đó và cấu hình lại; không mặc định số 4 có cùng ý nghĩa trên máy khác.

Kiểm thử chạy lại package BureauCredit bị chặn trước Data Flow: số dòng và
số audit không thay đổi. Đây là kiểm thử chống nạp trùng STG, chưa thay thế
regression NDS.

## Mã nguồn và thay đổi SQL

- [Project và hướng dẫn chạy Hộp](../ssis/TEAM/hop_credit_history/README.md):
  ba package CSV và một package STG validation → NDS load → NDS validation.
- Nạp NDS dùng `@ConfirmReplace=0`; không xóa dữ liệu hoặc chạy DDS.
- Thay đổi SQL duy nhất trong bản bàn giao là chuẩn hóa phép so sánh catalog
  trong `053_smoke_test_schema.sql` bằng `COLLATE DATABASE_DEFAULT`, xử lý khác
  biệt collation khi kiểm tra object. Không đổi collation của database/server.
- Tám clean view và hai procedure NDS trên database khớp source; xem
  `nds_deployed_source_comparison.json`.
- Bốn package portable đều qua SSIS metadata validation; Python preparation
  tests, KPI baseline và project artifact validation PASS.

## Đầu vào còn cần để tiếp tục ngày 3–4

| Owner | Nguồn | Số dòng full yêu cầu |
| --- | --- | ---: |
| Duy | `application_train.csv` | 307.511 |
| Duy | `application_test.csv` | 48.744 |
| Bảo | `POS_CASH_balance.csv` | 10.001.358 |
| Bảo | `installments_payments.csv` | 13.605.401 |
| Bảo | `credit_card_balance.csv` | 3.840.312 |

Mỗi file phải có audit SUCCEEDED, đúng counts, 0 reject và chung BatchID.
Project Application hiện tại còn thiếu destination, TEST và per-file audit;
xem [review tích hợp](../evidence/hop_credit_history/INTEGRATION_REVIEW.md).

Instance hiện tại là SQL Server 2022 Express; data file sau Credit History
đã khoảng 6 GB. Cần review dung lượng/host trước full STG + NDS + DDS.
Baseline của repository dùng Developer Edition; Express 2022 có giới hạn
10 GB/database theo [Microsoft](https://learn.microsoft.com/en-us/sql/sql-server/editions-and-components-of-sql-server-2022/).

## Tiếp tục trên database tích hợp

1. Xác nhận host, batch RUNNING và toàn bộ tám file audit; chạy
   `Verify-NDS.ps1 -Mode Readiness` với server/batch thực. Output thiếu nguồn
   phải giữ INCOMPLETE.
2. Chỉ khi đầu vào đủ: thực thi `04_Load_Validate_NDS.local.dtsx` trong VS,
   dùng batch chung. Package kiểm tra staging và không tự thay NDS cũ.
3. Lưu 12 kết quả NDS PASS và counts của tám bảng. Sau tích hợp chạy
   `Verify-NDS.ps1 -Mode Regression` và `Verify-DeployedNds.ps1`.
4. Nhận peer review, merge PR của Hộp; ghi merge commit và chạy lại kiểm tra
   deployment/regression trên revision đã merge. Không thay NDS chỉ để test.
5. Sau các bước trên mới bàn giao NDS READY cho Bảo và bộ evidence cho Hiển.

## Evidence

Xem [mục lục evidence](../evidence/hop_credit_history/README.md). Backup chứa dữ
liệu được giữ ở thư mục local `D:/HomeCreditWork/sql_backups/`, không đưa vào
Git. Bản source không chứa raw CSV, local connection settings hay binary build.
