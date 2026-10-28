# Submission checklist — Home Credit BI

_Nhóm 8 · required stack · cập nhật ngày 29/10/2026_

---

## ✅ Code-first artifacts đã có

- [x] Raw-data manifest, profiling, DQ rules, and KPI oracle
- [x] SQL Server control/STG/NDS/DDS schemas and validators
- [x] Mage pipeline specification and MSSQL configuration template
- [x] dbt application MVP with source, staging, intermediate, mart, and tests
- [x] Power BI model and canonical DAX specifications
- [x] Grounded GenAI contract and JSON output schema
- [x] GitHub Actions and local artifact validator

Run before every push:

```bash
python3 scripts/validate_kpi_baseline.py
python3 scripts/validate_project_artifacts.py --skip-raw
```

## 🚦 Runtime gates

| Gate | Owner | Acceptance | Evidence |
| --- | --- | --- | --- |
| R01 Toolchain | Duy/Hộp | Docker, Mage, dbt, ODBC, SQL Server versions recorded | Version output/screenshots |
| R02 SQL deploy | Hộp | Schema smoke test finds all required objects | Result grid |
| R03 Mage ingestion | Duy | TRAIN/TEST loaded with one `BatchID`; rejects auditable | Mage graph, logs, row counts |
| R04 dbt build | Hộp | All models and tests pass; lineage generated | dbt summary and docs screenshot |
| R05 KPI | Hộp/Hiển | Population, defaults, and rate match local oracle | SQL/dbt results |
| R06 Power BI | Bảo | SQL equals DAX under shared filters | PBIX and reconciliation matrix |
| R07 GenAI | Bảo/Hiển | Output validates against schema and cites supplied metrics | Input/output JSON and demo |
| R08 Rerun | Duy/Hộp | No duplicate keys or count drift | Two run IDs and before/after queries |
| R09 Final | Cả nhóm | Report, code, PBIX, evidence, video, and citations reviewed | Signed checklist |

## 📁 Evidence structure

```text
evidence/
├── 01_tool_versions/
├── 02_sql_deploy/
├── 03_mage_ingestion/
├── 04_dbt_build_tests/
├── 05_kpi_reconciliation/
├── 06_powerbi/
├── 07_genai/
├── 08_rerun_performance/
└── 09_final_demo/
```

Every evidence artifact should include the Git commit and `BatchID` where applicable. Screenshots must not expose passwords, connection strings, API keys, or Kaggle tokens.

## 📦 Final package

- [ ] Final report in DOCX/PDF
- [ ] Presentation slides
- [ ] Mage project or exported pipeline source
- [ ] `dbt_home_credit/` with models, tests, and generated documentation evidence
- [ ] SQL deployment and validation scripts
- [ ] Power BI `.pbix`
- [ ] GenAI source, prompt contract, schema, and safe sample output
- [ ] Runtime evidence and rerun/performance log
- [ ] Demo video or live-demo runbook
- [ ] README with exact setup and ownership
- [ ] No raw data, secrets, or machine-specific credentials

## 🔍 Cross-review

| Owner | Reviewer | Scope |
| --- | --- | --- |
| Nguyễn Thế Hiển | Nguyễn Quốc Bảo | Data quality, KPI oracle, report accuracy |
| Nguyễn Trường Duy | Nguyễn Văn Hộp | Mage ingestion, audit, failures, rerun |
| Nguyễn Văn Hộp | Nguyễn Trường Duy | dbt/SQL models, tests, lineage, performance |
| Nguyễn Quốc Bảo | Nguyễn Thế Hiển | Power BI filters, GenAI grounding, demo |

No runtime gate is marked `PASS` from source code alone.
