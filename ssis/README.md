# SSIS workspace

_Package design cho luồng STG → NDS → DDS_

---

## 📦 Package inventory

| Package | Input | Output | Logging |
| --- | --- | --- | --- |
| `Master_Load.dtsx` | Parameters | Child packages | Batch status |
| `Load_Staging.dtsx` | Kaggle CSV | STG tables | Read/accepted/rejected |
| `Load_NDS.dtsx` | STG | NDS | Insert/update/error |
| `Load_DDS.dtsx` | NDS | DDS dimensions + facts | Rows/unknown/orphan |
| `Reconcile_Load.dtsx` | Audit + targets | Test results | Pass/fail |

## ⚙️ Parameters

- `SourceRoot`
- `ConnectionString`
- `BatchID`
- `FullLoadFlag`
- `FailOnQualityError`

## ✅ Evidence cần lưu

- Control Flow và Data Flow screenshots
- Execution result của từng package
- Audit table trước và sau lần chạy
- Ví dụ rejected row và lý do
- Reconciliation query và kết quả

Chi tiết triển khai: [Package build specification](PACKAGE_BUILD_SPEC.md).
