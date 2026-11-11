# Hiển — final handoff and evidence gate

_Owner: Nguyễn Thế Hiển · Scope: data modeling, independent DQ, metadata/audit specification, final evidence review_

This document is the single execution handoff for Hiển's four timeline assignments. Existing domain documents remain the source of truth for detailed definitions; this file records what is complete, what still needs a real Windows run, and the exact evidence required to close each gate.

## Status at repository commit

| Assignment | Repository implementation | Runtime closure |
| --- | --- | --- |
| Mapping, data model, progress control | Complete: mapping, dictionary, DDS model, checklist, status review | Needs team acknowledgement |
| Independent profiling and test oracle | Complete locally: full scan, hashes, KPI baseline, bounded sample oracle | Needs actual-vs-expected result from the canonical batch |
| Metadata/audit specification and independent acceptance | SQL procedures, control tables, DQ tests, and rules are implemented | Needs `ETLBatch`, `ETLFileLoad`, and `DataQualityResult` output from a real batch |
| Final report, slides, and evidence acceptance | Structure and acceptance criteria exist | Not closable until runtime evidence and final files exist |

`IMPLEMENTED` is not `RUNTIME VERIFIED`. Do not replace a pending status with `PASS` based on a package file, static SQL review, or a local Python scan.

## Existing evidence that can be cited now

- [Data profile](DATA_PROFILE_REPORT.md): full source profiling and quality findings.
- [Cleaning rules](DATA_CLEANING_RULES.md): deterministic NDS treatment and flags.
- [KPI baseline](KPI_BASELINE_FULL_SCAN.md): local reconciliation oracle.
- [Source-to-target mapping](SOURCE_TO_TARGET_MAPPING.md): source, STG, NDS, and DDS contract.
- [DDS model](DDS_MODEL.md): dimensions, facts, grains, and relationships.
- [Test plan](TEST_PLAN.md): runtime test catalog.
- [Project status](PROJECT_STATUS.md): current boundary between implemented and verified.

## Required Windows evidence packet

The Windows owner must provide one packet for one canonical `BatchID`. Store small screenshots/logs under `evidence/` or the relevant existing `ssis/evidence/` and `powerbi/evidence/` folder. Do not commit raw data, credentials, or database backups.

| Evidence ID | Required output | Acceptance rule |
| --- | --- | --- |
| HN-01 | SQL deploy smoke-test result | 59 required objects and five schemas exist |
| HN-02 | `ctl.ETLBatch` row | One shared `BatchID`, correct status and timestamps |
| HN-03 | `ctl.ETLFileLoad` table | All eight ETL source files have terminal status; `RowsRead = RowsAccepted + RowsRejected` |
| HN-04 | STG expected-vs-actual table | Each of seven STG tables matches the source count supplied by Hiển |
| HN-05 | `ctl.DataQualityResult` output | No unexpected `FAIL`; `WARN` rows are explained and retained |
| HN-06 | NDS and DDS validation results | All required NDS/DDS tests pass for the same `BatchID` |
| HN-07 | KPI reconciliation result | SQL values equal the documented baseline within the documented population |
| HN-08 | Power BI comparison | Each required page/card matches SQL under the same filters |
| HN-09 | Rerun comparison | Second execution does not silently duplicate rows |

## SQL evidence queries

Run these after the ETL owner supplies the canonical `BatchID`; replace `@BatchID` only with that value.

```sql
DECLARE @BatchID BIGINT = 0; -- replace; do not use MAX(BatchID)

SELECT BatchID, PipelineName, BatchStatus, StartedAtUtc, EndedAtUtc,
       RowsRead, RowsAccepted, RowsRejected, ErrorMessage
FROM ctl.ETLBatch
WHERE BatchID = @BatchID;

SELECT f.FileLoadID, sf.FileName, f.LoadStatus, f.StartedAtUtc, f.EndedAtUtc,
       f.RowsRead, f.RowsAccepted, f.RowsRejected,
       CASE WHEN f.RowsRead = f.RowsAccepted + f.RowsRejected
            THEN 'PASS' ELSE 'FAIL' END AS RowArithmetic
FROM ctl.ETLFileLoad AS f
JOIN ctl.SourceFile AS sf ON sf.SourceFileID = f.SourceFileID
WHERE f.BatchID = @BatchID
ORDER BY sf.FileName;

SELECT TestCode, ObjectName, ExpectedValue, ActualValue, TestStatus
FROM ctl.DataQualityResult
WHERE BatchID = @BatchID
ORDER BY TestStatus, TestCode;
```

The first query proves batch identity, the second proves per-file audit completeness, and the third proves persisted DQ outcomes. A screenshot must show the `BatchID`, query name or test code, expected value, actual value, and status.

## Expected-vs-actual register

Complete this register from the SQL result grid. Never fill the Actual column from the local oracle.

| Source/STG object | Expected rows | Actual rows | Difference | Status | Evidence |
| --- | ---: | ---: | ---: | --- | --- |
| `application_train.csv` / `stg.Application` TRAIN | 307511 |  |  | PENDING | HN-04 |
| `application_test.csv` / `stg.Application` TEST | 48744 |  |  | PENDING | HN-04 |
| `previous_application.csv` / `stg.PreviousApplication` | 1670214 |  |  | PENDING | HN-04 |
| `bureau.csv` / `stg.BureauCredit` | 1716428 |  |  | PENDING | HN-04 |
| `bureau_balance.csv` / `stg.BureauBalance` | 27299925 |  |  | PENDING | HN-04 |
| `installments_payments.csv` / `stg.InstallmentPayment` | 13605401 |  |  | PENDING | HN-04 |
| `POS_CASH_balance.csv` / `stg.POSCashBalance` | 10001358 |  |  | PENDING | HN-04 |
| `credit_card_balance.csv` / `stg.CreditCardBalance` | 3840312 |  |  | PENDING | HN-04 |

The eight rows above are the ETL scope in the timeline. The repository also tracks `HomeCredit_columns_description.csv`, `application_test.csv`, and `sample_submission.csv` as intake files; they are not additional business STG loads.

## Final report and slide closure

Hiển can assemble the narrative and review once HN-01 through HN-09 are supplied. The final package must label every claim as one of:

- `LOCAL VERIFIED`: independently reproduced from local source files.
- `IMPLEMENTED`: source/specification exists.
- `RUNTIME VERIFIED`: supported by the canonical Windows evidence packet.
- `BLOCKED/PLANNED`: not yet supported by runtime evidence.

Until the packet exists, the final report and slides must not present expected counts, mock screenshots, or local KPI values as SQL Server/Power BI execution results.

## Mac-ready deliverables

The following source files are now ready for the team to compile and review:

- [Technical report source](../latex/report/main.tex): Chapters 1--7, local baseline, architecture, ETL, dashboard specification, testing, ownership, and reproducibility.
- [Team plan source](../latex/team-plan/main.tex): ownership, dependencies, gates, and review responsibilities.
- [Slide source](../latex/slides/main.tex): a 10-slide presentation covering problem, architecture, quality, KPI, Hiển's contribution, audit contract, dashboard, evidence gates, and conclusion.

Before delivery, replace only verified placeholders and keep the status labels. Do not remove the draft/runtime warning until the Windows evidence packet is reviewed.
