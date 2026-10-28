# Project status — Home Credit BI

_Cập nhật: 29/10/2026 — Nhóm 8_

---

## 📊 Tóm tắt tiến độ

Có hai cách đo để tránh nhầm giữa “đã viết thiết kế/script” và “đã chạy end-to-end”:

| Góc đo | Tiến độ ước tính | Ý nghĩa |
| --- | ---: | --- |
| Artifact thiết kế và mã nguồn | **92%** | Profiling, STG/NDS/DDS, ETL/tests, KPI baseline, chi tiết star schema, Power BI/SSIS specs, application staging package source và CI đã có; report source được phát hành riêng |
| Pipeline SQL/SSIS chạy thực tế | **22%** | Full local analytics đã chạy; SQL Server/SSIS/Power BI chưa chạy end-to-end |
| Local full-data analysis | **100%** | 7 business files, 58.441.149 rows, KPI baseline và invariants đã hoàn tất |

Phần chuẩn bị độc lập của Nguyễn Thế Hiển cho mốc 30/10 đã đạt **100% artifact-ready**: repository inventory, MVP scope, application mapping, focused profile, TRAIN/TEST samples, staging oracle, progress matrix và speaker notes đã có. Trạng thái này không thay thế runtime evidence do các owner Windows thực hiện.

Các tỷ lệ là ước tính quản trị dự án, không phải điểm số môn học.

## ✅ Đã hoàn thành

- Nhận đủ 10 file Home Credit, tổng cộng 58.538.856 data rows
- Kiểm kê encoding, schema, row count và kích thước file
- Full-scan khóa chính, quan hệ `SK_ID_CURR`, parent coverage và các rule chất lượng cốt lõi
- Xác nhận 307.511 train applications, default rate 8,0729%
- Chốt grain cho application, previous, bureau, monthly balances và installments
- Viết control/audit layer và registry nguồn
- Sinh 7 bảng STG, 8 bảng NDS và index cốt lõi
- Viết rule catalog làm sạch, 8 clean views và procedure nạp NDS có transaction
- Viết staging validation và NDS reconciliation tests
- Tạo 6 dimensions, 7 facts, DDS loader và 12 DDS reconciliation tests
- Viết semantic SQL views, KPI reconciliation và canonical DAX measures
- Chạy full-data KPI baseline và xác nhận mọi aggregate invariant đều PASS
- Hoàn thiện bus matrix, ERD star schema có PK/FK, KPI dictionary, source-to-target mapping và 23-case test plan
- Viết SSIS package build specification cho 5 packages và error flow
- Commit Visual Studio/SSIS project source cho application-train staging; chưa có runtime evidence
- Thêm GitHub Actions để compile Python, kiểm tra KPI baseline và validate code-first artifacts trên push/PR
- Đưa aggregate KPI baseline an toàn vào Git; không chứa raw row hoặc dữ liệu định danh
- Viết báo cáo kỹ thuật Chương 1–7, kế hoạch nhóm 4 người và checklist bàn giao
- Chuẩn bị report source riêng; chưa đưa vào code-first release trên GitHub
- Đóng gói validator local cho raw hashes, KPI invariants, SQL structure, tài liệu và 59 object bắt buộc
- Hoàn tất bộ progress-review 30/10: inventory, MVP, application mapping/profile, sample oracle, status matrix và speaker notes

## 🧹 Các lỗi dữ liệu đã xử lý bằng rule

| Vấn đề | Số dòng | Cách xử lý ở NDS |
| --- | ---: | --- |
| `DAYS_EMPLOYED = 365243` | 55.374 | Tenure → null, bật flag |
| Gender `XNA` | 4 | `Unknown`, bật flag |
| Missing application annuity | 12 | Giữ null, bật flag |
| Missing goods price | 278 | Giữ null, bật flag |
| Previous date sentinel | 997.144 | Từng sentinel → null, bật flag |
| Previous payment count ≤ 0 | 144.985 | Giữ giá trị, bật flag |
| Previous negative amount | 2 | Giữ để review, bật flag |
| Bureau debt âm | 8.418 | Giữ để tránh bóp méo dữ liệu, bật flag |
| Installment thiếu ngày/amount payment | 2.905 | Giữ null, `PaymentRecordedFlag = 0` |
| Child row thiếu parent | 3,41–28,20% tùy bảng | Không xóa; bật `ParentMissingFlag` |

