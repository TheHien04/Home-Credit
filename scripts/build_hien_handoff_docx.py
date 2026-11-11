#!/usr/bin/env python3
"""Build the Word handoff for Hiển from verified repository facts."""

from __future__ import annotations

from pathlib import Path

from docx import Document
from docx.enum.section import WD_SECTION
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_CELL_VERTICAL_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Inches, Pt, RGBColor


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "Nhom08_HomeCreditBI_Hien_Handoff_DRAFT.docx"


def shade(cell, fill: str) -> None:
    properties = cell._tc.get_or_add_tcPr()
    shading = OxmlElement("w:shd")
    shading.set(qn("w:fill"), fill)
    properties.append(shading)


def set_cell_text(cell, text: str, bold: bool = False) -> None:
    cell.text = ""
    paragraph = cell.paragraphs[0]
    run = paragraph.add_run(text)
    run.bold = bold
    run.font.size = Pt(9)
    cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER


def add_table(document: Document, headers: list[str], rows: list[list[str]]) -> None:
    table = document.add_table(rows=1, cols=len(headers))
    table.style = "Table Grid"
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    for cell, header in zip(table.rows[0].cells, headers):
        set_cell_text(cell, header, bold=True)
        shade(cell, "D9EAF7")
    for row in rows:
        cells = table.add_row().cells
        for cell, value in zip(cells, row):
            set_cell_text(cell, value)
    document.add_paragraph()


def add_bullets(document: Document, items: list[str]) -> None:
    for item in items:
        paragraph = document.add_paragraph(style="List Bullet")
        paragraph.add_run(item)


def add_heading(document: Document, text: str, level: int = 1) -> None:
    document.add_heading(text, level=level)


