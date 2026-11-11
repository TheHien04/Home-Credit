# Kết quả thực thi phần Hộp

Ngày chạy: 11/11/2026. Phạm vi theo lịch 09–12/11: ba nguồn Credit History,
audit từng file và package điều phối NDS.

## Batch và trạng thái

- Batch tích hợp: **4**, pipeline `HomeCredit_Team_FULL_20261111`.
- Batch 4 đang `RUNNING`; chưa kết thúc batch chung khi thiếu phần của Duy/Bảo.
- Ba package mẫu đã chạy thành công với 1.000 dòng/file; đối chiếu tất cả các
  trường của 1.000 dòng/file không có sai lệch.
- **Full load cả ba nguồn đã PASS đối soát:** `previous_application` 1.670.214,
  `bureau` 1.716.428, `bureau_balance` 27.299.925 dòng; tổng 30.686.567 dòng.
- Mỗi nguồn có ordinal duy nhất, 0 missing key, 0 reject; mọi trường trên mẫu
  1.000 dòng/nguồn khớp SQL. FileLoadID lần lượt 11, 10 và 9.
- Ngày 1 và 2 đã đủ bằng chứng kiểm tra hiện tại. Ngày 3–4 **chưa hoàn thành**:
  Application/Payment History chưa có trên database này, NDS chưa được nạp,
  chưa có peer review/merge và regression sau tích hợp.

## Bằng chứng

- `raw_integrity.json`: SHA256 của ba CSV gốc khớp manifest của repo.
- `sample_batch_3_reconciliation.json` và `.csv`: số dòng, audit, ordinal,
  trường dữ liệu và số reject của mẫu.
- `sample_*_pass.png`: ảnh kết quả thực thi thật trong Visual Studio.
- `nds_dependency_gate.txt`: package NDS từ chối batch chưa đủ đầu vào bằng
  lỗi 51408 trước khi chạy validator hoặc load NDS.
- `full_batch_4_reconciliation.json` và `.csv`: kết quả đối soát full cả ba
  nguồn; 3/3 PASS.
- `full_*_debugger.txt`, `full_*_pass.png`: log và ảnh thực thi full được lưu;
  `full_*.manifest.json` chỉ là manifest chuẩn bị nguồn, không thay runtime.
- `schema_smoke.txt`, `backup_verify.txt`: 59 required objects PASS và backup
  COPY_ONLY/CHECKSUM được RESTORE VERIFYONLY xác nhận hợp lệ.
- `validate_0*.txt`: cả bốn portable packages qua SSIS metadata validation.
- `rerun_guard_bureau.json` và `.txt`: chạy lại package bị chặn trước Data
  Flow; counts và audit không đổi, không chứng nhận NDS rerun.
- `nds_deployed_source_comparison.json`: 10/10 NDS modules khớp source SQL.
- `nds_readiness_batch_4.json`, `nds_regression_batch_4.json`: đầu vào còn
  thiếu được ghi rõ INCOMPLETE; không chạy validator trên NDS rỗng để lấy PASS.
- `python_prepare_tests.txt`, `kpi_baseline_validation.txt`,
  `project_artifact_validation.txt`: kiểm tra local PASS.
- [Review tích hợp](INTEGRATION_REVIEW.md) và
  [bàn giao ngày 4](../../docs/HOP_DAY4_HANDOFF.md): thay đổi SQL, findings và
  điều kiện còn thiếu để nghiệm thu NDS.

Batch mẫu 1–3 có các lần chẩn đoán thất bại được giữ nguyên trong audit;
batch 3 được đóng `FAILED` do có một lần lỗi trước khi sửa xong loader.
Ba lần chạy mẫu cuối cùng của batch 3 đều `SUCCEEDED` (FileLoadID 6–8).
Không sử dụng các batch mẫu này để tích hợp.

## Điều kiện để chạy NDS

1. Duy nạp `application_train.csv` và `application_test.csv`; Bảo nạp
   `POS_CASH_balance.csv`, `installments_payments.csv`, `credit_card_balance.csv`
   vào cùng batch tích hợp trên cùng database.
2. Kiểm tra đủ bảy bảng STG, tám file audit `SUCCEEDED`, không reject và
   validator staging không có FAIL.
3. Hộp chạy `04_Load_Validate_NDS.local.dtsx`. Package dùng `@ConfirmReplace=0`
   và kiểm tra kết quả NDS sau khi load.
4. Bảo tiếp tục DDS; chỉ kết thúc batch khi cả nhóm hoàn thành đối chiếu.

BatchID 4 chỉ có ý nghĩa trên database đã tạo batch này. Khi dùng host tích hợp
khác, tạo một batch chung ở host đó và cấu hình cả ba project bằng ID mới.

Host hiện tại là SQL Server Express. Kiểm tra dung lượng trước khi tích hợp
đầy đủ STG/NDS/DDS; checklist của repo yêu cầu host SQL Server Developer.

Mã nguồn và hướng dẫn chạy: [README của project Hộp](../../ssis/TEAM/hop_credit_history/README.md).
