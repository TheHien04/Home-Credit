# Windows BI toolchain setup

_Phase 0 checklist cho máy tích hợp của Nhóm 8 — cập nhật ngày 21/10/2026_

**Ownership:** Nguyễn Trường Duy chuẩn bị môi trường phát triển STG; Nguyễn Văn Hộp duy trì canonical SQL/SSIS integration host; Nguyễn Quốc Bảo chuẩn bị Power BI và kết nối tới canonical database.

---

## 📋 Kiến trúc môi trường

Nhóm cần ít nhất một máy **Windows 11 x64** làm máy tích hợp. macOS vẫn dùng được cho Git, tài liệu và kiểm tra CSV, nhưng SSIS Designer cần SSDT/Visual Studio còn Power BI Desktop yêu cầu Windows.[^1][^6]

### Baseline đề xuất

| Thành phần | Lựa chọn |
| --- | --- |
| Hệ điều hành | Windows 11 x64 |
| Database | SQL Server 2022 Developer |
| Quản trị database | SQL Server Management Studio 22 |
| IDE | Visual Studio 2022 Community |
| Database tooling | SQL Server Data Tools workload |
| ETL designer | SQL Server Integration Services Projects 2022 |
| Dashboard | Power BI Desktop 64-bit |

SQL Server Express không phù hợp vì Microsoft ghi rõ SSIS không đi kèm Express Edition.[^1] Visual Studio Community được phép dùng trong môi trường lớp học.[^2]

> 📌 **Khuyến nghị:** Cả nhóm thống nhất cùng một baseline thay vì tự chọn nhiều phiên bản khác nhau. Nếu giảng viên yêu cầu phiên bản khác, yêu cầu của giảng viên được ưu tiên.

## ⚙️ Thứ tự cài đặt

### 1. SQL Server Database Engine

1. Tải SQL Server 2022 từ trang Microsoft.
2. Chọn **Developer Edition**.
3. Chọn **New SQL Server stand-alone installation**.
4. Bật **Database Engine Services**.
5. Dùng Windows Authentication; chỉ bật Mixed Mode nếu môn học yêu cầu.
6. Ghi lại instance name, ví dụ `localhost` hoặc `localhost\SQLEXPRESS`.
7. Không đặt password hoặc connection string vào repository.

Microsoft hướng dẫn dùng SQL Server Setup Wizard và chọn Developer Edition cho môi trường phát triển/thử nghiệm.[^3]

### 2. SQL Server Management Studio

1. Tải installer `vs_SSMS.exe`.
2. Cài SSMS 22 bằng Visual Studio Installer.
3. Mở SSMS và kết nối tới instance vừa cài.
4. Chạy:

```sql
SELECT
    @@SERVERNAME AS ServerName,
    @@VERSION AS SqlServerVersion,
    SUSER_SNAME() AS LoginName;
```

SSMS 22 là bản GA hiện hành và hỗ trợ SQL Server 2014 trở lên.[^4]

### 3. Visual Studio và SSDT

1. Cài Visual Studio 2022 Community.
2. Mở **Visual Studio Installer → Modify**.
3. Trong **Data storage and processing**, chọn **SQL Server Data Tools**.
4. Hoàn tất cài đặt và khởi động Visual Studio.
5. Kiểm tra có thể tạo **SQL Server Database Project**.

SSDT là component của Visual Studio; SSIS, SSAS và SSRS được cung cấp dưới dạng extension riêng.[^5]

### 4. SSIS Projects extension

1. Trong Visual Studio, mở **Extensions → Manage Extensions**.
2. Tìm **SQL Server Integration Services Projects 2022**.
3. Chọn extension do Microsoft phát hành.
4. Đóng Visual Studio để installer hoàn tất.
5. Mở lại và kiểm tra template **Integration Services Project**.
6. Tạo project thử, thêm một package và mở Data Flow Designer.

Cài Integration Services server component không tự cài công cụ thiết kế; Microsoft yêu cầu SSDT cùng extension SSIS phù hợp.[^1]

### 5. Power BI Desktop

