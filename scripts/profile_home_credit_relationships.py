#!/usr/bin/env python3
"""Aggregate Home Credit key coverage without emitting identifiers or raw rows."""

from __future__ import annotations

import argparse
import csv
import json
import os
from pathlib import Path
from typing import Dict, Set

RELATION_FILES = [
    "bureau.csv",
    "previous_application.csv",
    "POS_CASH_balance.csv",
    "credit_card_balance.csv",
    "installments_payments.csv",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Profile SK_ID_CURR relationship coverage.")
    parser.add_argument("--root", type=Path, default=Path("home-credit-default-risk"))
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("data/processed/eda/relationship_coverage.json"),
    )
    return parser.parse_args()


def checked_root(root: Path) -> Path:
    project = Path.cwd().resolve()
    resolved = (project / root).resolve() if not root.is_absolute() else root.resolve()
    try:
        resolved.relative_to(project)
    except ValueError as exc:
        raise SystemExit("Data root must remain inside the current project.") from exc
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
        raise SystemExit(f"Unsafe or missing expected file: {name}")
    return path


def load_ids(path: Path) -> Set[str]:
    ids: Set[str] = set()
    with path.open("r", encoding="utf-8-sig", errors="strict", newline="") as handle:
        reader = csv.DictReader(handle)
        if not reader.fieldnames or "SK_ID_CURR" not in reader.fieldnames:
            raise SystemExit(f"Expected SK_ID_CURR in {path.name}")
        for row in reader:
            value = row["SK_ID_CURR"].strip()
            if value:
                ids.add(value)
    return ids


def profile_relation(path: Path, train_ids: Set[str], test_ids: Set[str]) -> Dict[str, object]:
    counts = {
        "rows": 0,
        "missing_key_rows": 0,
        "train_rows": 0,
        "test_rows": 0,
        "unknown_rows": 0,
    }
    train_clients: Set[str] = set()
    test_clients: Set[str] = set()
    unknown_clients: Set[str] = set()

    with path.open("r", encoding="utf-8-sig", errors="strict", newline="") as handle:
        reader = csv.DictReader(handle)
        if not reader.fieldnames or "SK_ID_CURR" not in reader.fieldnames:
            raise SystemExit(f"Expected SK_ID_CURR in {path.name}")
        for row in reader:
            counts["rows"] += 1
            value = row["SK_ID_CURR"].strip()
            if not value:
                counts["missing_key_rows"] += 1
            elif value in train_ids:
                counts["train_rows"] += 1
                train_clients.add(value)
            elif value in test_ids:
                counts["test_rows"] += 1
                test_clients.add(value)
            else:
                counts["unknown_rows"] += 1
                unknown_clients.add(value)

    return {
        **counts,
        "distinct_train_clients": len(train_clients),
        "distinct_test_clients": len(test_clients),
        "distinct_unknown_clients": len(unknown_clients),
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
    with temporary.open("x", encoding="utf-8") as handle:
        os.chmod(temporary, 0o600)
        json.dump(payload, handle, indent=2, sort_keys=True)
        handle.write("\n")
    temporary.replace(resolved)


def main() -> int:
    args = parse_args()
    root = checked_root(args.root)
    train_ids = load_ids(checked_file(root, "application_train.csv"))
    test_ids = load_ids(checked_file(root, "application_test.csv"))
    overlap = len(train_ids.intersection(test_ids))

    results: Dict[str, object] = {
        "scope": "complete-file SK_ID_CURR coverage",
        "raw_values_emitted": False,
        "application_train_distinct_ids": len(train_ids),
        "application_test_distinct_ids": len(test_ids),
        "train_test_id_overlap": overlap,
        "files": {},
    }

    for name in RELATION_FILES:
        results["files"][name] = profile_relation(
            checked_file(root, name),
            train_ids,
            test_ids,
        )

    write_private_json(args.output, results)
    print("Relationship coverage profile complete.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
