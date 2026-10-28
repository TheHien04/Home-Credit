# Progress status — 29 October 2026

_Evidence-based status for the 30/10 progress presentation_

---

## Status matrix

| Workstream | Planned | Implemented | Verified | Status |
| --- | --- | --- | --- | --- |
| Raw intake | 10 source files | Manifest and intake rules | SHA-256/full row inventory | PASS local |
| Profiling and DQ | Full business scan | Python profilers and reports | 58.441.149 business rows | PASS local |
| KPI oracle | Application/history KPIs | Versioned baseline | All local invariants PASS | PASS local |
| SQL warehouse | Control/STG/NDS/DDS | 59 required SQL objects scripted | Static checks PASS | READY, runtime pending |
| SSIS | Five-package ETL | Build specification and application-train staging `.dtproj/.dtsx` committed | Source inspected; no Windows execution evidence | PARTIAL, runtime pending |
| Power BI | Five pages | Model and DAX specifications | No PBIX evidence | PLANNED |
| Report | Chapters and appendices | LaTeX source updated | Static convention checks PASS | DOING |

## What can be claimed

- Dataset profiling, data-quality rules and KPI oracle are verified locally.
- SQL DDL, loaders and validators are implemented as source code and pass static checks.
- Application demo samples, mapping and expected-count oracle are ready.

## What cannot be claimed yet

- SSIS package execution, SQL Server row counts, NDS/DDS tests and performance are not runtime verified.
- Power BI visuals and SQL–DAX reconciliation are not verified.
- Mockups or expected values must not be presented as actual output.

## Known issues and dependencies

1. Canonical Windows host must install compatible SQL Server, Visual Studio, SSDT/SSIS and Power BI versions.
2. Duy must review, parameterize and run the committed SSIS staging package before Hộp can execute NDS/DDS reconciliation.
3. Bảo must wait for verified DDS before final KPI reconciliation in Power BI.
4. All runtime evidence must share one canonical `BatchID` and Git commit.

## Next period: 31/10–07/11

1. Run application sample, then full seven-source SSIS load.
2. Execute STG/NDS/DDS/KPI validators and fix all blocking failures.
3. Complete Power BI pages and SQL–DAX matrix.
4. Measure runtime, rows per second, transaction-log growth and rerun behavior.
5. Insert evidence into report, render PDF, build slides and rehearse demo.
