# SSIS package build specification

_Dùng tài liệu này để dựng solution trong Visual Studio + Integration Services Projects trên Windows._

**Runtime ownership:** Nguyễn Trường Duy dựng `01_Load_Staging.dtsx`; Nguyễn Văn Hộp duy trì canonical integration solution, nhập package STG rồi dựng `00_Master_Load.dtsx`, `02_Load_NDS.dtsx`, `03_Load_DDS.dtsx` và `04_Reconcile_Load.dtsx`. Rerun và evidence chính thức phải chạy trên canonical host. Nguyễn Quốc Bảo thu thập evidence; Nguyễn Thế Hiển hỗ trợ đối chiếu với baseline đã tạo trên Mac.

## 1. Solution layout

```text
HomeCreditBI.sln
└── HomeCreditBI_ETL.dtproj
    ├── Project.params
    ├── Connection Managers/
    │   ├── CM_HomeCreditBI.conmgr
    │   └── CM_SourceRoot.conmgr
    └── SSIS Packages/
        ├── 00_Master_Load.dtsx
        ├── 01_Load_Staging.dtsx
        ├── 02_Load_NDS.dtsx
        ├── 03_Load_DDS.dtsx
        └── 04_Reconcile_Load.dtsx
```

## 2. Project parameters

| Parameter | Type | Sensitive | Example |
| --- | --- | :---: | --- |
| `pSourceRoot` | String | No | `C:\HomeCredit\data` |
| `pConnectionString` | String | Yes | SQL Server connection string |
| `pFullLoad` | Boolean | No | `True` |
| `pFailOnQualityError` | Boolean | No | `True` |

Package variables:

- `User::BatchID` — Int64
- `User::SourceFileID` — Int32
- `User::RowsRead`, `RowsAccepted`, `RowsRejected` — Int64
- `User::CurrentFilePath` — String

## 3. `00_Master_Load.dtsx`

### Control flow

1. **Execute SQL — Start batch**

```sql
DECLARE @NewBatchID BIGINT;
EXEC ctl.usp_StartETLBatch
    @PipelineName = N'HomeCredit_Full_Load',
    @BatchID = @NewBatchID OUTPUT;
SELECT @NewBatchID AS BatchID;
```

Map single-row result `BatchID` to `User::BatchID`.

2. Execute package `01_Load_Staging.dtsx`.
3. Execute package `02_Load_NDS.dtsx` only on success.
4. Execute package `03_Load_DDS.dtsx` only on success.
5. Execute package `04_Reconcile_Load.dtsx` only on success.
6. **Execute SQL — Finish batch** calls `ctl.usp_EndETLBatch`; it refuses success while a file load or persisted DQ test has failed.
7. Event handler `OnError` updates `BatchStatus='FAILED'`, `EndedAtUtc` and `ErrorMessage`.

Do not run the four largest files in parallel on a laptop. Load sequentially to control memory and transaction-log pressure.

## 4. `01_Load_Staging.dtsx`

Create one Sequence Container per source in this order:

1. application train
2. application test
3. previous application
4. bureau
5. bureau balance
6. installments payments
7. POS cash balance
8. credit-card balance

The two application files share `stg.Application`; add derived `DatasetSplit` as `TRAIN` or `TEST`.

### Standard container pattern

1. Execute SQL: call `ctl.usp_StartFileLoad`, capture `FileLoadID` and `SourceFileID`.
2. Data Flow: Flat File Source → Data Conversion → Derived Columns → OLE DB Destination.
3. Redirect conversion/truncation errors; record row number, column, error code and hashed raw value in `ctl.RejectedRow`.
4. Execute SQL: call `ctl.usp_EndFileLoad`; it enforces `RowsRead = RowsAccepted + RowsRejected`.

### Flat-file settings

- CSV delimiter: comma; text qualifier: `"`; header row present.
- Code page: detect UTF-8 for business files; metadata file is not part of STG load.
- Retain nulls; configure empty unquoted fields as database null after conversion.
- Use `FastLoad`, table lock and batch size around 50,000 rows; tune after measurement.
- Add `BatchID`, one-based `SourceRowNumber` and `LoadedAtUtc` as derived columns.

Do not clean `XNA`, sentinel dates or negative values inside this package. STG must retain source-aligned values.

## 5. `02_Load_NDS.dtsx`

1. Execute SQL:

```sql
EXEC ctl.usp_ValidateHomeCreditStaging @BatchID = ?;
```

2. If any persisted `STG_%` result is `FAIL`, raise an error.
3. Execute SQL:

```sql
EXEC etl.usp_LoadNDS @BatchID = ?, @ConfirmReplace = ?;
```

Map `pFullLoad` to `@ConfirmReplace`; the first empty load may use `0`.

4. Execute SQL:

```sql
EXEC etl.usp_ValidateNDS @BatchID = ?, @PersistResults = 1;
```

The procedure owns the transaction boundary; do not wrap it in a second distributed transaction.

## 6. `03_Load_DDS.dtsx`

Execute sequentially:

```sql
EXEC etl.usp_LoadDDS @BatchID = ?, @ConfirmReplace = ?;
EXEC etl.usp_ValidateDDS @BatchID = ?, @PersistResults = 1;
```

Use `FailPackageOnFailure=True`. DDS is a rebuildable analytical layer; raw/STG/NDS remain available for recovery.

## 7. `04_Reconcile_Load.dtsx`

1. Query `ctl.DataQualityResult` for `FAIL`.
2. Execute `etl.usp_ValidateKPIBaseline @BatchID = ?, @PersistResults = 1`.
3. Run the four KPI views for the active batch.
4. Confirm current-loan count = 307,511 and default count = 24,825.
5. Export result grids or capture screenshots into `ssis/evidence/`.
6. Mark batch `SUCCEEDED` only when no test failed.

## 8. Error handling contract

- Parsing/type/key errors: reject row and increment rejected count.
- Missing source file/header mismatch: fail package immediately.
- Known anomalies handled by NDS flags: warning, not rejection.
- SQL procedure failure: rollback its layer and fail parent package.
- Never log Kaggle API tokens or complete raw rows containing unnecessary data.

## 9. Evidence checklist

- [ ] Screenshot Master control flow
- [ ] Screenshot one staging data flow and red error path
- [ ] Successful package execution tree
- [ ] `ctl.ETLBatch` and `ctl.ETLFileLoad` result grids
- [ ] Staging, NDS and DDS validation result grids
- [ ] KPI reconciliation result grid
- [ ] Runtime and machine specification