1. Cài Power BI Desktop từ Microsoft Store hoặc installer chính thức.
2. Dùng bản 64-bit.
3. Mở Power BI Desktop và kiểm tra **Get Data → SQL Server**.
4. Kết nối thử tới database Home Credit sau khi tạo.

Power BI Desktop yêu cầu Windows 10/Windows Server 2016 trở lên; Microsoft khuyến nghị tối thiểu 4 GB RAM khả dụng.[^6]

## 💾 Tạo database project

Sau khi SSMS kết nối thành công:

1. Mở SSMS và bật **Query → SQLCMD Mode**.
2. Mở `sql/000_deploy_all.sql`; bảo đảm working directory là thư mục `sql` để các lệnh `:r` resolve đúng.
3. Chạy file tổng; smoke test cuối script phải trả về `PASS`.
4. Kiểm tra năm schema `ctl`, `stg`, `nds`, `dds` và `etl`.
5. Kiểm tra các bảng control trong schema `ctl` và source registry.

Hoặc dùng PowerShell với Windows Authentication từ project root:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Deploy-HomeCreditSql.ps1 -ServerInstance "localhost"
```

Script sẽ kiểm tra đủ file và SHA-256 trước khi gọi `sqlcmd`; nó không tải dữ liệu vào STG.

### Truy vấn xác nhận

```sql
SELECT s.name AS SchemaName
FROM sys.schemas AS s
WHERE s.name IN ('ctl', 'stg', 'nds', 'dds', 'etl')
ORDER BY s.name;

SELECT
    sf.FileName,
    sf.ScopeName,
    sf.ExpectedGrain,
    sf.NaturalKeyRule
FROM ctl.SourceFile AS sf
ORDER BY sf.SourceFileID;
```

## ✅ Acceptance checklist

- [ ] SSMS kết nối được SQL Server
- [ ] Visual Studio tạo được Integration Services Project
- [ ] SSIS Designer mở được Control Flow và Data Flow
- [ ] Năm schema được tạo thành công
- [ ] Schema smoke test trả về `PASS`
- [ ] `ctl.SourceFile` có 10 bản ghi nguồn
- [ ] Power BI kết nối được database
- [ ] Không có credential trong project
- [ ] Ghi lại phiên bản thực tế để đưa vào Chương 4 báo cáo

## ⚠️ Lỗi thường gặp

| Triệu chứng | Kiểm tra |
| --- | --- |
| Không thấy SSIS project template | Extension SSIS chưa cài hoặc Visual Studio chưa restart |
| Có SSIS runtime nhưng không có Designer | Thiếu SSDT/SSIS Projects extension |
| Power BI không thấy SQL Server | Kiểm tra instance name, service và authentication |
| Nhóm mở project bị lỗi version | Thống nhất TargetServerVersion và Visual Studio baseline |
| CSV lỗi Unicode | Dùng UTF-8, kiểm tra code page trong Flat File Connection Manager |
| ETL hết bộ nhớ | Phát triển bằng sample rồi chạy full load trên máy tích hợp |

## 🔗 Tài liệu tham khảo

[^1]: Microsoft. (2026). "Install SQL Server Integration Services." _Microsoft Learn_. https://learn.microsoft.com/en-us/sql/integration-services/install-windows/install-integration-services

[^2]: Microsoft. (2026). "Visual Studio Community." _Visual Studio_. https://visualstudio.microsoft.com/vs/community/

[^3]: Microsoft. (2026). "Install SQL Server by using the Installation Wizard." _Microsoft Learn_. https://learn.microsoft.com/en-us/sql/database-engine/install-windows/install-sql-server-from-the-installation-wizard-setup

[^4]: Microsoft. (2026). "Install SQL Server Management Studio." _Microsoft Learn_. https://learn.microsoft.com/en-us/sql/ssms/download-sql-server-management-studio-ssms

[^5]: Microsoft. (2026). "Install SQL Server Data Tools for Visual Studio." _Microsoft Learn_. https://learn.microsoft.com/en-us/sql/ssdt/download-sql-server-data-tools-ssdt

[^6]: Microsoft. (2026). "Download Power BI Desktop." _Microsoft Learn_. https://learn.microsoft.com/en-us/power-bi/fundamentals/desktop-get-the-desktop
