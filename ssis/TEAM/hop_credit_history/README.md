# Hộp — SSIS Credit History: CSV → Stage

Project này chỉ gồm ba loader CSV → Stage. Package NDS 04 không được khai báo
trong project này. Các package đã được thiết kế sẵn, mở và chạy trực tiếp trong
Visual Studio; chỉ cần Python helper để chuẩn bị CSV.

## Bộ source

```text
hop_credit_history/
├── .gitignore
├── README.md
├── Hop_CreditHistory/
│   ├── Hop_CreditHistory.slnx
│   └── Hop_CreditHistory/
│       ├── Hop_CreditHistory.dtproj
│       ├── Hop_CreditHistory.database
│       ├── Project.params
│       ├── 01_Load_PreviousApplication.dtsx
│       ├── 02_Load_BureauCredit.dtsx
│       └── 03_Load_BureauBalance.dtsx
└── scripts/
    └── prepare_source.py
```

| Package | CSV nguồn | Bảng đích |
| --- | --- | --- |
| `01_Load_PreviousApplication.dtsx` | `previous_application.csv` | `stg.PreviousApplication` |
| `02_Load_BureauCredit.dtsx` | `bureau.csv` | `stg.BureauCredit` |
| `03_Load_BureauBalance.dtsx` | `bureau_balance.csv` | `stg.BureauBalance` |

## Điều kiện chạy

- Windows, Visual Studio hỗ trợ `.slnx`, extension Microsoft SSIS Projects với
  target SQL Server 2022 và Microsoft OLE DB Driver for SQL Server.
- Python 3 để chạy `scripts/prepare_source.py`.
- Database `HomeCreditBI` đã triển khai SQL dùng chung của repository, gồm ba
  bảng STG ở trên, `ctl.SourceFile`, `ctl.ETLBatch`, `ctl.ETLFileLoad`,
  `ctl.RejectedRow`, `ctl.usp_StartFileLoad` và `ctl.usp_EndFileLoad`.
  Ba tên CSV phải có trong danh mục nguồn đang active.
- File `sql/01_staging/010_create_staging_tables.sql` phải có trong checkout:
  helper đọc file này để kiểm tra header và kiểu dữ liệu.

Các lệnh PowerShell bên dưới chạy từ thư mục gốc repository. Build project
bằng Visual Studio; không cần script build hoặc C# helper riêng.

## 1. Xác nhận BatchID

Nếu team đã có batch tích hợp, dùng đúng BatchID đó trên cùng SQL Server.
Batch phải đang `RUNNING`. Nếu cần tạo batch mới, chạy trong SSMS:

```sql
USE HomeCreditBI;
GO
DECLARE @BatchID BIGINT;
EXEC ctl.usp_StartETLBatch
    @PipelineName = N'HomeCredit_Team_FULL',
    @BatchID = @BatchID OUTPUT;
SELECT @BatchID AS BatchID;
```

Chỉ tạo batch chung một lần rồi chia sẻ ID cho team. Khi chạy sample, tạo
batch riêng với tên như `HomeCredit_Team_SAMPLE`; không trộn sample với full.

## 2. Chuẩn bị ba CSV

```powershell
$batch = Read-Host 'BatchID đã xác nhận trên SQL Server'
$batch = [long]$batch
if ($batch -le 0) { throw 'BatchID phải lớn hơn 0.' }
$source = (Resolve-Path './home-credit-default-risk').Path
$prepared = Join-Path (Get-Location) "data/staging/hop_credit_history/batch_$batch"
$helper = './ssis/TEAM/hop_credit_history/scripts/prepare_source.py'
$rowLimit = 0 # 0 = full; 1000 = sample, dùng batch SAMPLE riêng

foreach ($file in @('previous_application.csv', 'bureau.csv', 'bureau_balance.csv')) {
    python $helper (Join-Path $source $file) (Join-Path $prepared $file) --row-limit $rowLimit
    if ($LASTEXITCODE -ne 0) { throw "Chuẩn bị CSV thất bại: $file" }
}
$prepared # Sao chép đường dẫn tuyệt đối này vào User::PreparedRoot
```

Helper giữ nguyên CSV gốc và tạo file trung gian có thêm `SourceRowNumber`
(từ 1, tính theo bản ghi CSV), kiểm tra đúng thứ tự header và chuyển biểu diễn
số theo kiểu STG. `BIGINT` giữ độ chính xác số nguyên; `DECIMAL(28,10)` làm tròn
half-away-from-zero. Giá trị rỗng được giữ để nạp thành SQL NULL. Dấu phẩy,
dấu nháy và xuống dòng trong trường được xử lý bằng CSV parser.

