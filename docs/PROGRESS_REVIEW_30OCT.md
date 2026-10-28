# Progress review and handoff — 30 October 2026

_Group 8 · Home Credit Risk & Loan Portfolio Analytics_

---

## 1. Purpose and status boundary

This document consolidates the progress-review scope, Nguyễn Thế Hiển's handoff, application profiling, SSIS mapping, test oracle, current status and presentation notes. It is the single reference for the 30 October review.

The target vertical slice is:

`application CSV → SSIS → SQL Server STG → validation → KPI query`

Statuses are evidence-based:

- **LOCAL VERIFIED:** reproduced from the local source files.
- **IMPLEMENTED:** source or specification exists but has not necessarily run on Windows.
- **RUNTIME VERIFIED:** supported by execution output from the canonical Windows host.
- **BLOCKED/PLANNED:** not yet supported by runtime evidence.

Expected values and mockups must never be presented as runtime results.

## 2. Nguyễn Thế Hiển handoff

Hiển's independently executable preparation for the 30 October review is complete.

| Deliverable | Evidence | Status |
| --- | --- | --- |
| Raw intake and integrity | `DATA_DOWNLOAD_AND_INTAKE.md`, `RAW_DATA_SHA256.txt` | LOCAL VERIFIED |
| Full profiling and DQ | `DATA_PROFILE_REPORT.md`, `DATA_CLEANING_RULES.md` | LOCAL VERIFIED |
| Data model and mapping | `DATA_DICTIONARY.md`, `DDS_MODEL.md`, `SOURCE_TO_TARGET_MAPPING.md` | IMPLEMENTED |
| KPI definitions and oracle | `KPI_DICTIONARY.md`, `KPI_BASELINE_FULL_SCAN.md` | LOCAL VERIFIED |
| SQL source and validators | `sql/`, including `055_validate_application_sample.sql` | IMPLEMENTED; static checks PASS |
| Application demo samples | Two deterministic local CSV samples and checksums below | LOCAL VERIFIED |
| Progress presentation | Scope, status matrix, script and Q&A in this document | COMPLETE |
| Repository quality | English README, artifact validator and GitHub Actions | VERIFIED |

The remaining SQL Server, SSIS and Power BI runtime work requires the group's Windows environment and is not an unfinished Mac deliverable of Hiển.

## 3. Repository inventory

| Area | Evidence | Remaining runtime work |
| --- | --- | --- |
| Repository and CI | `README.md`, `.github/workflows/validate.yml` | Keep status current |
| SQL warehouse | `sql/00_admin` through `sql/06_analytics` | Deploy on canonical host |
| SSIS | `ssis/PACKAGE_BUILD_SPEC.md`, `ssis/HomeCredit_BI/HomeCredit_ETL/` | Parameterize, build, run and extend to five packages |
| Power BI | `powerbi/MODEL_SPEC.md`, `powerbi/MEASURES_DAX.md` | Build/refresh PBIX and reconcile DAX |
| Report | Local `latex/report` and `latex/team-plan` | Insert runtime evidence and render final PDF |
| Runtime evidence | Not yet versioned | Capture one canonical commit and `BatchID` |

SSIS is the official ETL/orchestration tool, SQL Server is the canonical STG/NDS/DDS store, and Power BI reads only validated DDS or analytics views.

## 4. MVP scope

| Component | Scope |
| --- | --- |
| Sources | `application_train.csv`, `application_test.csv` |
| Demo samples | 5,000 TRAIN and 5,000 TEST rows |
| Full oracle | 307,511 TRAIN and 48,744 TEST rows |
| Destination | `stg.Application` |
| Lineage | `BatchID`, `SourceRowNumber`, `LoadedAtUtc`, `DatasetSplit` |
| Validation | Row count, null/duplicate key, TARGET domain and split rules |
| KPI reference | TRAIN applications, defaults and default rate |

Full seven-source loading, all history facts, five final Power BI pages, performance benchmarking and incremental loading remain final-project work rather than 30 October MVP claims.

### Demo sequence

1. Open the SSIS solution and identify Control Flow and Data Flow.
2. Parameterize the CSV root and SQL Server connection.
3. Create one `BatchID` and load both sample splits into `stg.Application`.
4. Run `sql/05_tests/055_validate_application_sample.sql` with that `BatchID`.
5. Compare the result grid with the expected values in Section 7.
6. Present architecture, mapping, local KPI oracle and remaining blockers.

## 5. Application source profile

### Full sources

