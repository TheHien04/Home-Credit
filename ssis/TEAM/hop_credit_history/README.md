# Hộp — Credit History staging and NDS

Scope follows the **09–12 November 2026 schedule**: Hộp owns the three Credit
History CSV loaders and NDS. Duy owns Application, Bảo owns Payment History and
DDS. The October specification elsewhere in the repository has older ownership.

## Packages

| Package | Source / action | Target |
| --- | --- | --- |
| `01_Load_PreviousApplication.dtsx` | `previous_application.csv` | `stg.PreviousApplication` |
| `02_Load_BureauCredit.dtsx` | `bureau.csv` | `stg.BureauCredit` |
| `03_Load_BureauBalance.dtsx` | `bureau_balance.csv` | `stg.BureauBalance` |
| `04_Load_Validate_NDS.dtsx` | Validate STG → load NDS without replacement → validate NDS | Eight NDS tables |

Open `Hop_CreditHistory/Hop_CreditHistory.slnx` for the portable source project.
Target: **SQL Server 2022**. Server instance, `BatchID`, and prepared-file root
are variables. The package defaults cannot start a real load (`BatchID=0`).
There is no fixed computer name, password, or `MAX(BatchID)` lookup.

## CSV contract

`prepare_source.py` keeps the original CSV files untouched. Its ignored output
adds one-based **CSV record** numbers and formats numbers for the deployed STG
types. Integer casts use exact decimal arithmetic; `DECIMAL(28,10)` uses SQL-style
half-away-from-zero rounding. Empty values stay empty and become SQL NULL.
Sentinels such as `365243`, `XNA`, negative amounts, and unmatched keys are not
cleaned here. Those rules belong to NDS.

The helper checks the complete ordered header against the staging DDL, handles
quoted commas and newlines with the CSV parser, and fails on malformed records,
fractional integer values, non-finite numbers, or overflow. Each prepared file
has a manifest declaring its measured row count and **sample/full** scope.

SSIS data flow: typed Flat File Source → parsed-row count → source columns plus
`BatchID` and UTC load timestamp → OLE DB Fast Load. Conversion failures follow
the red path to `ctl.RejectedRow` with source file, record ordinal, and error
metadata. Original values remain recoverable in the unchanged raw source.

## Build and configure on Windows

Run from the repository root in PowerShell. Use the actual SSMS server name:

```powershell
$server = Read-Host 'SQL Server instance'
$source = (Resolve-Path './home-credit-default-risk').Path
$work = Join-Path (Get-Location) 'data/staging/hop_credit_history'
$tools = './ssis/team/hop_credit_history'

& "$tools/Build-Packages.ps1" -ServerInstance $server -SourceRoot $source -WorkRoot $work
```

Requirements: Python 3, SQL Server 2022 client/object-model assemblies, Visual
Studio with Microsoft SSIS Projects and the SQL Server 2022 target, and the
Microsoft OLE DB Driver for SQL Server. The builder discovers Visual Studio
with `vswhere` and uses its installed SSIS manifest; it changes no registration
or machine settings. Generated executables, local settings, and build outputs
are ignored by Git.

### Shared batch

Hộp creates the integration batch **once** and shares the returned number with
Duy and Bảo. If the team already created one, use that existing explicit ID.
Keep sample batches separate from the integration batch.

```powershell
& "$tools/Start-SharedBatch.ps1" -ServerInstance $server `
  -PipelineName 'HomeCredit_Team_FULL' `
  -EvidencePath (Join-Path $work 'shared_batch.local.json')

$batch = (Get-Content (Join-Path $work 'shared_batch.local.json') -Raw | ConvertFrom-Json).batch_id
```

The helper refuses to overwrite an existing batch-evidence file. It never
automatically closes the shared batch after Hộp's three files.

### Run with the Visual Studio debugger

```powershell
& "$tools/Configure-Designer.ps1" -ServerInstance $server -BatchID $batch `
  -SourceRoot $source -WorkRoot $work -RowLimit 0
