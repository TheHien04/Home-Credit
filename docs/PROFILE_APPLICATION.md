# Application source profile

_Full-file profile và bounded demo sample cho mốc 30/10/2026_

---

## Full sources

| File | Rows | Columns | Key | Target rule |
| --- | ---: | ---: | --- | --- |
| `application_train.csv` | 307.511 | 122 | 0 null, 0 duplicate | 0/1 only |
| `application_test.csv` | 48.744 | 121 | 0 null, 0 duplicate | Column absent |

Full TRAIN có 24.825 default applications và 282.686 non-default applications; default rate là 8,0729%. Đây là local full-file oracle, chưa phải SQL Server runtime result.

## Demo samples

| File | Rows | Columns | Null keys | Duplicate keys | Expected target |
| --- | ---: | ---: | ---: | ---: | --- |
| `application_train.sample_5000.csv` | 5.000 | 122 | 0 | 0 | 4.614 zero, 386 one |
| `application_test.sample_5000.csv` | 5.000 | 121 | 0 | 0 | TARGET absent; SSIS derives null |

Samples are deterministic prefixes created with `scripts/create_bounded_csv_sample.py`. They are ignored by Git and are not substitutes for full-load validation.

## Known quality rules

- Preserve raw values in STG; no imputation or sentinel replacement at ingestion.
- Convert `DAYS_EMPLOYED = 365243` only at NDS and retain a flag.
- Preserve missing annuity/goods price and expose flags downstream.
- Compute KPI only on `DatasetSplit = 'TRAIN'`.
- Treat TEST as unlabeled data and never include it in default numerator or denominator.
