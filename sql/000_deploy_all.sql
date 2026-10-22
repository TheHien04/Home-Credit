/*
SQLCMD-mode deployment entry point.
Run from the sql directory so relative :r paths resolve correctly.
This creates/updates objects only and does not load source data.
*/

:on error exit

:r 00_admin/000_create_database.sql
:r 00_admin/001_create_control_layer.sql
:r 00_admin/002_seed_source_files.sql
:r 00_admin/003_create_batch_procedures.sql
:r 01_staging/010_create_staging_tables.sql
:r 02_nds/020_create_nds_tables.sql
:r 03_dds/030_create_dds_tables.sql
:r 04_etl/040_create_clean_views.sql
:r 04_etl/041_load_nds.sql
:r 04_etl/042_load_dds.sql
:r 05_tests/050_validate_staging.sql
:r 05_tests/051_validate_nds.sql
:r 05_tests/052_validate_dds.sql
:r 05_tests/054_validate_kpi_baseline.sql
:r 06_analytics/060_create_analytics_views.sql
:r 05_tests/053_smoke_test_schema.sql