```

`RowLimit=0` means **full**. To test first, use `RowLimit=1000` and a separate
pipeline name and batch-evidence file containing `SAMPLE`.

Open the returned `Hop_CreditHistory.local.slnx`. It retains the SSIS project
type and target. Its `.local.dtsx` and `.local.dtproj` files carry this machine's
paths and explicit batch ID and are ignored by Git. In Solution Explorer,
right-click the intended `.local.dtsx` and choose **Execute Package**, one
source package at a time. F5 executes the project's configured startup package,
which may differ from the active editor tab. Do not run NDS until
Application and Payment History are also complete for the same integration ID.

The installed client/Express tools may build packages but reject execution
outside SSDT with `C000F427`. In that environment use Visual Studio's SSIS
debugger. `Run-CreditHistory.ps1` is an alternative only on a host with the
full supported Integration Services runtime installed.

## Audit and acceptance

Each file starts its own `ctl.usp_StartFileLoad` under the supplied shared batch.
Success requires parsed rows = committed rows + rejected rows **and zero
rejects**. Failed data flows finish their file audit through an explicit failure
constraint after pipeline counters settle. Rejected rows or SQL failures make
the package fail. A failed partial load remains available for investigation;
the loader will refuse to append to the same table/batch and create duplicates.
Do not delete partial records or force a replacement to bypass this guard.

Full-file reconciliation targets from the existing independent profile:

| File | Expected rows |
| --- | ---: |
| `previous_application.csv` | 1,670,214 |
| `bureau.csv` | 1,716,428 |
| `bureau_balance.csv` | 27,299,925 |

For each file retain its preparation manifest, actual `COUNT_BIG(*)` filtered
by `BatchID`, unique/min/max source ordinals, audit row, execution duration,
and SSIS result. An estimate in `sys.partitions` does not replace final counts.

NDS acceptance requires all seven STG tables, staging validation without FAIL,
eight successful source-file audits, and all NDS tests passing. The NDS package
checks the seven input tables and eight audits before invoking validators or
load procedures. It always uses `@ConfirmReplace=0` and
does not execute DDS or close the shared batch.

After the three source packages finish, verify and save aggregate evidence:

```powershell
& "$tools/Verify-CreditHistory.ps1" -ServerInstance $server -BatchID $batch `
  -WorkRoot $work -EvidenceDirectory './evidence/hop_credit_history' -RequireFull
```

This checks exact full counts, unique record ordinals, required keys, audit
counts and statuses, rejects, and every source field on a bounded 1,000-record
SQL read. It exports aggregate JSON and CSV without source records.

The current SQL Server instance is Express. Check capacity before integrating
all STG, NDS, and DDS layers; the source project's Windows setup checklist
specifies a Developer integration host.

## NDS readiness and day-4 regression

Capture the complete integration input contract before running NDS:

```powershell
& "$tools/Verify-NDS.ps1" -ServerInstance $server -BatchID $batch `
  -EvidenceDirectory './evidence/hop_credit_history' -Mode Readiness
```

This read-only command requires exact full counts and the latest successful
audit for all eight CSV inputs. It saves the missing inputs as `INCOMPLETE`
and returns a nonzero exit code when the integration is not ready. A readiness
PASS still requires the staging-quality gate inside the NDS package. It does
not itself run the load or certify NDS.

After NDS has completed and persisted its twelve passing checks, capture
regression and source/deployment parity:

```powershell
& "$tools/Verify-NDS.ps1" -ServerInstance $server -BatchID $batch `
  -EvidenceDirectory './evidence/hop_credit_history' -Mode Regression
& "$tools/Verify-DeployedNds.ps1" -ServerInstance $server `
  -EvidenceDirectory './evidence/hop_credit_history'
```

Regression first requires all eight full NDS populations, then calls
`etl.usp_ValidateNDS` with `@PersistResults=0`. It never replaces data and does
not accept empty-equals-empty validation as completion. Deployment parity
compares the eight clean views and two NDS procedures with repository SQL;
it does not deploy or alter anything. See the
[integration review](../../../evidence/hop_credit_history/INTEGRATION_REVIEW.md)
for the Application/Payment prerequisites and review findings.

## Local checks

```powershell
python -m unittest discover -s ssis/team/hop_credit_history -p test_prepare_source.py -v
python scripts/validate_kpi_baseline.py
python scripts/validate_project_artifacts.py --skip-raw
```

These checks do not certify full SSIS execution. See saved runtime evidence for
the executed batch and distinguish diagnostic/sample attempts from full loads.
