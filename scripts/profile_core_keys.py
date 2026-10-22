#!/usr/bin/env python3
"""Profile exact Home Credit key integrity without emitting raw identifiers."""

from __future__ import annotations

import argparse
import csv
import gc
import json
import os
from collections import Counter
from pathlib import Path
from typing import Dict, Iterable, Set, Tuple


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Profile Home Credit key uniqueness and coverage.")
    parser.add_argument("--root", type=Path, default=Path("home-credit-default-risk"))
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("data/processed/eda/core_key_integrity.json"),
    )
    return parser.parse_args()


def checked_root(root: Path) -> Path:
    project = Path.cwd().resolve()
    resolved = (project / root).resolve() if not root.is_absolute() else root.resolve()
    try:
        resolved.relative_to(project)
    except ValueError as exc:
        raise SystemExit("Data root must remain inside the project.") from exc
    if not resolved.is_dir() or resolved.is_symlink():
        raise SystemExit("Data root must be a non-symlink directory.")
    return resolved


def checked_file(root: Path, name: str) -> Path:
    path = (root / name).resolve()
    try:
        path.relative_to(root)
    except ValueError as exc:
        raise SystemExit("Unsafe input path.") from exc
    if not path.is_file() or path.is_symlink() or path.stat().st_nlink != 1:
        raise SystemExit(f"Unsafe or missing file: {name}")
    return path


def scan_key(
    path: Path,
    key_column: str,
    extra_counter_column: str | None = None,
) -> Tuple[Set[str], Dict[str, object]]:
    values: Set[str] = set()
    counts: Counter[str] = Counter()
    rows = 0
    missing = 0
    duplicate_rows = 0

    with path.open("r", encoding="utf-8-sig", errors="strict", newline="") as handle:
        reader = csv.DictReader(handle)
        if not reader.fieldnames or key_column not in reader.fieldnames:
            raise SystemExit(f"Expected {key_column} in {path.name}")
        if extra_counter_column and extra_counter_column not in reader.fieldnames:
            raise SystemExit(f"Expected {extra_counter_column} in {path.name}")
        for row in reader:
            rows += 1
            value = row[key_column].strip()
            if not value:
                missing += 1
            elif value in values:
                duplicate_rows += 1
            else:
                values.add(value)
            if extra_counter_column:
                token = row[extra_counter_column].strip()
                counts[token if token else "<MISSING>"] += 1

    report: Dict[str, object] = {
        "rows": rows,
        "missing_key_rows": missing,
        "distinct_keys": len(values),
        "duplicate_key_rows": duplicate_rows,
    }
    if extra_counter_column:
        report["aggregate_value_counts"] = dict(sorted(counts.items()))
    return values, report


def scan_foreign_key(path: Path, key_column: str, parent_keys: Set[str]) -> Dict[str, int]:
    rows = 0
    missing = 0
    matched = 0
    orphan = 0
    distinct_orphans: Set[str] = set()

    with path.open("r", encoding="utf-8-sig", errors="strict", newline="") as handle:
        reader = csv.DictReader(handle)
        if not reader.fieldnames or key_column not in reader.fieldnames:
            raise SystemExit(f"Expected {key_column} in {path.name}")
        for row in reader:
            rows += 1
            value = row[key_column].strip()
            if not value:
                missing += 1
            elif value in parent_keys:
                matched += 1
            else:
                orphan += 1
                distinct_orphans.add(value)

    return {
        "rows": rows,
        "matched_rows": matched,
        "missing_key_rows": missing,
        "orphan_rows": orphan,
        "distinct_orphan_keys": len(distinct_orphans),
    }


def write_private_json(path: Path, payload: object) -> None:
    project = Path.cwd().resolve()
    resolved = (project / path).resolve() if not path.is_absolute() else path.resolve()
    try:
        resolved.relative_to(project)
    except ValueError as exc:
        raise SystemExit("Output must remain inside the current project.") from exc
    resolved.parent.mkdir(parents=True, exist_ok=True)
    temporary = resolved.with_suffix(resolved.suffix + ".tmp")
    if temporary.exists():
        temporary.unlink()
    with temporary.open("x", encoding="utf-8") as handle:
        os.chmod(temporary, 0o600)
        json.dump(payload, handle, indent=2, sort_keys=True)
        handle.write("\n")
    temporary.replace(resolved)


def main() -> int:
    args = parse_args()
    root = checked_root(args.root)
    report: Dict[str, object] = {
        "scope": "complete-file exact key audit",
        "raw_values_emitted": False,
        "primary_keys": {},
        "foreign_keys": {},
    }

    train_ids, train_report = scan_key(
        checked_file(root, "application_train.csv"),
        "SK_ID_CURR",
        "TARGET",
    )
    test_ids, test_report = scan_key(
        checked_file(root, "application_test.csv"),
        "SK_ID_CURR",
    )
    report["primary_keys"]["application_train.SK_ID_CURR"] = train_report
    report["primary_keys"]["application_test.SK_ID_CURR"] = test_report
    report["train_test_overlap"] = len(train_ids.intersection(test_ids))
    del train_ids, test_ids
    gc.collect()

    previous_ids, previous_report = scan_key(
        checked_file(root, "previous_application.csv"),
        "SK_ID_PREV",
    )
    report["primary_keys"]["previous_application.SK_ID_PREV"] = previous_report
    for name in [
        "POS_CASH_balance.csv",
        "credit_card_balance.csv",
        "installments_payments.csv",
    ]:
        report["foreign_keys"][f"{name}.SK_ID_PREV"] = scan_foreign_key(
            checked_file(root, name),
            "SK_ID_PREV",
            previous_ids,
        )
    del previous_ids
    gc.collect()

    bureau_ids, bureau_report = scan_key(
        checked_file(root, "bureau.csv"),
        "SK_ID_BUREAU",
    )
    report["primary_keys"]["bureau.SK_ID_BUREAU"] = bureau_report
    report["foreign_keys"]["bureau_balance.csv.SK_ID_BUREAU"] = scan_foreign_key(
        checked_file(root, "bureau_balance.csv"),
        "SK_ID_BUREAU",
        bureau_ids,
    )
    del bureau_ids
    gc.collect()

    write_private_json(args.output, report)
    print("Core key integrity profile complete.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
