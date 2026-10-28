# MVP for 30 October progress review

_Vertical slice có thể chứng minh trong thời gian ngắn mà không làm sai phạm vi dữ liệu_

---

## Mục tiêu

Chứng minh luồng `application CSV → SSIS → SQL Server STG → validation → KPI query`, đồng thời trình bày rõ phần nào đã triển khai, đã xác minh hoặc còn bị chặn.

## Phạm vi bắt buộc

| Thành phần | Nội dung |
| --- | --- |
| Sources | `application_train.csv`, `application_test.csv` |
| Sample demo | 5.000 TRAIN + 5.000 TEST rows |
| Full oracle | 307.511 TRAIN + 48.744 TEST rows |
| Destination | `stg.Application` |
| Lineage | `BatchID`, `SourceRowNumber`, `LoadedAtUtc`, `DatasetSplit` |
| Validation | Row count, null/duplicate key, TARGET domain, split rules |
| KPI reference | TRAIN applications, defaults, default rate |

## Không thuộc MVP 30/10

- Full seven-source SSIS load
- Complete NDS/DDS history facts
- Final five-page Power BI dashboard
- Performance benchmark và incremental load

Các phần trên vẫn thuộc final project nhưng không được trình bày là đã chạy trong progress review.

## Demo flow

1. Mở SSIS solution và chỉ ra Control Flow/Data Flow.
2. Tạo một `BatchID` trong SQL Server.
3. Nạp hai sample files vào `stg.Application`.
4. Chạy `sql/05_tests/055_validate_application_sample.sql` với đúng sample `BatchID`.
5. So sánh result grid với `STG_TEST_ORACLE.md`.
6. Trình bày architecture, mapping, full-data KPI oracle và các blocker còn lại.

## Definition of Done

- SSIS execution hoàn tất hoặc có blocker/log cụ thể.
- Expected sample counts bằng actual SQL counts.
- Không có null/duplicate `SK_ID_CURR`.
- TRAIN chỉ chứa TARGET 0/1; TEST có TARGET null.
- Slide phân biệt rõ `LOCAL VERIFIED`, `RUNTIME VERIFIED`, `BLOCKED` và `PLANNED`.
