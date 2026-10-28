# Application mapping v0.1

_Mapping khóa cho vertical slice SSIS → `stg.Application`; mapping đầy đủ nằm trong `SOURCE_TO_TARGET_MAPPING.md`_

---

| Source field | STG target | SQL type | Nullable | Rule |
| --- | --- | --- | --- | --- |
| File identity | `DatasetSplit` | `VARCHAR(5)` | No | TRAIN hoặc TEST từ tên file |
| Row ordinal | `SourceRowNumber` | `BIGINT` | No | Bắt đầu từ 1 trong mỗi file |
| Runtime batch | `BatchID` | `BIGINT` | No | Nhận từ `ctl.usp_StartETLBatch` |
| `SK_ID_CURR` | `SK_ID_CURR` | `BIGINT` | Source no | Null/duplicate làm validation fail |
| `TARGET` | `TARGET` | `BIGINT` | Yes | TRAIN 0/1; TEST null |
| `NAME_CONTRACT_TYPE` | same | `NVARCHAR(255)` | Yes | Giữ source tại STG |
| `CODE_GENDER` | same | `NVARCHAR(255)` | Yes | Giữ XNA tại STG; clean ở NDS |
| `FLAG_OWN_CAR` | same | `NVARCHAR(255)` | Yes | Giữ Y/N tại STG |
| `FLAG_OWN_REALTY` | same | `NVARCHAR(255)` | Yes | Giữ Y/N tại STG |
| `CNT_CHILDREN` | same | `BIGINT` | Yes | Không impute |
| `AMT_INCOME_TOTAL` | same | `DECIMAL(28,10)` | Yes | Không đổi null thành 0 |
| `AMT_CREDIT` | same | `DECIMAL(28,10)` | Yes | Không làm tròn tại STG |
| `AMT_ANNUITY` | same | `DECIMAL(28,10)` | Yes | Giữ null |
| `AMT_GOODS_PRICE` | same | `DECIMAL(28,10)` | Yes | Giữ null |
| `NAME_INCOME_TYPE` | same | `NVARCHAR(255)` | Yes | Trim/normalize ở NDS |
| `NAME_EDUCATION_TYPE` | same | `NVARCHAR(255)` | Yes | Trim/normalize ở NDS |
| `NAME_FAMILY_STATUS` | same | `NVARCHAR(255)` | Yes | Trim/normalize ở NDS |
| `NAME_HOUSING_TYPE` | same | `NVARCHAR(255)` | Yes | Trim/normalize ở NDS |
| `DAYS_BIRTH` | same | `BIGINT` | Yes | Age chỉ tính ở NDS |
| `DAYS_EMPLOYED` | same | `BIGINT` | Yes | Sentinel 365243 chỉ xử lý ở NDS |
| `EXT_SOURCE_1` | same | `DECIMAL(28,10)` | Yes | Giữ null |
| `EXT_SOURCE_2` | same | `DECIMAL(28,10)` | Yes | Giữ null |
| `EXT_SOURCE_3` | same | `DECIMAL(28,10)` | Yes | Giữ null |

## Header contract

- TRAIN có 122 cột và chứa `TARGET`.
- TEST có 121 cột và không chứa `TARGET`.
- SSIS phải thêm `TARGET = NULL` cho TEST trước khi ghi chung vào `stg.Application`.
- Không map theo vị trí sau cột `SK_ID_CURR`; Flat File Connection Manager phải được kiểm tra lại khi header thay đổi.
