# Test plan — Home Credit BI

_Cập nhật: 29/10/2026 — test chạy local và test chờ Windows được tách riêng_

---

## 🧪 Test catalog

| ID | Layer | Test | Expected result | Automation |
| --- | --- | --- | --- | --- |
| TC-001 | Raw | 10 CSV hashes match manifest | All `OK` | `shasum -c` |
| TC-002 | STG | Application business key duplicate | 0 | `STG_APP_DUPLICATE_KEY` |
| TC-003 | STG | Invalid train/test target combination | 0 | `STG_APP_INVALID_CORE` |
| TC-004 | STG | Mandatory keys/grain missing | 0 | DDS/NDS loader guards |
| TC-005 | STG | Unmatched previous parent | WARN, never silent delete | `STG_*_UNMATCHED` |
| TC-006 | NDS | Application row parity | PASS | `NDS_APP_ROW_PARITY` |
| TC-007 | NDS | Employment sentinel normalized | 55.374 and PASS | `CLEAN_EMPLOYMENT_SENTINEL` |
| TC-008 | NDS | Previous-date sentinel normalized | 997.144 and PASS | `CLEAN_PREVIOUS_DATE_SENTINEL` |
| TC-009 | NDS | Missing payment flagged | 2.905 and PASS | `CLEAN_MISSING_PAYMENT` |
| TC-010 | NDS | Negative bureau debt retained/flagged | 8.418 and PASS | `CLEAN_NEGATIVE_BUREAU_DEBT` |
| TC-011 | NDS | Default numerator unchanged | 24.825 | `TARGET_DEFAULT_COUNT` |
| TC-012 | DDS | One fact per labeled train application | 307.511 | `DDS_LOAN_ROW_PARITY` |
| TC-013 | DDS | Default numerator unchanged | 24.825 | `DDS_DEFAULT_COUNT_PARITY` |
| TC-014 | DDS | History facts limited to train applicants | PASS | DDS parity tests |
| TC-015 | DDS | Ratio denominator protection | 0 invalid ratios | `DDS_RATIO_DENOMINATOR_GUARD` |
| TC-016 | DDS | Late-payment flag follows signed delay | PASS | `DDS_LATE_PAYMENT_FLAG_PARITY` |
| TC-017 | DDS | Exactly one unknown applicant | 1 | `DDS_UNKNOWN_APPLICANT_SINGLETON` |
| TC-018 | KPI | Default rate SQL | 8,0729% | `etl.usp_ValidateKPIBaseline` |
| TC-019 | Power BI | DAX matches SQL under same filters | Difference = 0 | Manual evidence |
| TC-020 | Rerun | Same source does not duplicate data | Counts unchanged | Run full load twice |
| TC-021 | Local KPI | Full-scan aggregate invariants | PASS | `validate_kpi_baseline.py` |
| TC-022 | Deploy | Required SQL objects exist | 59 objects | `053_smoke_test_schema.sql` |
| TC-023 | Repository | Code-first validation on every push/PR | PASS | GitHub Actions `validate.yml` |
| TC-024 | Demo sample | TRAIN sample checksum/count/domain | 5.000 rows; 386 defaults; no invalid key/target | Local validator + `055_validate_application_sample.sql` |
| TC-025 | Demo sample | TEST sample checksum/count/domain | 5.000 rows; TARGET absent at source | Local validator + `055_validate_application_sample.sql` |

## ✅ Kết quả local đã xác nhận

| Test | Trạng thái | Bằng chứng |
| --- | --- | --- |
| TC-001 raw SHA-256 | PASS | `docs/RAW_DATA_SHA256.txt` đối chiếu đủ 10 file |
| Full DQ profiling | PASS | 58.441.149 dòng nghiệp vụ đã quét toàn bộ |
| TC-021 KPI invariants | PASS | 7 source sections và mọi population partition khớp |
| Python syntax | PASS | Toàn bộ script compile thành công |
| SQL static structure | PASS | Batch boundary và dấu ngoặc cân bằng |
| Documentation links | PASS | Không có internal link bị thiếu |
| TC-023 code-first CI | PASS locally | Python compile, KPI invariants và artifact checks không cần raw CSV |
| TC-024/025 application samples | PASS local | Hai sample 5.000 rows khớp SHA-256 và oracle trong `PROGRESS_REVIEW_30OCT.md` |

Các test cần SQL Server, SSIS hoặc Power BI vẫn ở trạng thái `PENDING`; không được suy ra `PASS` từ kiểm tra tĩnh.

## ▶️ Execution order

1. Verify raw manifest.
2. Load STG and run `ctl.usp_ValidateHomeCreditStaging`.
3. Load NDS and run `etl.usp_ValidateNDS`.
4. Load DDS and run `etl.usp_ValidateDDS`.
5. Run `061_kpi_reconciliation.sql`.
6. Refresh Power BI and compare every card with SQL.
7. Repeat the full load once with replace enabled to demonstrate rerun safety.

## 📁 Evidence naming

```text
TC-001_raw_hashes.png
TC-006_nds_row_parity.png
TC-012_dds_loan_parity.png
TC-018_sql_default_rate.png
TC-019_powerbi_default_rate.png
TC-020_rerun_counts.png
```

Do not mark runtime-dependent cases Pass until the result grid or screenshot exists.
