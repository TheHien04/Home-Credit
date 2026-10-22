# Power BI workspace

_Semantic model và dashboard cho Home Credit analytics_

**Owner runtime trên Windows:** Nguyễn Quốc Bảo (23127328).

---

## 📊 Trang báo cáo

| Trang | Câu hỏi chính |
| --- | --- |
| Executive overview | Danh mục hiện tại có quy mô và rủi ro thế nào? |
| Credit risk profile | Phân khúc nào có default rate đáng chú ý? |
| Payment behavior | Khách hàng trả sớm, đúng hạn hay trễ hạn ra sao? |
| Credit history | Lịch sử bureau và đơn vay trước cho biết điều gì? |
| Data quality | Dữ liệu và lần tải có đáng tin cậy không? |

## ✅ Quy ước

- Dùng measure thay vì calculated column khi logic cần filter context
- Tập trung measure trong một bảng riêng
- Ẩn technical key khỏi report view
- Quan hệ mặc định là một chiều từ dimension sang fact
- Mỗi KPI có tooltip giải thích công thức và population
- Kiểm chứng measure bằng truy vấn SQL trước khi trình bày insight

## 📦 Artifact

File `.pbix` được bỏ qua trong Git vì là binary lớn. Khi nộp bài, lưu bản chính thức theo quy ước:

```text
Nhom08_HomeCreditBI_vYYYYMMDD.pbix
```

Implementation references:

- [Semantic model specification](MODEL_SPEC.md)
- [Canonical DAX measures](MEASURES_DAX.md)
