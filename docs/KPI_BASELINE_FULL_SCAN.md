# Full-data KPI baseline — Home Credit

_Analysis date: 22/10/2026 — complete-file aggregate scan_

---

## 🔍 Scope and provenance

- Scanned all rows of the seven business CSV files: **58.441.149 rows**.
- Current-risk population: 307.511 labeled `application_train` rows.
- History metrics include only rows linked to TRAIN applicants, except unmatched bureau-month rows retained in DDS scope with an unknown applicant.
- Raw CSV files were opened read-only; no raw rows or business identifiers were emitted.
- Missing values were not imputed and financial anomalies were not removed.
- Reproducible output: `data/processed/eda/full_kpi_baseline.json`.
- Command: `python3 scripts/compute_full_kpi_baseline.py --root home-credit-default-risk --output data/processed/eda/full_kpi_baseline.json --analysis-date 2026-10-22`.

## 📊 Executive baseline

| KPI | Full-scan result |
| --- | ---: |
| Total applications | 307.511 |
| Default applications | 24.825 |
| Non-default applications | 282.686 |
| Default rate | **8,0729%** |
| Average credit amount | 599.026,00 |
| Average annuity amount | 27.108,57 |
| Average income amount | 168.797,92 |
| Average credit-to-income | 3,9576 |
| Average annuity-to-income | 0,1809 |
| Average available external score | 0,5093 |

Amounts use the dataset's anonymized monetary scale; the source does not provide a reportable currency label.

## 👥 Descriptive application segments

### Contract type

| Contract | Applications | Defaults | Default rate |
| --- | ---: | ---: | ---: |
| Cash loans | 278.232 | 23.221 | 8,3459% |
| Revolving loans | 29.279 | 1.604 | 5,4783% |

### Age band

| Age band | Applications | Defaults | Default rate |
| --- | ---: | ---: | ---: |
| Under 25 | 12.233 | 1.504 | 12,2946% |
| 25–34 | 72.429 | 7.721 | 10,6601% |
| 35–44 | 84.261 | 7.085 | 8,4084% |
| 45–54 | 70.190 | 4.946 | 7,0466% |
| 55–64 | 60.522 | 3.281 | 5,4212% |
| 65+ | 7.876 | 288 | 3,6567% |

### Income band

| Income band | Applications | Defaults | Default rate |
| --- | ---: | ---: | ---: |
| Under 100k | 63.698 | 5.225 | 8,2028% |
| 100k–149k | 91.591 | 7.894 | 8,6188% |
| 150k–249k | 112.444 | 9.160 | 8,1463% |
| 250k+ | 39.778 | 2.546 | 6,4005% |

### Annuity-to-income affordability band

| Band | Applications | Defaults | Default rate |
| --- | ---: | ---: | ---: |
| Low (≤20%) | 202.441 | 15.806 | 7,8077% |
| Moderate (20–35%) | 88.551 | 7.689 | 8,6831% |
| High (35–50%) | 13.977 | 1.139 | 8,1491% |
| Very high (>50%) | 2.530 | 191 | 7,5494% |
| Unknown | 12 | 0 | 0,0000% |

The rate is not monotonic across affordability bands. This is an exploratory segmentation, not evidence that changing annuity burden causes or prevents default.

## 🗂️ Previous-application baseline

| KPI | Result |
| --- | ---: |
| Source rows scanned | 1.670.214 |
| TRAIN-linked rows | 1.413.701 |
| Approved rows | 886.099 |
| Previous approval rate | **62,6794%** |
| Average requested amount | 175.243,59 |
| Average previous credit amount | 196.354,09 |
| TRAIN-linked negative-amount rows | 2 |
| TRAIN-linked non-positive payment-count rows | 121.985 |

Status distribution: 886.099 Approved, 259.441 Canceled, 245.390 Refused and 22.771 Unused offer.

## 💳 Payment behavior baseline

| KPI | Result |
| --- | ---: |
| Source rows scanned | 13.605.401 |
| TRAIN-linked payment rows | 11.591.592 |
| Recorded payment rows | 11.589.009 |
| Missing payment rows | 2.583 |
| Late payment rows | 993.629 |
| Late payment rate | **8,5739%** |
| Average days late among late rows | **12,5137 days** |
| Total scheduled amount | 196.105.378.746,14 |
| Total paid amount | 197.904.671.164,26 |
| Aggregate paid − scheduled | 1.799.292.418,12 |
| Missing previous-parent rows | 1.019.371 (8,7941%) |

The aggregate payment variance must not be presented as profit or customer overpayment. Payment rows can represent multiple or partial events at a finer grain than one loan.

## 🏦 Bureau baseline

| KPI | Result |
| --- | ---: |
| Bureau credits scanned | 1.716.428 |
| TRAIN-linked bureau credits | 1.465.325 |
| Active bureau credits | 541.919 |
| Active bureau debt | 166.140.712.936,59 |
| Total bureau overdue amount | 58.767.541,51 |
| Credits with overdue indicator | 3.918 |
| Negative-debt rows retained | 8.418 |

Bureau monthly DDS scope contains 17.821.796 rows: 14.701.612 linked to TRAIN bureau credits and 3.120.184 unmatched rows retained under the unknown applicant member.

## 🧩 Extension baseline

| Source | TRAIN-linked rows | Missing parent | Rows with DPD > 0 |
| --- | ---: | ---: | ---: |
| POS/cash monthly | 8.543.375 | 291.621 (3,4134%) | 259.107 (3,0328%) |
| Credit-card monthly | 3.227.965 | 872.972 (27,0440%) | 134.123 (4,1550%) |

Credit-card TRAIN-linked rows have aggregate balance 190.686.609.912,73 and aggregate limit 493.728.786.000,00. Because these are monthly snapshots, totals must not be interpreted as unique-customer exposure or summed across time without a stated period rule.

## 💡 Exploratory findings for dashboard storytelling

1. Younger age bands show higher observed default rates in this dataset, but age is not established as a causal driver.
2. Cash-loan applications have a higher observed default rate than revolving loans; contract mix and applicant composition may confound this comparison.
3. The highest-income band has a lower observed rate than the other income bands, but the relationship is not monotonic across every band.
4. Moderate annuity-to-income has the highest observed rate among the predefined bands; very-high burden does not have the highest rate, warning against simplistic threshold conclusions.
5. About 8,57% of recorded installment payment rows are late; among late rows, mean delay is about 12,51 days.
6. Parent coverage is a material data-quality limitation, especially for credit-card monthly and bureau-month data.

These findings are descriptive associations. They should be accompanied by population counts and should not be used to make individual credit decisions.

## ✅ Validation status

`scripts/validate_kpi_baseline.py` passed all row-count, target-partition, group-total and scope reconciliation invariants. SQL Server and Power BI values must match this baseline under the same population rules before screenshots are accepted as evidence.

The EDA workflow follows raw-data preservation, explicit scope and non-causal interpretation principles described by Kassis et al.[^1]

[^1]: Kassis, T., Agarwal, V., He, Y., Patel, D., & Brueckner, A. M. (2026). “Scientific Agent Skills: A Library of Procedural Knowledge for Research Agents.” _arXiv:2609.00065_. https://doi.org/10.48550/arXiv.2609.00065
