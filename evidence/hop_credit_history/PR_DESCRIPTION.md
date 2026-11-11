Adds Hộp's three Credit History SSIS loaders and guarded NDS orchestration for
the 09–12 November schedule. The loaders accept an explicit shared BatchID,
retain row lineage, audit accepted/rejected rows and refuse duplicate loads.
Includes build/configuration helpers, read-only NDS verification, deployment
comparison, runtime evidence and handoff/review notes.

Verified on SQL Server 2022 / Visual Studio SSIS debugger, integration batch 4:

- `previous_application.csv`: 1,670,214 rows; FileLoadID 11.
- `bureau.csv`: 1,716,428 rows; FileLoadID 10.
- `bureau_balance.csv`: 27,299,925 rows; FileLoadID 9.
- All three full reconciliations PASS: exact counts, unique ordinals,
  mandatory keys, zero rejects and all fields reconciled on 1,000 sampled
  records per source.
- Duplicate-load guard PASS with unchanged data/audit counts; four package
  metadata validations PASS.
- Schema smoke PASS (59 objects / 10 sources), backup CHECKSUM + VERIFYONLY
  PASS; ten deployed NDS modules match source.
- Clean schema deployment and idempotent redeployment PASS on a separate
  empty database, using the fifteen original SQL includes unchanged and only
  replacing the bootstrap database name; both smoke tests find 59 objects,
  ten sources and five seeded bands. This is not full-data NDS regression.
- Four preparation tests, KPI baseline and project artifact validator PASS.

The only shared SQL change makes the smoke test's catalog comparisons use
`DATABASE_DEFAULT` collation.

This PR remains **DRAFT**: Application and Payment History are missing on the
integration host/batch. The NDS package correctly refuses incomplete input.
NDS load, twelve passing tests, integration regression, peer review and merge
remain outstanding. Review SQL Server Express capacity before full
STG/NDS/DDS integration. Other members' SSIS projects are unchanged.

Run instructions: `ssis/TEAM/hop_credit_history/README.md`.
Handoff: `docs/HOP_DAY4_HANDOFF.md`.
Evidence: `evidence/hop_credit_history/full_batch_4_reconciliation.json`.
Review: `evidence/hop_credit_history/INTEGRATION_REVIEW.md`.
