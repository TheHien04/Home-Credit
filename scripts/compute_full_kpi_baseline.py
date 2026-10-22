#!/usr/bin/env python3
"""Compute full-file aggregate KPI baselines without modifying source CSVs.

The output contains aggregate counts and summaries only. It never emits raw rows
or business identifiers. Python standard library only.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import os
import platform
import tempfile
from collections import Counter, defaultdict
from pathlib import Path
from typing import Dict, Iterable, Optional


REQUIRED_FILES = {
    "application_train": "application_train.csv",
    "previous": "previous_application.csv",
    "bureau": "bureau.csv",
    "bureau_balance": "bureau_balance.csv",
    "installments": "installments_payments.csv",
    "pos": "POS_CASH_balance.csv",
    "credit_card": "credit_card_balance.csv",
}


class RunningMean:
    def __init__(self) -> None:
        self.count = 0
        self.total = 0.0

    def add(self, value: Optional[float]) -> None:
        if value is not None and math.isfinite(value):
            self.count += 1
            self.total += value

    def result(self, digits: int = 6) -> Optional[float]:
        if not self.count:
            return None
        return round(self.total / self.count, digits)


def parse_float(value: Optional[str]) -> Optional[float]:
    if value is None:
        return None
    value = value.strip()
    if not value:
        return None
    return float(value)


def parse_int(value: Optional[str]) -> Optional[int]:
    number = parse_float(value)
    if number is None:
        return None
    return int(number)


def ratio(numerator: Optional[float], denominator: Optional[float]) -> Optional[float]:
    if numerator is None or denominator is None or denominator <= 0:
        return None
    return numerator / denominator


def age_band(age: Optional[int]) -> str:
    if age is None:
        return "Unknown"
    if age < 25:
        return "Under 25"
    if age < 35:
        return "25–34"
    if age < 45:
        return "35–44"
    if age < 55:
        return "45–54"
    if age < 65:
        return "55–64"
    return "65+"


def income_band(income: Optional[float]) -> str:
    if income is None:
        return "Unknown"
    if income < 100_000:
        return "Under 100k"
    if income < 150_000:
        return "100k–149k"
    if income < 250_000:
        return "150k–249k"
    return "250k+"


def affordability_band(value: Optional[float]) -> str:
    if value is None:
        return "Unknown"
    if value <= 0.20:
        return "Low (≤20%)"
    if value <= 0.35:
        return "Moderate (20–35%)"
    if value <= 0.50:
        return "High (35–50%)"
    return "Very high (>50%)"


def ensure_regular_source(path: Path, root: Path) -> None:
    resolved = path.resolve(strict=True)
    resolved.relative_to(root)
    if path.is_symlink() or not path.is_file():
        raise ValueError(f"Source must be a regular non-symlink file: {path.name}")


def rows(path: Path, required_columns: Iterable[str]):
    with path.open("r", encoding="utf-8-sig", errors="strict", newline="") as handle:
        reader = csv.DictReader(handle, strict=True)
        fields = set(reader.fieldnames or [])
        missing = set(required_columns) - fields
        if missing:
            raise ValueError(f"{path.name} is missing required columns: {sorted(missing)}")
        yield from reader


def new_group() -> Dict[str, object]:
    return {"applications": 0, "defaults": 0, "credit": RunningMean()}


def finalize_groups(groups: Dict[str, Dict[str, object]]) -> Dict[str, dict]:
    result = {}
    for name in sorted(groups):
        item = groups[name]
        count = int(item["applications"])
        defaults = int(item["defaults"])
        result[name] = {
            "applications": count,
            "defaults": defaults,
            "default_rate": round(defaults / count, 8) if count else None,
            "average_credit_amount": item["credit"].result(2),
        }
    return result


def update_group(groups, key: str, target: int, credit: Optional[float]) -> None:
    item = groups[key]
    item["applications"] += 1
    item["defaults"] += target
    item["credit"].add(credit)


def round_money(value: float) -> float:
    return round(value, 2)


def atomic_write_json(output: Path, payload: dict, force: bool) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists() and not force:
        raise FileExistsError(f"Output exists; pass --force to replace: {output}")
    descriptor, temporary_name = tempfile.mkstemp(prefix=f".{output.name}.", dir=output.parent)
    try:
        os.fchmod(descriptor, 0o600)
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            json.dump(payload, handle, ensure_ascii=False, indent=2, sort_keys=True)
            handle.write("\n")
        os.replace(temporary_name, output)
    except Exception:
        try:
            os.unlink(temporary_name)
        except FileNotFoundError:
            pass
        raise


def main() -> None:
    parser = argparse.ArgumentParser(description="Compute full Home Credit KPI baselines.")
    parser.add_argument("--root", default="home-credit-default-risk")
    parser.add_argument("--output", default="data/processed/eda/full_kpi_baseline.json")
    parser.add_argument("--analysis-date", default="2026-10-22")
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    root = Path(args.root).resolve(strict=True)
    if not root.is_dir() or root.is_symlink():
        raise ValueError("Root must be a regular local directory, not a symlink.")
    paths = {name: root / filename for name, filename in REQUIRED_FILES.items()}
    for path in paths.values():
        ensure_regular_source(path, root)

    manifest = Path("docs/RAW_DATA_SHA256.txt")
    manifest_hash = hashlib.sha256(manifest.read_bytes()).hexdigest() if manifest.exists() else None

    train_ids = set()
    application_rows = 0
    defaults = 0
    non_defaults = 0
    credit_mean = RunningMean()
    annuity_mean = RunningMean()
    income_mean = RunningMean()
    credit_income_mean = RunningMean()
    annuity_income_mean = RunningMean()
    external_score_mean = RunningMean()
    contract_groups = defaultdict(new_group)
    age_groups = defaultdict(new_group)
    income_groups = defaultdict(new_group)
    affordability_groups = defaultdict(new_group)

    app_columns = [
        "SK_ID_CURR", "TARGET", "NAME_CONTRACT_TYPE", "DAYS_BIRTH",
        "AMT_INCOME_TOTAL", "AMT_CREDIT", "AMT_ANNUITY",
        "EXT_SOURCE_1", "EXT_SOURCE_2", "EXT_SOURCE_3",
    ]
    for row in rows(paths["application_train"], app_columns):
        application_rows += 1
        application_id = int(row["SK_ID_CURR"])
        train_ids.add(application_id)
        target = int(row["TARGET"])
        defaults += target
        non_defaults += 1 - target
        income = parse_float(row["AMT_INCOME_TOTAL"])
        credit = parse_float(row["AMT_CREDIT"])
        annuity = parse_float(row["AMT_ANNUITY"])
        credit_income = ratio(credit, income)
        annuity_income = ratio(annuity, income)
        birth_days = parse_int(row["DAYS_BIRTH"])
        age = math.floor(-birth_days / 365.25) if birth_days is not None and birth_days < 0 else None
        scores = [parse_float(row[name]) for name in ("EXT_SOURCE_1", "EXT_SOURCE_2", "EXT_SOURCE_3")]
        available_scores = [value for value in scores if value is not None]
        external_average = sum(available_scores) / len(available_scores) if available_scores else None

        credit_mean.add(credit)
        annuity_mean.add(annuity)
        income_mean.add(income)
        credit_income_mean.add(credit_income)
        annuity_income_mean.add(annuity_income)
        external_score_mean.add(external_average)
        update_group(contract_groups, row["NAME_CONTRACT_TYPE"].strip() or "Unknown", target, credit)
        update_group(age_groups, age_band(age), target, credit)
        update_group(income_groups, income_band(income), target, credit)
        update_group(affordability_groups, affordability_band(annuity_income), target, credit)

    previous_all_ids = set()
    previous_rows = 0
    previous_train_rows = 0
    previous_approved = 0
    previous_status = Counter()
    previous_application_mean = RunningMean()
    previous_credit_mean = RunningMean()
    previous_negative_amount_rows = 0
    previous_nonpositive_payment_rows = 0
    previous_columns = [
        "SK_ID_PREV", "SK_ID_CURR", "NAME_CONTRACT_STATUS", "AMT_APPLICATION",
        "AMT_CREDIT", "AMT_ANNUITY", "AMT_DOWN_PAYMENT", "AMT_GOODS_PRICE", "CNT_PAYMENT",
    ]
    for row in rows(paths["previous"], previous_columns):
        previous_rows += 1
        previous_id = int(row["SK_ID_PREV"])
        previous_all_ids.add(previous_id)
        if int(row["SK_ID_CURR"]) not in train_ids:
            continue
        previous_train_rows += 1
        status = row["NAME_CONTRACT_STATUS"].strip() or "Unknown"
        previous_status[status] += 1
        if status.upper() == "APPROVED":
            previous_approved += 1
        amounts = [parse_float(row[name]) for name in (
            "AMT_APPLICATION", "AMT_CREDIT", "AMT_ANNUITY", "AMT_DOWN_PAYMENT", "AMT_GOODS_PRICE"
        )]
        previous_application_mean.add(amounts[0])
        previous_credit_mean.add(amounts[1])
        if any(value is not None and value < 0 for value in amounts):
            previous_negative_amount_rows += 1
        payment_count = parse_float(row["CNT_PAYMENT"])
        if payment_count is not None and payment_count <= 0:
            previous_nonpositive_payment_rows += 1

    bureau_all_ids = set()
    bureau_train_ids = set()
    bureau_rows = 0
    bureau_train_rows = 0
    active_bureau_credits = 0
    active_bureau_debt = 0.0
    total_bureau_overdue = 0.0
    bureau_with_overdue = 0
    negative_bureau_debt_rows = 0
    bureau_status = Counter()
    bureau_columns = [
        "SK_ID_BUREAU", "SK_ID_CURR", "CREDIT_ACTIVE", "AMT_CREDIT_SUM_DEBT",
        "AMT_CREDIT_SUM_OVERDUE", "CREDIT_DAY_OVERDUE",
    ]
    for row in rows(paths["bureau"], bureau_columns):
        bureau_rows += 1
        bureau_id = int(row["SK_ID_BUREAU"])
        bureau_all_ids.add(bureau_id)
        if int(row["SK_ID_CURR"]) not in train_ids:
            continue
        bureau_train_ids.add(bureau_id)
        bureau_train_rows += 1
        status = row["CREDIT_ACTIVE"].strip() or "Unknown"
        bureau_status[status] += 1
        debt = parse_float(row["AMT_CREDIT_SUM_DEBT"])
        overdue_amount = parse_float(row["AMT_CREDIT_SUM_OVERDUE"])
        overdue_days = parse_int(row["CREDIT_DAY_OVERDUE"])
        if debt is not None and debt < 0:
            negative_bureau_debt_rows += 1
        if status.upper() == "ACTIVE":
            active_bureau_credits += 1
            if debt is not None:
                active_bureau_debt += debt
        if overdue_amount is not None:
            total_bureau_overdue += overdue_amount
        if (overdue_days is not None and overdue_days > 0) or (overdue_amount is not None and overdue_amount > 0):
            bureau_with_overdue += 1

    installment_rows = 0
    installment_train_rows = 0
    recorded_payment_rows = 0
    missing_payment_rows = 0
    late_payment_rows = 0
    days_late_mean = RunningMean()
    scheduled_total = 0.0
    paid_total = 0.0
    installment_parent_missing = 0
    installment_columns = [
        "SK_ID_PREV", "SK_ID_CURR", "DAYS_INSTALMENT", "DAYS_ENTRY_PAYMENT",
        "AMT_INSTALMENT", "AMT_PAYMENT",
    ]
    for row in rows(paths["installments"], installment_columns):
        installment_rows += 1
        if int(row["SK_ID_CURR"]) not in train_ids:
            continue
        installment_train_rows += 1
        previous_id = int(row["SK_ID_PREV"])
        if previous_id not in previous_all_ids:
            installment_parent_missing += 1
        due_day = parse_int(row["DAYS_INSTALMENT"])
        payment_day = parse_int(row["DAYS_ENTRY_PAYMENT"])
        scheduled = parse_float(row["AMT_INSTALMENT"])
        paid = parse_float(row["AMT_PAYMENT"])
        recorded = payment_day is not None and paid is not None
        if recorded:
            recorded_payment_rows += 1
        else:
            missing_payment_rows += 1
        if scheduled is not None:
            scheduled_total += scheduled
        if paid is not None:
            paid_total += paid
        if recorded and due_day is not None:
            delay = payment_day - due_day
            if delay > 0:
                late_payment_rows += 1
                days_late_mean.add(float(delay))

    bureau_month_rows = 0
    bureau_month_in_scope = 0
    bureau_month_train_linked = 0
    bureau_month_parent_missing = 0
    bureau_month_status = Counter()
    for row in rows(paths["bureau_balance"], ["SK_ID_BUREAU", "MONTHS_BALANCE", "STATUS"]):
        bureau_month_rows += 1
        bureau_id = int(row["SK_ID_BUREAU"])
        if bureau_id in bureau_train_ids:
            bureau_month_train_linked += 1
            bureau_month_in_scope += 1
        elif bureau_id not in bureau_all_ids:
            bureau_month_parent_missing += 1
            bureau_month_in_scope += 1
        else:
            continue
        bureau_month_status[row["STATUS"].strip() or "Unknown"] += 1

    pos_rows = 0
    pos_train_rows = 0
    pos_parent_missing = 0
    pos_dpd_rows = 0
    for row in rows(paths["pos"], ["SK_ID_PREV", "SK_ID_CURR", "SK_DPD"]):
        pos_rows += 1
        if int(row["SK_ID_CURR"]) not in train_ids:
            continue
        pos_train_rows += 1
        if int(row["SK_ID_PREV"]) not in previous_all_ids:
            pos_parent_missing += 1
        dpd = parse_int(row["SK_DPD"])
        if dpd is not None and dpd > 0:
            pos_dpd_rows += 1

    credit_card_rows = 0
    credit_card_train_rows = 0
    credit_card_parent_missing = 0
    credit_card_dpd_rows = 0
    credit_card_balance_total = 0.0
    credit_card_limit_total = 0.0
    for row in rows(paths["credit_card"], [
        "SK_ID_PREV", "SK_ID_CURR", "SK_DPD", "AMT_BALANCE", "AMT_CREDIT_LIMIT_ACTUAL"
    ]):
        credit_card_rows += 1
        if int(row["SK_ID_CURR"]) not in train_ids:
            continue
        credit_card_train_rows += 1
        if int(row["SK_ID_PREV"]) not in previous_all_ids:
            credit_card_parent_missing += 1
        dpd = parse_int(row["SK_DPD"])
        if dpd is not None and dpd > 0:
            credit_card_dpd_rows += 1
        balance = parse_float(row["AMT_BALANCE"])
        credit_limit = parse_float(row["AMT_CREDIT_LIMIT_ACTUAL"])
        if balance is not None:
            credit_card_balance_total += balance
        if credit_limit is not None:
            credit_card_limit_total += credit_limit

    payload = {
        "metadata": {
            "analysis_date": args.analysis_date,
            "scope": "complete-file aggregate scan of seven business CSV files",
            "raw_data_modified": False,
            "raw_rows_emitted": False,
            "python_version": platform.python_version(),
            "manifest_sha256": manifest_hash,
            "formulas": {
                "default_rate": "default applications / labeled TRAIN applications",
                "previous_approval_rate": "approved previous applications / TRAIN-linked previous applications",
                "late_payment_rate": "recorded payments with payment day > due day / recorded payment rows",
                "average_days_late": "mean positive payment-day minus due-day difference among late rows",
                "active_bureau_debt": "sum debt where CREDIT_ACTIVE is Active; negative debt retained",
            },
        },
        "application": {
            "rows_scanned": application_rows,
            "total_applications": application_rows,
            "default_applications": defaults,
            "non_default_applications": non_defaults,
            "default_rate": round(defaults / application_rows, 8),
            "average_credit_amount": credit_mean.result(2),
            "average_annuity_amount": annuity_mean.result(2),
            "average_income_amount": income_mean.result(2),
            "average_credit_to_income": credit_income_mean.result(6),
            "average_annuity_to_income": annuity_income_mean.result(6),
            "average_available_external_score": external_score_mean.result(6),
            "by_contract_type": finalize_groups(contract_groups),
            "by_age_band": finalize_groups(age_groups),
            "by_income_band": finalize_groups(income_groups),
            "by_affordability_band": finalize_groups(affordability_groups),
        },
        "previous_application": {
            "rows_scanned": previous_rows,
            "train_linked_rows": previous_train_rows,
            "approved_rows": previous_approved,
            "approval_rate": round(previous_approved / previous_train_rows, 8),
            "average_application_amount": previous_application_mean.result(2),
            "average_credit_amount": previous_credit_mean.result(2),
            "negative_amount_rows": previous_negative_amount_rows,
            "nonpositive_payment_count_rows": previous_nonpositive_payment_rows,
            "status_counts": dict(sorted(previous_status.items())),
        },
        "installment_payment": {
            "rows_scanned": installment_rows,
            "train_linked_rows": installment_train_rows,
            "recorded_payment_rows": recorded_payment_rows,
            "missing_payment_rows": missing_payment_rows,
            "late_payment_rows": late_payment_rows,
            "late_payment_rate": round(late_payment_rows / recorded_payment_rows, 8),
            "average_days_late": days_late_mean.result(4),
            "total_scheduled_amount": round_money(scheduled_total),
            "total_paid_amount": round_money(paid_total),
            "payment_variance_amount": round_money(paid_total - scheduled_total),
            "parent_missing_rows": installment_parent_missing,
        },
        "bureau_credit": {
            "rows_scanned": bureau_rows,
            "train_linked_rows": bureau_train_rows,
            "active_credit_rows": active_bureau_credits,
            "active_bureau_debt": round_money(active_bureau_debt),
            "total_overdue_amount": round_money(total_bureau_overdue),
            "credits_with_overdue": bureau_with_overdue,
            "negative_debt_rows": negative_bureau_debt_rows,
            "status_counts": dict(sorted(bureau_status.items())),
        },
        "bureau_monthly": {
            "rows_scanned": bureau_month_rows,
            "dds_scope_rows": bureau_month_in_scope,
            "train_linked_rows": bureau_month_train_linked,
            "parent_missing_rows": bureau_month_parent_missing,
            "status_counts_in_scope": dict(sorted(bureau_month_status.items())),
        },
        "pos_cash_monthly": {
            "rows_scanned": pos_rows,
            "train_linked_rows": pos_train_rows,
            "parent_missing_rows": pos_parent_missing,
            "rows_with_dpd": pos_dpd_rows,
        },
        "credit_card_monthly": {
            "rows_scanned": credit_card_rows,
            "train_linked_rows": credit_card_train_rows,
            "parent_missing_rows": credit_card_parent_missing,
            "rows_with_dpd": credit_card_dpd_rows,
            "total_balance_amount": round_money(credit_card_balance_total),
            "total_credit_limit_amount": round_money(credit_card_limit_total),
        },
    }

    atomic_write_json(Path(args.output), payload, args.force)
    print("Full KPI baseline scan complete.")


if __name__ == "__main__":
    main()
