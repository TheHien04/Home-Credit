#!/usr/bin/env python3
"""Run reproducible static checks for the Home Credit BI repository."""

from __future__ import annotations

import argparse
import hashlib
import re
import sys
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "docs" / "RAW_DATA_SHA256.txt"
SMOKE_TEST = ROOT / "sql" / "05_tests" / "053_smoke_test_schema.sql"
EXPECTED_SQL_OBJECTS = 59

REQUIRED_ARTIFACTS = (
    ".github/workflows/validate.yml",
    "README.md",
    "data/processed/eda/full_kpi_baseline.json",
    "docs/DDS_MODEL.md",
    "docs/KPI_BASELINE_FULL_SCAN.md",
    "docs/PROJECT_STATUS.md",
    "docs/SUBMISSION_CHECKLIST.md",
    "docs/TEST_PLAN.md",
    "scripts/compute_full_kpi_baseline.py",
    "scripts/validate_kpi_baseline.py",
    "sql/000_deploy_all.sql",
    "sql/05_tests/054_validate_kpi_baseline.sql",
    "ssis/PACKAGE_BUILD_SPEC.md",
    "powerbi/MODEL_SPEC.md",
    "powerbi/MEASURES_DAX.md",
)

MARKDOWN_LINK = re.compile(r"(?<!!)\[[^]]+\]\(([^)]+)\)")
SQL_CREATE = re.compile(
    r"(?im)^\s*CREATE\s+(?:OR\s+ALTER\s+)?(?:PROCEDURE|VIEW|FUNCTION|TRIGGER)\b"
)


def fail(message: str, failures: list[str]) -> None:
    failures.append(message)


def check_required_artifacts(failures: list[str]) -> None:
    for relative in REQUIRED_ARTIFACTS:
        if not (ROOT / relative).is_file():
            fail(f"Missing required artifact: {relative}", failures)


def check_raw_hashes(failures: list[str]) -> None:
    for line_number, raw_line in enumerate(MANIFEST.read_text(encoding="utf-8").splitlines(), 1):
        if not raw_line.strip():
            continue
        expected, relative = raw_line.split(maxsplit=1)
        source = ROOT / relative
        if not source.is_file() or source.is_symlink():
            fail(f"Manifest line {line_number}: unsafe or missing file {relative}", failures)
            continue
        digest = hashlib.sha256()
        with source.open("rb") as handle:
            for block in iter(lambda: handle.read(1024 * 1024), b""):
                digest.update(block)
        if digest.hexdigest() != expected:
            fail(f"SHA-256 mismatch: {relative}", failures)


def check_markdown_links(failures: list[str]) -> None:
    for document in sorted(ROOT.rglob("*.md")):
        if any(part in {".git", "home-credit-default-risk"} for part in document.parts):
            continue
        text = document.read_text(encoding="utf-8")
        for target in MARKDOWN_LINK.findall(text):
            target = target.strip().split("#", 1)[0]
            if not target or "://" in target or target.startswith(("mailto:", "#")):
                continue
            if target.startswith("<") and target.endswith(">"):
                target = target[1:-1]
            if not (document.parent / target).resolve().exists():
                fail(f"Broken link in {document.relative_to(ROOT)}: {target}", failures)