## 🗺️ Trạng thái theo phase

| Phase | Trạng thái | % | Còn thiếu để Done |
| --- | --- | ---: | --- |
| 0. Setup & repository | Gần xong | 90% | Cài và chụp bằng chứng SQL Server, VS, SSDT/SSIS trên Windows |
| 1. Intake & profiling | Gần xong | 95% | Chạy duplicate test theo composite grain sau khi load STG |
| 2. Business requirements | Gần xong | 95% | Nhóm/giảng viên xác nhận KPI dictionary |
| 3. STG & NDS | Đã viết, chưa chạy DB | 80% | Load thật, sửa lỗi runtime, ký acceptance tests |
| 4. DDS/star schema | Đã viết, chưa chạy DB | 75% | Compile/load full data và review performance |
| 5. SSIS ETL | Có build spec và application staging source | 45% | Parameterize package, bổ sung TEST/reject flow và các package còn lại; chạy thật trên Windows |
| 6. Testing & reconciliation | Local baseline PASS | 70% | Chạy SQL/Power BI test, lưu evidence và benchmark |
| 7. Power BI | Có model/DAX spec | 30% | Tạo `.pbix`, 5 pages, interactions và visual QA |
| 8. Report/demo | Có draft Chương 1–7 ở workspace riêng | 75% | Phát hành report source, render/QA PDF, điền ảnh runtime, slide và tập demo |

## ⏭️ Việc tiếp theo theo đúng thứ tự

1. **Hiển:** bàn giao `PROGRESS_REVIEW_30OCT.md` và hai application samples cho Duy/Hộp; nhận xác nhận review.
2. **Cả ba bạn Windows:** thống nhất SQL Server/SSIS target version; Duy cài ETL toolchain, Hộp chuẩn bị canonical SQL/SSIS host, Bảo cài Power BI.
3. **Hộp — Windows:** deploy SQL trên canonical host theo `sql/README.md`; smoke test phải tìm đủ 59 objects.
4. **Duy — Windows:** chạy application sample trước; actual counts phải khớp test oracle trong `PROGRESS_REVIEW_30OCT.md`.
5. **Duy — Windows:** tạo một `ctl.ETLBatch`, mở rộng staging package và load cả 7 nguồn nghiệp vụ cùng `BatchID`.
6. **Hộp — Windows:** tích hợp package STG, dựng/chạy NDS và DDS packages; lưu result grids, KPI reconciliation và benchmark.
7. **Bảo — Windows:** tạo `.pbix` theo model/DAX spec, làm 5 pages và đối soát SQL–DAX.
8. **Cả nhóm:** tổng hợp evidence, điền runtime placeholders, hoàn thiện slide và tổ chức demo.

## ⚠️ Chưa thể xác nhận ở máy hiện tại

- SSIS và Visual Studio integration là công cụ Windows; workspace hiện tại là macOS.
- Chưa có SQL Server instance để compile và chạy các script T-SQL trên full data.
- Vì vậy các STG/NDS/DDS scripts đã được review tĩnh nhưng chưa được xác nhận runtime.
- Đã có application staging `.dtsx`; chưa có `.pbix`, ảnh execution evidence hay kết quả performance của full ETL.

## Definition of Done gần nhất

Mốc kế tiếp được xem là hoàn tất khi:

- 7 bảng STG có đúng row count nguồn
- staging validation không có `FAIL`
- NDS load thành công trong một transaction
- 12 NDS tests đều `PASS`
- 12 DDS tests đều `PASS`
- Default count vẫn là 24.825 trên 307.511 train rows
- Sentinel và missing-payment counts khớp full-scan
- Unmatched history rows không bị mất
