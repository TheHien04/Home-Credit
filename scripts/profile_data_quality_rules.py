#!/usr/bin/env python3
"""Run deterministic aggregate data-quality rules over Home Credit CSV files."""

from __future__ import annotations

import argparse
import csv
import json
import os
from collections import Counter
from pathlib import Path
from typing import Callable, Dict, List, Mapping, Sequence

Row = Mapping[str, str]
Predicate = Callable[[Row], bool]


def blank(value: str) -> bool:
    return not value.strip()


def number(value: str) -> float | None:
    value = value.strip()
    return None if not value else float(value)


def any_negative(row: Row, columns: Sequence[str]) -> bool:
    return any((value := number(row[column])) is not None and value < 0 for column in columns)


def any_outside_zero_one(row: Row, columns: Sequence[str]) -> bool:
    return any(
        (value := number(row[column])) is not None and not 0 <= value <= 1
        for column in columns
    )


RULES: Dict[str, List[Dict[str, object]]] = {
    "application_train.csv": [
        {"code": "APP_MISSING_KEY", "severity": "REJECT", "action": "REJECT_ROW",
         "test": lambda r: blank(r["SK_ID_CURR"])},
        {"code": "APP_INVALID_TARGET", "severity": "REJECT", "action": "REJECT_ROW",
         "test": lambda r: r["TARGET"].strip() not in {"0", "1"}},
        {"code": "APP_NONPOS_INCOME", "severity": "REJECT", "action": "REVIEW_ROW",
         "test": lambda r: (v := number(r["AMT_INCOME_TOTAL"])) is not None and v <= 0},
        {"code": "APP_NONPOS_CREDIT", "severity": "REJECT", "action": "REVIEW_ROW",
         "test": lambda r: (v := number(r["AMT_CREDIT"])) is not None and v <= 0},
        {"code": "APP_MISSING_ANNUITY", "severity": "WARN", "action": "KEEP_NULL",
         "test": lambda r: blank(r["AMT_ANNUITY"])},
        {"code": "APP_NONPOS_ANNUITY", "severity": "WARN", "action": "REVIEW_ROW",
         "test": lambda r: (v := number(r["AMT_ANNUITY"])) is not None and v <= 0},
        {"code": "APP_MISSING_GOODS_PRICE", "severity": "WARN", "action": "KEEP_NULL",
         "test": lambda r: blank(r["AMT_GOODS_PRICE"])},
        {"code": "APP_NONPOS_GOODS_PRICE", "severity": "WARN", "action": "REVIEW_ROW",
         "test": lambda r: (v := number(r["AMT_GOODS_PRICE"])) is not None and v <= 0},
        {"code": "APP_DAYS_BIRTH_NONNEGATIVE", "severity": "REJECT", "action": "REVIEW_ROW",
         "test": lambda r: (v := number(r["DAYS_BIRTH"])) is None or v >= 0},
        {"code": "APP_EMPLOYED_SENTINEL", "severity": "WARN", "action": "NORMALIZE_NULL",
         "test": lambda r: r["DAYS_EMPLOYED"].strip() == "365243"},
        {"code": "APP_EMPLOYED_OTHER_POSITIVE", "severity": "WARN", "action": "REVIEW_ROW",
         "test": lambda r: (v := number(r["DAYS_EMPLOYED"])) is not None and v > 0 and v != 365243},
        {"code": "APP_NEGATIVE_CHILDREN", "severity": "REJECT", "action": "REVIEW_ROW",
         "test": lambda r: (v := number(r["CNT_CHILDREN"])) is not None and v < 0},
        {"code": "APP_NONPOS_FAMILY_MEMBERS", "severity": "WARN", "action": "REVIEW_ROW",
         "test": lambda r: (v := number(r["CNT_FAM_MEMBERS"])) is not None and v <= 0},
        {"code": "APP_GENDER_UNKNOWN", "severity": "WARN", "action": "MAP_UNKNOWN",
         "test": lambda r: blank(r["CODE_GENDER"]) or r["CODE_GENDER"].strip() == "XNA"},
        {"code": "APP_EXT_SOURCE_OUT_OF_RANGE", "severity": "WARN", "action": "REVIEW_ROW",
         "test": lambda r: any_outside_zero_one(r, ["EXT_SOURCE_1", "EXT_SOURCE_2", "EXT_SOURCE_3"])},
    ],
    "previous_application.csv": [
        {"code": "PREV_MISSING_KEY", "severity": "REJECT", "action": "REJECT_ROW",
         "test": lambda r: blank(r["SK_ID_PREV"]) or blank(r["SK_ID_CURR"])},
        {"code": "PREV_NEGATIVE_AMOUNT", "severity": "WARN", "action": "REVIEW_ROW",
         "test": lambda r: any_negative(r, ["AMT_ANNUITY", "AMT_APPLICATION", "AMT_CREDIT",
                                             "AMT_DOWN_PAYMENT", "AMT_GOODS_PRICE"])},
        {"code": "PREV_DAYS_DECISION_POSITIVE", "severity": "WARN", "action": "REVIEW_ROW",
         "test": lambda r: (v := number(r["DAYS_DECISION"])) is not None and v > 0},
        {"code": "PREV_DATE_SENTINEL", "severity": "WARN", "action": "NORMALIZE_NULL",
         "test": lambda r: any(
             number(r[column]) == 365243
             for column in ["DAYS_FIRST_DRAWING", "DAYS_FIRST_DUE",
                            "DAYS_LAST_DUE_1ST_VERSION", "DAYS_LAST_DUE",
                            "DAYS_TERMINATION"]
         )},
        {"code": "PREV_NONPOS_PAYMENT_COUNT", "severity": "WARN", "action": "KEEP_AND_FLAG",
         "test": lambda r: (v := number(r["CNT_PAYMENT"])) is not None and v <= 0},
    ],
    "bureau.csv": [
        {"code": "BUREAU_MISSING_KEY", "severity": "REJECT", "action": "REJECT_ROW",
         "test": lambda r: blank(r["SK_ID_BUREAU"]) or blank(r["SK_ID_CURR"])},
        {"code": "BUREAU_DAYS_CREDIT_POSITIVE", "severity": "WARN", "action": "REVIEW_ROW",
         "test": lambda r: (v := number(r["DAYS_CREDIT"])) is not None and v > 0},
        {"code": "BUREAU_NEGATIVE_CREDIT", "severity": "WARN", "action": "REVIEW_ROW",
         "test": lambda r: (v := number(r["AMT_CREDIT_SUM"])) is not None and v < 0},
        {"code": "BUREAU_NEGATIVE_DEBT", "severity": "WARN", "action": "KEEP_AND_FLAG",
         "test": lambda r: (v := number(r["AMT_CREDIT_SUM_DEBT"])) is not None and v < 0},
        {"code": "BUREAU_NEGATIVE_OVERDUE", "severity": "WARN", "action": "REVIEW_ROW",
         "test": lambda r: (v := number(r["AMT_CREDIT_SUM_OVERDUE"])) is not None and v < 0},
    ],
    "bureau_balance.csv": [
        {"code": "BUREAU_BAL_MISSING_KEY", "severity": "REJECT", "action": "REJECT_ROW",
         "test": lambda r: blank(r["SK_ID_BUREAU"]) or blank(r["MONTHS_BALANCE"])},
        {"code": "BUREAU_BAL_POSITIVE_MONTH", "severity": "WARN", "action": "REVIEW_ROW",
         "test": lambda r: (v := number(r["MONTHS_BALANCE"])) is not None and v > 0},
        {"code": "BUREAU_BAL_INVALID_STATUS", "severity": "WARN", "action": "MAP_UNKNOWN",
         "test": lambda r: r["STATUS"].strip() not in {"0", "1", "2", "3", "4", "5", "C", "X"}},
    ],
    "POS_CASH_balance.csv": [
        {"code": "POS_MISSING_KEY", "severity": "REJECT", "action": "REJECT_ROW",
         "test": lambda r: blank(r["SK_ID_PREV"]) or blank(r["SK_ID_CURR"]) or blank(r["MONTHS_BALANCE"])},
        {"code": "POS_POSITIVE_MONTH", "severity": "WARN", "action": "REVIEW_ROW",
         "test": lambda r: (v := number(r["MONTHS_BALANCE"])) is not None and v > 0},
        {"code": "POS_NEGATIVE_INSTALLMENT_COUNT", "severity": "WARN", "action": "REVIEW_ROW",
         "test": lambda r: any_negative(r, ["CNT_INSTALMENT", "CNT_INSTALMENT_FUTURE"])},
        {"code": "POS_NEGATIVE_DPD", "severity": "WARN", "action": "REVIEW_ROW",
         "test": lambda r: any_negative(r, ["SK_DPD", "SK_DPD_DEF"])},
    ],
    "credit_card_balance.csv": [
        {"code": "CC_MISSING_KEY", "severity": "REJECT", "action": "REJECT_ROW",
         "test": lambda r: blank(r["SK_ID_PREV"]) or blank(r["SK_ID_CURR"]) or blank(r["MONTHS_BALANCE"])},
        {"code": "CC_POSITIVE_MONTH", "severity": "WARN", "action": "REVIEW_ROW",
         "test": lambda r: (v := number(r["MONTHS_BALANCE"])) is not None and v > 0},
        {"code": "CC_NEGATIVE_LIMIT", "severity": "WARN", "action": "KEEP_AND_FLAG",
         "test": lambda r: (v := number(r["AMT_CREDIT_LIMIT_ACTUAL"])) is not None and v < 0},
        {"code": "CC_NEGATIVE_DPD", "severity": "WARN", "action": "REVIEW_ROW",
         "test": lambda r: any_negative(r, ["SK_DPD", "SK_DPD_DEF"])},
    ],
    "installments_payments.csv": [
        {"code": "INST_MISSING_KEY", "severity": "REJECT", "action": "REJECT_ROW",
         "test": lambda r: blank(r["SK_ID_PREV"]) or blank(r["SK_ID_CURR"])},
        {"code": "INST_MISSING_PAYMENT_DATE", "severity": "WARN", "action": "KEEP_NULL",
         "test": lambda r: blank(r["DAYS_ENTRY_PAYMENT"])},
        {"code": "INST_MISSING_PAYMENT_AMOUNT", "severity": "WARN", "action": "KEEP_NULL",
         "test": lambda r: blank(r["AMT_PAYMENT"])},
        {"code": "INST_POSITIVE_DUE_DAY", "severity": "WARN", "action": "REVIEW_ROW",
         "test": lambda r: (v := number(r["DAYS_INSTALMENT"])) is not None and v > 0},
        {"code": "INST_POSITIVE_PAYMENT_DAY", "severity": "WARN", "action": "REVIEW_ROW",
         "test": lambda r: (v := number(r["DAYS_ENTRY_PAYMENT"])) is not None and v > 0},
        {"code": "INST_NEGATIVE_AMOUNT", "severity": "WARN", "action": "REVIEW_ROW",
         "test": lambda r: any_negative(r, ["AMT_INSTALMENT", "AMT_PAYMENT"])},
    ],
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run aggregate Home Credit DQ rules.")
    parser.add_argument("--root", type=Path, default=Path("home-credit-default-risk"))
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("data/processed/eda/full_data_quality_rules.json"),
    )
    return parser.parse_args()


