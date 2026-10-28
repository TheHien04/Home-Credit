# Staging test oracle

_Expected values for SSIS application sample and full-load reconciliation_

---

## Sample manifest

| Local file | SHA-256 | Expected rows |
| --- | --- | ---: |
| `data/staging/application_train.sample_5000.csv` | `16df53567a56f5f58d12ad58f98cce09c5041b768493abedf855000f5a518424` | 5.000 |
| `data/staging/application_test.sample_5000.csv` | `8d185745ca98229301199b1614a6d71c3620bd4ceaf7101ab09b7d90314dab7b` | 5.000 |

## Expected sample results

| Check | Expected |
| --- | ---: |
| Total rows | 10.000 |
| TRAIN rows | 5.000 |
| TEST rows | 5.000 |
| TRAIN TARGET = 0 | 4.614 |
| TRAIN TARGET = 1 | 386 |
| TRAIN default rate | 7,72% |
| Null `SK_ID_CURR` | 0 |
| Duplicate `SK_ID_CURR` | 0 |
| Invalid TRAIN target | 0 |
| Non-null TEST target | 0 |

## Expected full-load results

| Check | Expected |
| --- | ---: |
| Total application rows | 356.255 |
| TRAIN rows | 307.511 |
| TEST rows | 48.744 |
| TRAIN TARGET = 0 | 282.686 |
| TRAIN TARGET = 1 | 24.825 |
| TRAIN default rate | 8,0729% |
| Null application keys | 0 |
| Duplicate application keys | 0 |

## Evidence rule

Expected values are written before the SSIS run. Actual values must come from SQL result grids using the same `BatchID`; they must never be copied from this oracle and relabeled as runtime output.

Chạy `sql/05_tests/055_validate_application_sample.sql` cho sample batch. Full load tiếp tục dùng `050_validate_staging.sql` và các validators NDS/DDS/KPI hiện có.
