#!/usr/bin/env python3
"""Validate aggregate KPI baseline invariants; no source rows are read or emitted."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


EXPECTED_SCANNED_ROWS = {
    "application": 307_511,
    "previous_application": 1_670_214,
    "bureau_credit": 1_716_428,
    "bureau_monthly": 27_299_925,
    "installment_payment": 13_605_401,
    "pos_cash_monthly": 10_001_358,
    "credit_card_monthly": 3_840_312,
}


def require(condition: bool, message: str, failures: list[str]) -> None:
    if not condition:
        failures.append(message)


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate Home Credit KPI baseline invariants.")
    parser.add_argument("--input", default="data/processed/eda/full_kpi_baseline.json")
    args = parser.parse_args()

    payload = json.loads(Path(args.input).read_text(encoding="utf-8"))
    failures: list[str] = []

    for section, expected in EXPECTED_SCANNED_ROWS.items():
        require(payload[section]["rows_scanned"] == expected,
                f"{section}.rows_scanned must equal {expected}", failures)

    app = payload["application"]
    require(app["total_applications"] == 307_511, "Application denominator changed", failures)
    require(app["default_applications"] == 24_825, "Default numerator changed", failures)
    require(app["non_default_applications"] == 282_686, "Non-default count changed", failures)
    require(app["default_applications"] + app["non_default_applications"] == app["total_applications"],
            "Application target partition does not reconcile", failures)
    for group_name in ("by_contract_type", "by_age_band", "by_income_band", "by_affordability_band"):
        groups = app[group_name].values()
        require(sum(item["applications"] for item in groups) == app["total_applications"],
                f"{group_name} application counts do not reconcile", failures)
        require(sum(item["defaults"] for item in app[group_name].values()) == app["default_applications"],
                f"{group_name} default counts do not reconcile", failures)

    previous = payload["previous_application"]
    require(sum(previous["status_counts"].values()) == previous["train_linked_rows"],
            "Previous status counts do not reconcile", failures)
    require(previous["approved_rows"] == previous["status_counts"].get("Approved"),
            "Previous approved numerator disagrees with status counts", failures)

    payment = payload["installment_payment"]
    require(payment["recorded_payment_rows"] + payment["missing_payment_rows"] == payment["train_linked_rows"],
            "Recorded/missing payment partition does not reconcile", failures)
    require(payment["late_payment_rows"] <= payment["recorded_payment_rows"],
            "Late payment count exceeds recorded payments", failures)
    require(payment["parent_missing_rows"] <= payment["train_linked_rows"],
            "Installment parent-missing count exceeds scope", failures)

    bureau = payload["bureau_credit"]
    require(sum(bureau["status_counts"].values()) == bureau["train_linked_rows"],
            "Bureau status counts do not reconcile", failures)
    require(bureau["active_credit_rows"] == bureau["status_counts"].get("Active"),
            "Active bureau numerator disagrees with status counts", failures)

    bureau_month = payload["bureau_monthly"]
    require(bureau_month["train_linked_rows"] + bureau_month["parent_missing_rows"] == bureau_month["dds_scope_rows"],
            "Bureau-month DDS population does not reconcile", failures)
    require(sum(bureau_month["status_counts_in_scope"].values()) == bureau_month["dds_scope_rows"],
            "Bureau-month status counts do not reconcile", failures)

    for section in ("pos_cash_monthly", "credit_card_monthly"):
        item = payload[section]
        require(item["parent_missing_rows"] <= item["train_linked_rows"],
                f"{section} parent-missing count exceeds scope", failures)
        require(item["rows_with_dpd"] <= item["train_linked_rows"],
                f"{section} DPD count exceeds scope", failures)

    require(payload["metadata"]["raw_data_modified"] is False,
            "Baseline metadata must state raw_data_modified=false", failures)
    require(payload["metadata"]["raw_rows_emitted"] is False,
            "Baseline metadata must state raw_rows_emitted=false", failures)

    if failures:
        for failure in failures:
            print(f"FAIL: {failure}")
        raise SystemExit(1)

    print(f"KPI baseline validation: PASS ({len(EXPECTED_SCANNED_ROWS)} files, all invariants reconciled)")


if __name__ == "__main__":
    main()
