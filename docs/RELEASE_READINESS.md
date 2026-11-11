# Release readiness — 12 November 2026

This is the final pre-submission gate for the code-first repository. It distinguishes
source deliverables that can be prepared on macOS from runtime deliverables that must
come from the canonical Windows environment.

## Current decision

**Status: NOT SUBMISSION-READY.** The repository is source-ready and locally validated,
but the final package cannot be called complete until Windows runtime evidence and the
binary submission files exist.

No expected value, mock screenshot, or source file is presented as runtime evidence.

## Deliverable matrix

| Deliverable | Current state | Owner/action needed |
| --- | --- | --- |
| Technical report | Source ready at `latex/report/main.tex`; draft/runtime warning intentionally retained | Compile to final PDF/DOCX after W02–W08 evidence; current Word handoff is draft-only |
| Team plan | Source ready at `latex/team-plan/main.tex` | Confirm contribution percentages and final date |
| Presentation | Source ready at `latex/slides/main.tex` | Compile to PPTX/PDF and add verified screenshots |
| SQL warehouse | 59 objects and validators are implemented; local static validation PASS | Run W02–W05 on Windows |
| SSIS | Build specification and partial projects exist | Complete five packages and run W03/W07 |
| Power BI | Model and DAX specifications exist | Build PBIX, refresh, compare SQL/DAX, capture W06 |
| Runtime evidence | Evidence directories are empty or contain no canonical final packet | Capture W01–W07 |
| Final package | Not present in repository | Assemble only after cross-review |

## Source review completed on macOS

- Mapping, dictionary, DQ rules, KPI definitions, DDS model, and test plan are linked
  from the report and handoff.
- Local KPI values are sourced from
  `data/processed/eda/full_kpi_baseline.json`.
- The report and slides label local values as an oracle and keep runtime placeholders.
- The expected-vs-actual register is in `docs/HIEN_FINAL_HANDOFF.md`.
- The source and SQL artifact validator passes before every push.

## Runtime closure checklist

| Gate | Required proof | Status |
| --- | --- | --- |
| W01A–W01C | Tool versions and connections | PENDING |
| W02 | 59-object SQL smoke test | PENDING |
| W03 | Seven STG counts, eight file audits, reject result | PENDING |
| W04 | NDS/DDS validators and shared `BatchID` | PENDING |
| W05 | KPI result grid matching the local oracle | PENDING |
| W06 | Five Power BI pages and SQL–DAX comparisons | PENDING |
| W07 | Rerun before/after counts with no duplicates | PENDING |
| W08 | PDF/DOCX, PPTX, PBIX, SSIS, SQL, evidence and cross-review | PENDING |

## Binary build instructions

The current macOS environment has no XeLaTeX, PDFLaTeX, PowerPoint, or LibreOffice
compiler available. On a Windows machine, Overleaf, or a prepared TeX environment:

1. Compile `latex/report/main.tex` twice with XeLaTeX.
2. Compile `latex/team-plan/main.tex` twice with XeLaTeX.
3. Compile `latex/slides/main.tex` with XeLaTeX.
4. Convert the Beamer PDF to PPTX only if the resulting layout is reviewed; otherwise
   use PowerPoint to reproduce the slides from the source and insert the real evidence.
5. Open every output and check page breaks, table overflow, Vietnamese fonts, names,
   class, lecturer, date, and evidence labels.

Do not commit generated `.aux`, `.log`, `.toc`, PDF, PPTX, PBIX, credentials, or raw
CSV files unless the submission policy explicitly requires them in a separate package.

## Information that requires team confirmation

The repository currently records class `23HTTT2`, lecturers `Hồ Thị Hoàng Vy` and
`Tiết Gia Hồng`, Group 8, and four student names/IDs. Confirm these against the
official course brief before exporting the final report and slides. The submission
date is intentionally not guessed in source files.