| File | Rows | Columns | Key quality | Target rule |
| --- | ---: | ---: | --- | --- |
| `application_train.csv` | 307,511 | 122 | 0 null, 0 duplicate | 0/1 only |
| `application_test.csv` | 48,744 | 121 | 0 null, 0 duplicate | Column absent |

Full TRAIN contains 282,686 non-default and 24,825 default applications, producing a local oracle default rate of 8.0729%. This is not yet a SQL Server runtime result.

### Deterministic samples

| Local file | Rows | Columns | SHA-256 |
| --- | ---: | ---: | --- |
| `data/staging/application_train.sample_5000.csv` | 5,000 | 122 | `16df53567a56f5f58d12ad58f98cce09c5041b768493abedf855000f5a518424` |
| `data/staging/application_test.sample_5000.csv` | 5,000 | 121 | `8d185745ca98229301199b1614a6d71c3620bd4ceaf7101ab09b7d90314dab7b` |

Both samples have zero null and duplicate application keys. TRAIN contains 4,614 target-zero and 386 target-one rows. Samples are ignored by Git and must be transferred privately to the Windows integration host.

## 6. Application-to-STG mapping

The full cross-layer mapping remains in `SOURCE_TO_TARGET_MAPPING.md`. The fields below are the critical contract for the SSIS application slice.

| Source | STG target | SQL type | Rule |
| --- | --- | --- | --- |
| File identity | `DatasetSplit` | `VARCHAR(5)` | Derive `TRAIN` or `TEST` from controlled file parameter |
| Row ordinal | `SourceRowNumber` | `BIGINT` | Start at 1 per source file |
| Runtime batch | `BatchID` | `BIGINT` | Receive from `ctl.usp_StartETLBatch` |
| `SK_ID_CURR` | same | `BIGINT` | Null or duplicate fails validation |
| `TARGET` | same | `BIGINT NULL` | TRAIN 0/1; derive null for TEST |
| `NAME_CONTRACT_TYPE` | same | `NVARCHAR(255)` | Preserve source at STG |
| `CODE_GENDER` | same | `NVARCHAR(255)` | Preserve XNA at STG; normalize at NDS |
| `FLAG_OWN_CAR` | same | `NVARCHAR(255)` | Preserve Y/N |
| `FLAG_OWN_REALTY` | same | `NVARCHAR(255)` | Preserve Y/N |
| `CNT_CHILDREN` | same | `BIGINT` | Do not impute |
| `AMT_INCOME_TOTAL` | same | `DECIMAL(28,10)` | Do not replace null with zero |
| `AMT_CREDIT` | same | `DECIMAL(28,10)` | Do not round at STG |
| `AMT_ANNUITY` | same | `DECIMAL(28,10)` | Preserve null |
| `AMT_GOODS_PRICE` | same | `DECIMAL(28,10)` | Preserve null |
| `NAME_INCOME_TYPE` | same | `NVARCHAR(255)` | Trim/normalize at NDS |
| `NAME_EDUCATION_TYPE` | same | `NVARCHAR(255)` | Trim/normalize at NDS |
| `NAME_FAMILY_STATUS` | same | `NVARCHAR(255)` | Trim/normalize at NDS |
| `NAME_HOUSING_TYPE` | same | `NVARCHAR(255)` | Trim/normalize at NDS |
| `DAYS_BIRTH` | same | `BIGINT` | Derive age at NDS |
| `DAYS_EMPLOYED` | same | `BIGINT` | Handle sentinel 365243 at NDS with flag |
| `EXT_SOURCE_1` | same | `DECIMAL(28,10)` | Preserve null |
| `EXT_SOURCE_2` | same | `DECIMAL(28,10)` | Preserve null |
| `EXT_SOURCE_3` | same | `DECIMAL(28,10)` | Preserve null |

TRAIN has 122 columns including `TARGET`; TEST has 121 columns without it. The TEST flow must derive `TARGET = NULL`. SSIS metadata must be validated by header name rather than assuming positional equivalence after `SK_ID_CURR`.

## 7. Staging test oracle

### Sample batch

| Check | Expected |
| --- | ---: |
| Total rows | 10,000 |
| TRAIN rows | 5,000 |
| TEST rows | 5,000 |
| TRAIN TARGET = 0 | 4,614 |
| TRAIN TARGET = 1 | 386 |
| TRAIN default rate | 7.72% |
| Null `SK_ID_CURR` | 0 |
| Duplicate `SK_ID_CURR` | 0 |
| Invalid TRAIN target | 0 |
| Non-null TEST target | 0 |

