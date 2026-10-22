#!/usr/bin/env python3
"""Safely verify the expected Home Credit CSV files without printing row data."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path
from typing import Any

CORE_FILES = {
    "application_train.csv": "current application",
    "previous_application.csv": "previous application",
    "bureau.csv": "bureau credit",
    "bureau_balance.csv": "bureau monthly status",
    "installments_payments.csv": "installment payment",
    "HomeCredit_columns_description.csv": "column metadata",
}

EXTENSION_FILES = {
    "POS_CASH_balance.csv": "POS/cash monthly balance",
    "credit_card_balance.csv": "credit-card monthly balance",
}

IGNORED_ANALYTICS_FILES = {
    "application_test.csv": "Kaggle test set",
    "sample_submission.csv": "Kaggle submission template",
}

# The competition metadata file is distributed with Windows-1252 punctuation.
# All business-data CSV files remain strict UTF-8/UTF-8-with-BOM inputs.
ENCODING_OVERRIDES = {
    "HomeCredit_columns_description.csv": "cp1252",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Verify Home Credit CSV presence, shape, and safe metadata."
    )
    parser.add_argument(
        "--root",
        type=Path,
        default=Path("data/raw"),
        help="Approved raw-data directory inside this project.",
    )
    parser.add_argument(
        "--count-rows",
        action="store_true",
        help="Stream every file to count data rows; slower for large files.",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Emit machine-readable JSON instead of a table.",
    )
    return parser.parse_args()


def resolve_root(root: Path) -> Path:
    project_root = Path.cwd().resolve()
    resolved = (project_root / root).resolve() if not root.is_absolute() else root.resolve()
    try:
        resolved.relative_to(project_root)
    except ValueError as exc:
        raise SystemExit("Refusing a data root outside the current project.") from exc
    if not resolved.is_dir() or resolved.is_symlink():
        raise SystemExit("Data root must be an existing, non-symlink directory.")
    return resolved


def inspect_csv(path: Path, count_rows: bool) -> dict[str, Any]:
    if path.is_symlink() or not path.is_file():
        return {"status": "unsafe_or_missing"}

    stat = path.stat()
    if stat.st_nlink != 1:
        return {"status": "multiply_linked"}

    encoding = ENCODING_OVERRIDES.get(path.name, "utf-8-sig")
    with path.open("r", encoding=encoding, errors="strict", newline="") as handle:
        reader = csv.reader(handle)
        try:
            header = next(reader)
        except StopIteration:
            return {
                "status": "empty",
                "size_bytes": stat.st_size,
                "columns": 0,
                "rows": 0,
            }

        row_count = None
        if count_rows:
            row_count = sum(1 for _ in reader)

    return {
        "status": "present",
        "encoding": encoding,
        "size_bytes": stat.st_size,
        "columns": len(header),
        "rows": row_count,
    }


def format_size(size_bytes: int | None) -> str:
    if size_bytes is None:
        return "-"
    units = ["B", "KiB", "MiB", "GiB"]
    value = float(size_bytes)
    for unit in units:
        if value < 1024 or unit == units[-1]:
            return f"{value:.1f} {unit}"
        value /= 1024
    return "-"


def main() -> int:
    args = parse_args()
    root = resolve_root(args.root)
    groups = [
        ("core", CORE_FILES),
        ("extension", EXTENSION_FILES),
        ("not_analyzed", IGNORED_ANALYTICS_FILES),
    ]
    results: list[dict[str, Any]] = []

    for scope, expected in groups:
        for filename, purpose in expected.items():
            path = root / filename
            metadata = inspect_csv(path, args.count_rows) if path.exists() else {"status": "missing"}
            results.append(
                {
                    "scope": scope,
                    "file": filename,
                    "purpose": purpose,
                    **metadata,
                }
            )

    core_ready = all(
        item["status"] == "present"
        for item in results
        if item["scope"] == "core"
    )

    if args.json:
        print(json.dumps({"core_ready": core_ready, "files": results}, indent=2))
    else:
        print(f"{'SCOPE':<13} {'FILE':<38} {'STATUS':<10} {'SIZE':>11} {'COLS':>6} {'ROWS':>12}")
        for item in results:
            rows = item.get("rows")
            row_text = str(rows) if rows is not None else "-"
            print(
                f"{item['scope']:<13} {item['file']:<38} "
                f"{item['status']:<10} {format_size(item.get('size_bytes')):>11} "
                f"{str(item.get('columns', '-')):>6} {row_text:>12}"
            )
        print()
        print("READY_FOR_CORE_PROFILE" if core_ready else "CORE_FILES_MISSING")

    return 0 if core_ready else 2


if __name__ == "__main__":
    raise SystemExit(main())
