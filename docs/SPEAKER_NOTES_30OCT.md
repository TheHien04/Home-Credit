# Speaker notes — 30 October progress review

_Nguyễn Thế Hiển · target duration 2–3 minutes_

---

## Script

**Opening — 20 seconds**

Nhóm 8 xây dựng hệ thống BI phân tích danh mục cho vay và rủi ro tín dụng từ Home Credit Default Risk. Đây là data warehouse project, không phải mô hình tự động quyết định cho vay.

**Data and business scope — 35 seconds**

Dữ liệu có 10 file và nhiều grain: application, previous application, bureau credit, payment row và monthly snapshot. Full local scan đã kiểm tra 58.441.149 business rows. Population có nhãn gồm 307.511 applications với 24.825 defaults, tương ứng 8,0729%.

**Architecture — 35 seconds**

Luồng mục tiêu là CSV nguồn qua SSIS vào SQL Server STG, sau đó chuẩn hóa NDS, xây DDS star schema và phục vụ Power BI. STG giữ dữ liệu gần nguồn; NDS xử lý sentinel/category có quality flag; DDS giữ grain riêng cho current application và từng history process để tránh nhân bản KPI.

**Current progress — 40 seconds**

Nhóm đã hoàn thành profiling, cleaning contract, source-to-target mapping, DDL STG/NDS/DDS, SQL loaders, validators, KPI oracle, Power BI specification và SSIS build specification. Các kết quả local đã PASS; SQL Server, SSIS và Power BI runtime vẫn phải được xác nhận trên canonical Windows host.

**Demo and honesty boundary — 25 seconds**

MVP 30/10 ưu tiên application TRAIN/TEST. Nhóm có sample 5.000 dòng mỗi split và expected-count oracle. Nếu package chưa chạy thành công, nhóm sẽ trình bày blocker và log, không dùng expected values hoặc mockup làm actual runtime evidence.

**Next step — 20 seconds**

Tiếp theo nhóm chạy full SSIS load, đối soát STG–NDS–DDS–KPI bằng cùng BatchID, hoàn thiện Power BI, kiểm thử rerun và chèn toàn bộ evidence vào báo cáo.

## Expected questions

| Question | Short answer |
| --- | --- |
| Vì sao dùng SSIS? | Đây là công cụ ETL giảng viên đã xác nhận; phù hợp SQL Server, audit, error path và package orchestration. |
| STG khác NDS thế nào? | STG giữ source-aligned values; NDS chuẩn hóa deterministic và giữ lineage/quality flags. |
| Grain application là gì? | Một dòng trên một `SK_ID_CURR`; TRAIN có target, TEST không có target. |
| Vì sao TEST không tính default rate? | TEST không có nhãn TARGET nên không thuộc numerator hoặc denominator. |
| Vì sao không join tất cả bảng trước? | History là one-to-many; join sớm sẽ nhân bản application và làm sai KPI. |
| Số 8,0729% đã là SQL result chưa? | Chưa; đó là local full-file oracle dùng để đối soát SQL và Power BI runtime. |

## After the presentation

Ghi lại câu hỏi, yêu cầu thay đổi, người phụ trách và deadline. Chỉ cập nhật gate `PASS` khi artifact/evidence đã được reviewer xác nhận.