Mỗi CSV trung gian có manifest ghi số dòng và phạm vi `sample`/`full`. Không
trỏ package vào CSV gốc vì CSV gốc chưa có `SourceRowNumber`. Các sentinel như
`365243`, `XNA`, số tiền âm và khóa chưa khớp được giữ cho bước NDS sau này.

## 3. Cấu hình và chạy trong Visual Studio

1. Mở `Hop_CreditHistory/Hop_CreditHistory.slnx`.
2. Mở từng package và sửa các biến ở **package scope** trong cửa sổ Variables:

   | Biến | Giá trị cần đặt |
   | --- | --- |
   | `User::ServerInstance` | Tên SQL Server thực tế, giống tên kết nối trong SSMS |
   | `User::BatchID` | BatchID đã xác nhận, lớn hơn 0 và đang RUNNING |
   | `User::PreparedRoot` | Đường dẫn tuyệt đối `$prepared`, không có tên file ở cuối |

   Đặt cùng giá trị cho cả ba package. Các biến audit/counter còn lại để mặc
   định. Connection Managers dùng expressions lấy server và đường dẫn từ các
   biến này, kết nối database `HomeCreditBI` bằng Windows Authentication.
3. Build solution. Trong Solution Explorer, nhấn phải package cần chạy rồi
   chọn **Execute Package**, chạy lần lượt 01 → 02 → 03. F5 có thể chạy startup
   package khác với tab đang mở.

Source portable có `BatchID=0`, `PreparedRoot` rỗng; cần cấu hình trước khi chạy.
Giữ cấu hình riêng trên máy trong bản sao `*.local.dtsx` hoặc hoàn tác các giá
trị riêng trước khi commit source portable. Không đưa tên server/đường dẫn máy
cá nhân vào commit chung.

## 4. Đối soát kết quả

Mỗi package mở audit file, nạp typed CSV bằng OLE DB Fast Load rồi đối soát số
bản ghi đã commit theo BatchID. Metadata gồm `BatchID`, `SourceRowNumber` và
thời điểm UTC. Lỗi chuyển đổi tại Derived Column đi vào `ctl.RejectedRow`;
lỗi parse/SQL có thể làm Data Flow thất bại và được kết thúc bằng audit FAILED.

Điều kiện thành công: `RowsRead = RowsAccepted + RowsRejected`, audit
`SUCCEEDED`, không có reject và số dòng STG khớp manifest của nguồn.
Dùng BatchID thực tế trong truy vấn sau:

```sql
USE HomeCreditBI;
DECLARE @BatchID BIGINT = 0; -- Thay bằng BatchID đã chạy

SELECT N'PreviousApplication' AS TableName, COUNT_BIG(*) AS ActualRows
FROM stg.PreviousApplication WHERE BatchID = @BatchID
UNION ALL
SELECT N'BureauCredit', COUNT_BIG(*)
FROM stg.BureauCredit WHERE BatchID = @BatchID
UNION ALL
SELECT N'BureauBalance', COUNT_BIG(*)
FROM stg.BureauBalance WHERE BatchID = @BatchID;

SELECT s.FileName, f.FileLoadID, f.LoadStatus,
       f.RowsRead, f.RowsAccepted, f.RowsRejected
FROM ctl.ETLFileLoad AS f
JOIN ctl.SourceFile AS s ON s.SourceFileID = f.SourceFileID
WHERE f.BatchID = @BatchID
  AND s.FileName IN
      (N'previous_application.csv', N'bureau.csv', N'bureau_balance.csv')
ORDER BY s.FileName, f.FileLoadID;
```

Số dòng full kỳ vọng: previous application **1.670.214**, bureau **1.716.428**,
bureau balance **27.299.925**. Sample đối chiếu theo manifest, không dùng các
mốc full này.

Loader từ chối nạp lặp vào cùng bảng/batch. Nếu lần chạy lỗi còn dữ liệu một
phần, kiểm tra audit và dữ liệu trước khi xử lý; không xóa dữ liệu hay ép thay
thế để bỏ qua guard. Ba loader không tự đóng batch chung của team.

## Phạm vi commit

Bộ này gồm 7 file SSIS, `scripts/prepare_source.py`, `.gitignore` và README.
Các file cấu hình local, output build và cache được ignore. NDS và các công cụ
build/configure/verify riêng không thuộc bộ source này.