def main() -> None:
    document = Document()
    section = document.sections[0]
    section.top_margin = Inches(0.7)
    section.bottom_margin = Inches(0.7)
    section.left_margin = Inches(0.8)
    section.right_margin = Inches(0.8)

    styles = document.styles
    styles["Normal"].font.name = "Arial"
    styles["Normal"].font.size = Pt(10)
    styles["Title"].font.name = "Arial"
    styles["Title"].font.size = Pt(24)
    styles["Title"].font.bold = True
    styles["Heading 1"].font.name = "Arial"
    styles["Heading 1"].font.color.rgb = RGBColor(24, 49, 83)
    styles["Heading 2"].font.name = "Arial"
    styles["Heading 2"].font.color.rgb = RGBColor(37, 99, 166)

    title = document.add_paragraph()
    title.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = title.add_run("HOME CREDIT BI — HIỂN HANDOFF")
    run.bold = True
    run.font.size = Pt(24)
    run.font.color.rgb = RGBColor(24, 49, 83)

    subtitle = document.add_paragraph()
    subtitle.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = subtitle.add_run("Bản tổng hợp Word · DRAFT / SOURCE RELEASE · 12/11/2026")
    run.italic = True
    run.font.size = Pt(11)

    warning = document.add_paragraph()
    warning.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = warning.add_run(
        "Chưa phải bản nộp cuối: runtime SQL Server, SSIS, Power BI và evidence Windows đang PENDING."
    )
    run.bold = True
    run.font.color.rgb = RGBColor(159, 58, 74)

    add_heading(document, "1. Phạm vi và trạng thái", 1)
    document.add_paragraph(
        "Owner: Nguyễn Thế Hiển (22127107). Phạm vi gồm data modeling, independent data quality, "
        "metadata/audit specification, KPI oracle, tài liệu bàn giao và review evidence."
    )
    add_table(
        document,
        ["Assignment", "Đã hoàn thành", "Còn cần để đóng"],
        [
            [
                "Mapping, data model, progress control",
                "Mapping, dictionary, DDS model, checklist và status review.",
                "Nhóm xác nhận và review chéo.",
            ],
            [
                "Profiling và test oracle",
                "Full scan, SHA-256, DQ findings, KPI baseline, bounded samples.",
                "Actual-vs-expected từ canonical batch.",
            ],
            [
                "Metadata/audit",
                "Control tables, batch/file procedures, DQ validators và audit queries.",
                "ETLBatch, ETLFileLoad, DataQualityResult runtime.",
            ],
            [
                "Report/slide/evidence review",
                "Report source, team plan, slide source, handoff và release gate.",
                "PDF/DOCX/PPTX/PBIX và evidence Windows.",
            ],
        ],
    )

    add_heading(document, "2. Kết quả local đã xác nhận", 1)
    add_table(
        document,
        ["Metric", "Verified value", "Interpretation"],
        [
            ["Source files", "10", "Intake inventory"],
            ["Business rows scanned", "58,441,149", "Full local scan"],
            ["Labeled applications", "307,511", "TRAIN population"],
            ["Default applications", "24,825", "TARGET = 1"],
            ["Observed default rate", "8.0729%", "Local oracle, not SQL runtime"],
            ["Previous approval rate", "62.6794%", "TRAIN-linked previous applications"],
            ["Late-payment rate", "8.5739%", "Recorded payment rows only"],
            ["Missing payment rows", "2,583", "Union of missing date/amount rows"],
        ],
    )
    document.add_paragraph(
        "Các giá trị trên là LOCAL VERIFIED từ full-file scan. Chỉ chuyển thành RUNTIME VERIFIED "
        "sau khi SQL Server trả cùng population và có result grid."
    )

    add_heading(document, "3. Data model và quality contract", 1)
    add_bullets(
        document,
        [
            "Source → STG → DQ gates → NDS → DDS → Power BI.",
            "STG giữ giá trị source-aligned và lineage; NDS chuẩn hóa nhưng giữ quality flags; DDS định nghĩa grain cho BI.",
            "Sentinel DAYS_EMPLOYED = 365243 được chuyển thành null ở NDS và giữ flag.",
            "Gender XNA được map thành Unknown và giữ flag.",
            "Missing payment giữ null, không đổi thành zero.",
            "Parent-missing history row không bị xóa; dùng unknown member/quality flag.",
            "Default KPI chỉ tính trên labeled TRAIN applications.",
        ],
    )
    add_heading(document, "4. Metadata và audit contract", 1)
    add_table(
        document,
        ["Object", "Vai trò", "Acceptance"],
        [
            ["ctl.ETLBatch", "Batch chung, trạng thái, tổng row counts.", "Một canonical BatchID; status và timestamps rõ."],
            ["ctl.ETLFileLoad", "Audit từng source file, FileLoadID, accepted/rejected.", "RowsRead = RowsAccepted + RowsRejected."],
            ["ctl.DataQualityResult", "Test code, expected, actual, PASS/FAIL/WARN.", "Không có FAIL chưa xử lý; WARN phải giải thích."],
            ["ctl.RejectedRow", "Lưu dòng lỗi và lý do reject.", "Không silently drop conversion errors."],
        ],
    )

    add_heading(document, "5. Evidence Windows cần bàn giao", 1)
    add_table(
        document,
        ["ID", "Evidence", "Status"],
        [
            ["HN-01", "SQL smoke test: 59 objects, 5 schemas.", "PENDING"],
            ["HN-02", "ETLBatch row với một BatchID chung.", "PENDING"],
            ["HN-03", "ETLFileLoad đủ 8 nguồn, terminal status.", "PENDING"],
            ["HN-04", "STG expected-vs-actual cho 7 bảng.", "PENDING"],
            ["HN-05", "DataQualityResult, FAIL/WARN review.", "PENDING"],
            ["HN-06", "NDS/DDS validators cùng BatchID.", "PENDING"],
            ["HN-07", "KPI reconciliation khớp local oracle.", "PENDING"],
            ["HN-08", "Power BI 5 pages, SQL–DAX comparison.", "PENDING"],
            ["HN-09", "Rerun before/after counts không duplicate.", "PENDING"],
        ],
    )

    add_heading(document, "6. Checklist release", 1)
    add_table(
        document,
        ["Deliverable", "Hiện trạng", "Điều kiện hoàn tất"],
        [
            ["Technical report", "Source .tex ready; warning retained.", "Compile PDF/DOCX sau W02–W08."],
            ["Slides", "Source .tex 10 trang ready.", "Export PDF/PPTX, thêm screenshot thật."],
            ["Power BI", "Model/DAX spec.", "PBIX refresh và SQL–DAX reconciliation."],
            ["SSIS", "Spec + partial projects.", "Đủ 5 packages và execution evidence."],
            ["Evidence", "Chưa có canonical final packet.", "Commit W01–W07 evidence."],
        ],
    )
    document.add_paragraph(
        "Không đánh dấu PASS từ source code, số expected hoặc screenshot mẫu. Mọi runtime claim "
        "phải có result grid, execution log hoặc screenshot có BatchID, expected, actual và status."
    )

    add_heading(document, "7. Tài liệu nguồn", 1)
    add_bullets(
        document,
        [
            "docs/DATA_PROFILE_REPORT.md — profiling và quality findings.",
            "docs/DATA_CLEANING_RULES.md — cleaning contract.",
            "docs/KPI_BASELINE_FULL_SCAN.md — independent oracle.",
            "docs/SOURCE_TO_TARGET_MAPPING.md — source/STG/NDS/DDS mapping.",
            "docs/DDS_MODEL.md — dimensional model.",
            "docs/TEST_PLAN.md — test catalog.",
            "docs/HIEN_FINAL_HANDOFF.md — evidence gate và SQL queries.",
            "docs/RELEASE_READINESS.md — release decision.",
        ],
    )
    document.add_paragraph(
        "Repository: https://github.com/TheHien04/Home-Credit\n"
        "Trạng thái cuối: source-ready và locally validated; chưa submission-ready."
    )

    footer = section.footer.paragraphs[0]
    footer.alignment = WD_ALIGN_PARAGRAPH.CENTER
    footer.add_run("Nhóm 8 · Home Credit BI · Draft / Source Release").font.size = Pt(8)

    document.save(OUTPUT)
    print(OUTPUT)


if __name__ == "__main__":
    main()
