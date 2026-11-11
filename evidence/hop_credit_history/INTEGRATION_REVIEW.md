# Integration review — Hộp, 11 November 2026

Reviewed source: `fd46cf8` on `main`, including merged PR #2
(`53b1c98`, Duy Application). This is a local review record; no review was
submitted on another member's behalf.

## Application findings that block NDS integration

1. **No SQL destination in the committed Application data flow.**
   `ssis/TEAM/Duy_Application/01_Load_Application.dtsx` contains a Flat File
   Source, Script Component, Data Conversion and Derived Column. The final
   Derived Column output has no downstream path and there is no OLE DB
   Destination component. Consequently this revision cannot populate
   `stg.Application`. Add the destination and confirm complete field/lineage
   mapping before treating the package as a loader.
2. **The package starts a separate batch.** `SQL_Start_ETL_Batch` invokes
   `ctl.usp_StartETLBatch` with pipeline `HomeCredit_Application_Train`.
   Integration requires accepting the explicit shared batch and validating
   that it is RUNNING. Starting another batch separates Application from
   Credit/Payment History and prevents the NDS gate from passing. The metadata
   Derived Column currently creates only `DatasetSplit`; map the accepted
   `BatchID` into every destination row as well.
3. **TEST and per-file audit are absent from this revision.** Only the TRAIN
   data flow is present; there are no calls to `usp_StartFileLoad` or
   `usp_EndFileLoad`. Add TEST with `TARGET=NULL` and separate TRAIN/TEST audits.
   Acceptance is 307,511 TRAIN and 48,744 TEST rows, two successful file audits,
   zero rejects and no duplicate application keys under the same batch.
4. **The project targets SQL Server 2025 and fixed local paths.** Its
   `TargetServerVersion` is `SQLServer2025`; the integration engine and Hộp
   packages use SQL Server 2022. Review the supported target together and
   parameterize the file root and server. A successful run on another member's
   machine does not prove that this source revision works on the integration
   host.

The procedure `ctl.usp_StartETLBatch` itself returns a single-row result set;
its existing result binding is therefore not reported as a defect here.

## Payment/DDS review

The repository and GitHub PR search on 11 November contain only Duy's two
merged PRs. No Payment/DDS project or PR was available for Bảo. Review is
pending its source and execution evidence. Hộp's work does not modify the
other members' SSIS project files or implement DDS.

## NDS deployment and regression

`nds_deployed_source_comparison.json` compares the deployed definitions of
eight clean views and the NDS load/validation procedures against repository
source. All ten match. The comparison is a deployment check, not runtime
acceptance of NDS data.

`Verify-NDS.ps1 -Mode Readiness` checks exact full source counts and the latest
file audit for each of eight input files, including separate Application
splits. `-Mode Regression` additionally requires all eight NDS populations at
their full expected counts before running the twelve NDS checks with
`@PersistResults=0`. Missing or empty populations return INCOMPLETE and cannot
be certified by zero-equals-zero tests. Both modes leave warehouse data and
the shared batch unchanged.

The current SQL Server 2022 Express engine has a 10 GB relational database
limit. Reassess capacity before combining full STG, NDS and DDS on this host;
the repository baseline specifies Developer Edition. See
[Microsoft's SQL Server 2022 edition limits](https://learn.microsoft.com/en-us/sql/sql-server/editions-and-components-of-sql-server-2022/).

## Remaining day-4 acceptance

- Receive complete Application/Payment inputs and their audits on the shared
  host/batch, then pass staging validation.
- Execute NDS with `@ConfirmReplace=0`, persist twelve passing checks and save
  actual counts. Run read-only regression after integration; do not replace
  NDS merely to demonstrate a rerun.
- Have another team member review the Credit History PR. Record the merge
  commit and verify deployment and regression from that revision.
- Hand off NDS READY, batch ID, counts, logs and SQL changes to Bảo/Hiển only
  after runtime acceptance. Until then report the dependency as incomplete.