def strip_sql_comments_and_strings(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    text = re.sub(r"--[^\n]*", "", text)
    return re.sub(r"N?'(?:''|[^'])*'", "''", text)


def check_sql_structure(failures: list[str]) -> None:
    for script in sorted((ROOT / "sql").rglob("*.sql")):
        text = strip_sql_comments_and_strings(script.read_text(encoding="utf-8"))
        if text.count("(") != text.count(")"):
            fail(f"Unbalanced parentheses: {script.relative_to(ROOT)}", failures)
        for match in SQL_CREATE.finditer(text):
            prefix = text[: match.start()]
            last_nonempty = next(
                (line.strip().upper() for line in reversed(prefix.splitlines()) if line.strip()),
                "",
            )
            if last_nonempty not in {"", "GO"}:
                fail(
                    f"CREATE may not start a SQL Server batch: {script.relative_to(ROOT)} "
                    f"line {text.count(chr(10), 0, match.start()) + 1}",
                    failures,
                )

    smoke_text = SMOKE_TEST.read_text(encoding="utf-8")
    object_rows = re.findall(
        r"^\s*\('[^']+',\s*'[^']+',\s*'[UVP]'\)[,;]?$",
        smoke_text,
        re.MULTILINE,
    )
    if len(object_rows) != EXPECTED_SQL_OBJECTS:
        fail(
            f"Schema smoke test lists {len(object_rows)} objects; expected {EXPECTED_SQL_OBJECTS}",
            failures,
        )


def strip_latex_comments(text: str) -> str:
    cleaned: list[str] = []
    for line in text.splitlines():
        index = 0
        while index < len(line):
            if line[index] == "%":
                backslashes = 0
                cursor = index - 1
                while cursor >= 0 and line[cursor] == "\\":
                    backslashes += 1
                    cursor -= 1
                if backslashes % 2 == 0:
                    line = line[:index]
                    break
            index += 1
        cleaned.append(line)
    return "\n".join(cleaned)


def check_latex_sources(failures: list[str]) -> None:
    latex_sources = (
        ROOT / "latex" / "report" / "main.tex",
        ROOT / "latex" / "team-plan" / "main.tex",
    )
    existing_sources = tuple(source for source in latex_sources if source.is_file())
    if not existing_sources:
        return
    if len(existing_sources) != len(latex_sources):
        fail("LaTeX release is incomplete: report and team plan must be published together", failures)
        return

    for source in latex_sources:
        text = strip_latex_comments(source.read_text(encoding="utf-8"))
        relative = source.relative_to(ROOT)
        if "\\documentclass" not in text:
            fail(f"Missing documentclass: {relative}", failures)
        if "\\usepackage{iftex}" not in text or "\\ifPDFTeX" not in text:
            fail(f"Missing pdfLaTeX/XeLaTeX compatibility guard: {relative}", failures)
        if text.count("\\begin{document}") != 1 or text.count("\\end{document}") != 1:
            fail(f"Invalid document boundary: {relative}", failures)

        brace_depth = 0
        for index, character in enumerate(text):
            if character not in "{}":
                continue
            backslashes = 0
            cursor = index - 1
            while cursor >= 0 and text[cursor] == "\\":
                backslashes += 1
                cursor -= 1
            if backslashes % 2 == 1:
                continue
            brace_depth += 1 if character == "{" else -1
            if brace_depth < 0:
                fail(f"Closing brace without opener: {relative}", failures)
                break
        if brace_depth != 0:
            fail(f"Unbalanced LaTeX braces ({brace_depth}): {relative}", failures)

        begins = Counter(re.findall(r"\\begin\{([^}]+)\}", text))
        ends = Counter(re.findall(r"\\end\{([^}]+)\}", text))
        if begins != ends:
            fail(f"Unbalanced LaTeX environments: {relative}", failures)

    report = latex_sources[0].read_text(encoding="utf-8")
    if "BẢN THẢO" not in report or "RUNTIME-05" not in report:
        fail("LaTeX report must retain draft and runtime-evidence gates", failures)
    required_report_sections = (
        "fig:dds-star",
        "tab:dds-bus",
        "tab:source-target",
        "tab:expected-counts",
        "tab:sql-dax",
        "tab:evidence-register",
        "RUNTIME-06",
    )
    for marker in required_report_sections:
        if marker not in report:
            fail(f"LaTeX report is missing required marker: {marker}", failures)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Validate versioned Home Credit BI artifacts and optional local raw data."
    )
    parser.add_argument(
        "--skip-raw",
        action="store_true",
        help="Skip source-file SHA-256 verification for CI or a code-only clone.",
    )
    args = parser.parse_args()

    failures: list[str] = []
    check_required_artifacts(failures)
    if not args.skip_raw:
        check_raw_hashes(failures)
    check_markdown_links(failures)
    check_sql_structure(failures)
    check_latex_sources(failures)

    if failures:
        for message in failures:
            print(f"FAIL: {message}")
        raise SystemExit(1)

    raw_summary = "raw hashes skipped" if args.skip_raw else "10 raw hashes"
    print(
        "Project artifact validation: PASS "
        f"({len(REQUIRED_ARTIFACTS)} required artifacts, {raw_summary}, "
        f"{EXPECTED_SQL_OBJECTS} SQL objects, links and optional LaTeX conventions)"
    )


if __name__ == "__main__":
    main()
