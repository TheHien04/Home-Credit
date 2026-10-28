# Home Credit dbt project

_MVP transformation project for SQL Server; application scope first, history tables next_

---

## Purpose

This project moves deterministic cleaning, feature derivation, dimensional materialization, and tests into dbt. Mage supplies the `batch_id` and runs `dbt build`; SQL Server remains the storage and execution engine.

The first vertical slice covers `stg.Application` and produces `dbt_dds.FactLoanApplicationMVP`. It is intentionally bounded so the team can prove the required toolchain before migrating all seven business sources.

## Run

1. Copy `profiles.yml.example` to a secure profiles directory as `profiles.yml`.
2. Set `DBT_SQLSERVER_HOST`, `DBT_SQLSERVER_DATABASE`, `DBT_SQLSERVER_USER`, and `DBT_SQLSERVER_PASSWORD` outside Git.
3. Confirm the selected `BatchID` exists in `stg.Application`.
4. Run:

```bash
dbt debug --project-dir dbt_home_credit --profiles-dir /secure/profile/path
dbt build --project-dir dbt_home_credit --profiles-dir /secure/profile/path --vars '{batch_id: 1}'
```

`batch_id: 0` is deliberately non-operational. A real batch must be supplied by the Mage pipeline so a rerun cannot silently mix ingestion batches.

## Acceptance

- `dbt debug` connects to the canonical SQL Server
- all source, generic, and singular tests pass
- `FactLoanApplicationMVP` contains 307,511 rows and 24,825 defaults for the complete TRAIN batch
- generated dbt documentation shows `source → staging → intermediate → mart` lineage
- credentials, `target/`, `logs/`, and `dbt_packages/` are not committed

