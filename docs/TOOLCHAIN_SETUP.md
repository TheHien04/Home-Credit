# Required toolchain setup

_Mage.ai + dbt + SQL Server + Power BI + Generative AI — Group 8_

---

## Target environment

| Component | Required role | Recommended owner |
| --- | --- | --- |
| Docker Desktop | Run Mage OSS and its dbt integration | Duy |
| Mage.ai | Ingest CSV, orchestrate dbt, schedule, retry, log | Duy |
| SQL Server 2022 Developer | Canonical database and audit store | Hộp |
| ODBC Driver 18 | Connect Mage/dbt to SQL Server | Duy and Hộp |
| dbt Core + `dbt-sqlserver` | Transform, test, document, expose lineage | Hộp |
| Power BI Desktop | Semantic model, dashboards, SQL–DAX reconciliation | Bảo |
| Approved LLM API or local model | Grounded KPI explanation | Bảo |

Mage's dbt integration is supported in Docker or Mage Pro, so Docker is part of the required local setup.[^1] The SQL Server adapter is community-maintained and should be validated against the exact dbt/adapter versions before the team freezes the environment.[^2]

## Setup sequence

### 1. Canonical SQL Server

1. Install SQL Server Developer Edition and SSMS on the integration host.
2. Enable TCP/IP and confirm port `1433` is reachable only from the team network.
3. Create a least-privilege SQL login for Mage/dbt; do not use `sa` in shared artifacts.
4. Deploy the existing schemas with `scripts/Deploy-HomeCreditSql.ps1`.
5. Run `sql/05_tests/053_smoke_test_schema.sql` and save the result grid.

### 2. Mage in Docker

1. Install Docker Desktop and verify `docker version` plus `docker compose version`.
2. Start from the official Mage dbt Docker quickstart rather than a bare local Python process.[^1]
3. Add `dbt-sqlserver` through `mage/requirements.txt`.
4. Copy `mage/io_config.yaml.example` into the Mage project and inject credentials through environment variables.
5. Run a Mage SQL block with `SELECT 1` against the canonical SQL Server.

### 3. dbt connection

1. Install ODBC Driver 18 and `dbt-sqlserver` in the Mage image or local virtual environment.
2. Copy `dbt_home_credit/profiles.yml.example` to a secure profiles directory.
3. Set the four `DBT_SQLSERVER_*` variables outside Git.
4. Run `dbt debug`.
5. Run the application MVP with a real Mage `BatchID`.

```bash
dbt build --project-dir dbt_home_credit --profiles-dir /secure/profile/path --vars '{batch_id: 1}'
```

### 4. Power BI and GenAI

1. Connect Power BI to verified dbt marts, not directly to raw CSV files.
2. Import canonical measures from `powerbi/MEASURES_DAX.md` and reconcile them with SQL.
3. Choose the GenAI provider only after confirming class rules and budget.
4. Store the API key in environment variables or a secret store; never in Git, PBIX, screenshots, or Mage exports.
5. Validate every GenAI response against `genai/kpi_insight.schema.json`.

## Version evidence

Capture exact versions in one screenshot or text artifact:

```text
Docker Desktop:
Mage image/tag:
Python:
dbt-core:
dbt-sqlserver:
ODBC Driver:
SQL Server:
Power BI Desktop:
GenAI provider/model:
Git commit:
```

## Security checklist

- [ ] No raw Kaggle files in Git
- [ ] No `io_config.yaml`, `profiles.yml`, `.env`, token, or password in Git
- [ ] SQL login has only the permissions needed by the pipeline
- [ ] GenAI receives aggregate KPI JSON only
- [ ] Screenshots hide server credentials and API keys
- [ ] One canonical `BatchID` appears in Mage, dbt, SQL, and evidence

## Troubleshooting

| Symptom | Check first |
| --- | --- |
| Mage cannot reach SQL Server | TCP/IP, port, firewall, Docker host name, SQL authentication |
| ODBC certificate error | `encrypt` and `trust_cert` settings for the development certificate |
| dbt creates unexpected schemas | Default profile schema plus dbt custom-schema naming |
| dbt test population is zero | Mage `BatchID` was not passed through `--vars` |
| Power BI count is inflated | Relationship direction and joins between one-to-many facts |
| GenAI invents a value | Reject output not traceable to an input `metric_id` |

[^1]: Mage AI. "Use dbt with Mage" and "Make dbt magical." https://docs.mage.ai/guides/dbt/overview and https://docs.mage.ai/guides/dbt/setup-dbt

[^2]: dbt Labs. "Connect Microsoft SQL Server to dbt." https://docs.getdbt.com/docs/local/connect-data-platform/mssql-setup