### Full application load

| Check | Expected |
| --- | ---: |
| Total rows | 356,255 |
| TRAIN rows | 307,511 |
| TEST rows | 48,744 |
| TRAIN TARGET = 0 | 282,686 |
| TRAIN TARGET = 1 | 24,825 |
| TRAIN default rate | 8.0729% |
| Null application keys | 0 |
| Duplicate application keys | 0 |

Expected values were written before SSIS execution. Actual values must come from SQL result grids under the same `BatchID`. Use `055_validate_application_sample.sql` for the sample and `050_validate_staging.sql` for the full staging load.

## 8. Progress status

| Workstream | Implemented | Verified | Status |
| --- | --- | --- | --- |
| Raw intake | Manifest and intake rules | SHA-256 and full row inventory | LOCAL VERIFIED |
| Profiling and DQ | Profilers, rules and reports | 58,441,149 business rows | LOCAL VERIFIED |
| KPI oracle | Application/history baselines | All local invariants PASS | LOCAL VERIFIED |
| SQL warehouse | 59 required objects scripted | Static checks PASS | IMPLEMENTED; runtime pending |
| SSIS | Build specification and application-train project source | Source inspected | PARTIAL; runtime pending |
| Power BI | Model and DAX specifications | No PBIX evidence | PLANNED |
| Report | Chapters and appendices drafted locally | Static convention checks PASS | IN PROGRESS |

### Required next actions

1. Duy reviews and parameterizes the committed application staging package, adds TEST and reject handling, and runs the sample.
2. Hộp deploys SQL on the canonical host, records the commit/`BatchID`, and executes STG/NDS/DDS/KPI validators.
3. Duy and Hộp extend the solution to the remaining sources and prove rerun behavior.
4. Bảo builds five Power BI pages only after DDS validation and completes SQL–DAX reconciliation.
5. The group captures performance, screenshots, report evidence and final rehearsal notes.

## 9. Speaker notes for Nguyễn Thế Hiển

### Two-to-three-minute script

**Opening.** Nhóm 8 xây dựng hệ thống BI phân tích danh mục cho vay và rủi ro tín dụng từ Home Credit Default Risk. Đây là data warehouse project, không phải mô hình tự động quyết định cho vay.

**Data and scope.** Dữ liệu có 10 file với nhiều grain như application, previous application, bureau credit, payment và monthly snapshot. Full local scan đã kiểm tra 58.441.149 business rows. Population có nhãn gồm 307.511 applications với 24.825 defaults, tương ứng 8,0729%.

**Architecture.** Luồng mục tiêu là CSV qua SSIS vào SQL Server STG, sau đó chuẩn hóa NDS, xây DDS star schema và phục vụ Power BI. STG giữ dữ liệu gần nguồn; NDS xử lý sentinel/category có quality flag; DDS giữ grain riêng để không nhân bản KPI.

**Current progress.** Nhóm đã hoàn thành profiling, cleaning contract, mapping, DDL STG/NDS/DDS, SQL loaders, validators, KPI oracle, Power BI specification và SSIS design. Application staging source đã có; runtime vẫn phải được xác nhận trên canonical Windows host.

**Demo boundary.** MVP ưu tiên application TRAIN/TEST với sample 5.000 dòng mỗi split và expected-count oracle. Nếu package chưa chạy thành công, nhóm trình bày blocker và log, không dùng expected value làm actual evidence.

**Next step.** Nhóm sẽ chạy full SSIS load, đối soát STG–NDS–DDS–KPI theo cùng `BatchID`, hoàn thiện Power BI, kiểm thử rerun và chèn evidence vào báo cáo.

### Likely questions

| Question | Answer |
| --- | --- |
| Why SSIS? | It is the confirmed course ETL tool and integrates with SQL Server audit, error paths and orchestration. |
| STG versus NDS? | STG preserves source-aligned values; NDS performs deterministic normalization with lineage and quality flags. |
| Application grain? | One row per `SK_ID_CURR`; TRAIN is labeled and TEST is unlabeled. |
| Why exclude TEST from default rate? | TEST has no `TARGET`, so it belongs to neither numerator nor denominator. |
| Why not join all sources first? | One-to-many histories would duplicate applications and distort KPIs. |
| Is 8.0729% already a SQL result? | No. It is the local full-file oracle for later SQL and Power BI reconciliation. |

After the review, record questions, requested changes, owner and deadline. Update a runtime gate to PASS only after reviewer-checked evidence exists.
