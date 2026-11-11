# LaTeX documents

Hai tài liệu chính thức được duy trì trong thư mục này:

- `report/main.tex`: báo cáo kỹ thuật Chương 1–7.
- `team-plan/main.tex`: kế hoạch, ownership, dependency và tiêu chí bàn giao của Nhóm 8.

## Biên dịch

Các file dùng Unicode tiếng Việt. XeLaTeX là lựa chọn khuyến nghị; báo cáo cũng có fallback cho pdfLaTeX. Trên Windows có thể dùng MiKTeX hoặc TeX Live; trên Overleaf nên chọn compiler **XeLaTeX**.

```text
xelatex main.tex
xelatex main.tex
```

Chạy hai lần để cập nhật mục lục, danh mục bảng và tham chiếu chéo. File sinh tự động và PDF được `.gitignore` loại khỏi source repository.

## Trạng thái kiểm chứng

`report/main.tex` là **bản thảo**, chưa phải bản nộp cuối. Không xóa nhãn bản thảo cho đến khi:

1. SQL Server/SSIS full load chạy thành công.
2. STG, NDS, DDS và KPI validators đều không có `FAIL`.
3. Power BI đã đối soát SQL–DAX.
4. Năm nhóm evidence `RUNTIME-01` đến `RUNTIME-05` đã được chèn.
5. Nhóm xác nhận thông tin trường, khoa, giảng viên và tỷ lệ đóng góp.

Hai file `.tex` là nguồn chính của báo cáo và kế hoạch nhóm. Markdown trong `docs/` chỉ giữ các tài liệu kỹ thuật hỗ trợ như profiling, cleaning rules, DDS model, KPI, mapping, test plan và checklist triển khai.

`slides/main.tex` là source slide trình bày 10 trang, dùng cùng baseline KPI và trạng thái evidence với báo cáo. Có thể biên dịch bằng XeLaTeX sau khi kiểm tra thông tin lớp, giảng viên và ngày nộp.