def checked_root(root: Path) -> Path:
    project = Path.cwd().resolve()
    resolved = (project / root).resolve() if not root.is_absolute() else root.resolve()
    try:
        resolved.relative_to(project)
    except ValueError as exc:
        raise SystemExit("Root must remain inside the current project.") from exc
    if not resolved.is_dir() or resolved.is_symlink():
        raise SystemExit("Root must be a non-symlink directory.")
    return resolved


def scan_file(path: Path, rules: List[Dict[str, object]]) -> Dict[str, object]:
    counts: Counter[str] = Counter()
    rows = 0
    with path.open("r", encoding="utf-8-sig", errors="strict", newline="") as handle:
        reader = csv.DictReader(handle)
        if not reader.fieldnames:
            raise SystemExit(f"Missing header: {path.name}")
        for row in reader:
            rows += 1
            for rule in rules:
                test = rule["test"]
                if test(row):
                    counts[str(rule["code"])] += 1

    summaries = []
    for rule in rules:
        code = str(rule["code"])
        count = counts[code]
        summaries.append({
            "code": code,
            "severity": rule["severity"],
            "action": rule["action"],
            "count": count,
            "fraction": count / rows if rows else None,
        })
    return {"rows_scanned": rows, "full_scan": True, "rules": summaries}


def write_private(path: Path, payload: object) -> None:
    project = Path.cwd().resolve()
    resolved = (project / path).resolve() if not path.is_absolute() else path.resolve()
    try:
        resolved.relative_to(project)
    except ValueError as exc:
        raise SystemExit("Output must remain inside the project.") from exc
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
        "scope": "complete-file aggregate data-quality rule audit",
        "raw_values_emitted": False,
        "files": {},
    }
    for filename, rules in RULES.items():
        path = (root / filename).resolve()
        if not path.is_file() or path.is_symlink() or path.stat().st_nlink != 1:
            raise SystemExit(f"Unsafe or missing file: {filename}")
        report["files"][filename] = scan_file(path, rules)
    write_private(args.output, report)
    print("Full data-quality rule audit complete.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
