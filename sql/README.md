# SQL workspace

_Deployment order and operational guidance for the Home Credit BI database_

---

**Windows runtime owner:** Nguyen Van Hop (23127192). Nguyen The Hien supports source-logic and KPI-baseline reconciliation.

## 📁 Directory structure

```text
sql/
├── 00_admin/       # Database, schemas, audit, and batch control
├── 01_staging/     # Source-aligned staging tables
├── 02_nds/         # Normalized data store
├── 03_dds/         # Dimensions and facts
├── 04_etl/         # Clean views and load procedures
├── 05_tests/       # Data-quality and reconciliation tests
└── 06_analytics/   # Semantic views and KPI queries
```

## ✅ Engineering conventions

- Make deployment scripts rerunnable or check for existing objects before creation
- Document each table's grain and business key
- Avoid `SELECT *` in production ETL logic
- Protect every division with `NULLIF`
- Validate fact-table uniqueness at the declared grain
- Suffix surrogate keys with `Key` and retain recognizable source business-key names

## 🚀 Deployment order

Run `000_deploy_all.sql` from the `sql/` directory with SQLCMD mode enabled. In SQL Server Management Studio, select **Query > SQLCMD Mode** before running the deployment file.

| Order | Script | Purpose |
| ---: | --- | --- |
| 1 | `00_admin/000_create_database.sql` | Create the `HomeCreditBI` database |
| 2 | `00_admin/001_create_control_layer.sql` | Create schemas and audit/control tables |
| 3 | `00_admin/002_seed_source_files.sql` | Seed the source-file registry |
| 4 | `00_admin/003_create_batch_procedures.sql` | Create batch and file-load lifecycle procedures |
| 5 | `01_staging/010_create_staging_tables.sql` | Create seven source-aligned staging tables |
| 6 | `02_nds/020_create_nds_tables.sql` | Create eight normalized tables and quality flags |
| 7 | `03_dds/030_create_dds_tables.sql` | Create six dimensions and seven facts |
| 8 | `04_etl/040_create_clean_views.sql` | Normalize sentinels, categories, missing values, and anomalies |
| 9 | `04_etl/041_load_nds.sql` | Create the transaction-safe NDS loader |
| 10 | `04_etl/042_load_dds.sql` | Create the full-load DDS procedure and unknown members |
| 11 | `05_tests/050_validate_staging.sql` | Create batch-level staging validation |
| 12 | `05_tests/051_validate_nds.sql` | Reconcile counts, sentinels, flags, and targets |
| 13 | `05_tests/052_validate_dds.sql` | Validate grains, scope, row parity, and KPI invariants |
| 14 | `05_tests/054_validate_kpi_baseline.sql` | Compare DDS values with the independent full-file baseline |
| 15 | `06_analytics/060_create_analytics_views.sql` | Create stable SQL and Power BI semantic views |
| 16 | `06_analytics/061_kpi_reconciliation.sql` | Produce KPI evidence for a selected `BatchID` |
| 17 | `06_analytics/062_data_dictionary_query.sql` | Export the technical dictionary from SQL Server catalogs |
| Verify | `05_tests/053_smoke_test_schema.sql` | Verify required objects and seed data |

Object-creation scripts do not delete source or staging data. `etl.usp_LoadNDS` and `etl.usp_LoadDDS` only replace populated targets when the operator explicitly supplies `@ConfirmReplace = 1`.

## ▶️ Post-staging execution

Run these commands only after the SSIS staging package has completed and returned a valid `BatchID`:

```sql
EXEC ctl.usp_ValidateHomeCreditStaging @BatchID = 1;
EXEC etl.usp_LoadNDS @BatchID = 1, @ConfirmReplace = 0;
EXEC etl.usp_ValidateNDS @BatchID = 1, @PersistResults = 1;
EXEC etl.usp_LoadDDS @BatchID = 1, @ConfirmReplace = 0;
EXEC etl.usp_ValidateDDS @BatchID = 1, @PersistResults = 1;
EXEC etl.usp_ValidateKPIBaseline @BatchID = 1, @PersistResults = 1;
```

If NDS or DDS already contains data and a replacement load has been reviewed, rerun the relevant loader with `@ConfirmReplace = 1`. Never enable replacement before staging validation passes.
