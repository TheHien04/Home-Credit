#!/usr/bin/env python3
"""Generate idempotent SQL Server staging DDL from bounded schema profiles."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Dict, List

TABLES = {
    "application_train.csv": ("Application", ["SK_ID_CURR"]),
    "previous_application.csv": ("PreviousApplication", ["SK_ID_PREV", "SK_ID_CURR"]),
    "bureau.csv": ("BureauCredit", ["SK_ID_BUREAU", "SK_ID_CURR"]),
    "bureau_balance.csv": ("BureauBalance", ["SK_ID_BUREAU", "MONTHS_BALANCE"]),
    "installments_payments.csv": ("InstallmentPayment", ["SK_ID_PREV", "SK_ID_CURR"]),
    "POS_CASH_balance.csv": ("POSCashBalance", ["SK_ID_PREV", "SK_ID_CURR", "MONTHS_BALANCE"]),
    "credit_card_balance.csv": ("CreditCardBalance", ["SK_ID_PREV", "SK_ID_CURR", "MONTHS_BALANCE"]),
}

SAFE_IDENTIFIER = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate Home Credit staging DDL.")
    parser.add_argument("--profiles", type=Path, default=Path("data/processed/eda"))
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("sql/01_staging/010_create_staging_tables.sql"),
    )
    return parser.parse_args()


def sql_type(kind: str) -> str:
    if kind == "integer":
        return "BIGINT"
    if kind == "numeric":
        return "DECIMAL(28,10)"
    return "NVARCHAR(255)"


def bracket(identifier: str) -> str:
    if not SAFE_IDENTIFIER.fullmatch(identifier):
        raise SystemExit(f"Unsafe SQL identifier in profile: {identifier!r}")
    return f"[{identifier}]"


def load_columns(profile_path: Path) -> List[Dict[str, object]]:
    data = json.loads(profile_path.read_text(encoding="utf-8"))
    columns = data.get("analysis", {}).get("columns")
    if not isinstance(columns, list) or not columns:
        raise SystemExit(f"Profile has no columns: {profile_path.name}")
    return columns


def create_table_sql(table_name: str, columns: List[Dict[str, object]]) -> str:
    definitions = [
        "        [StagingRowID] BIGINT IDENTITY(1,1) NOT NULL",
        "        [BatchID] BIGINT NOT NULL",
        "        [SourceRowNumber] BIGINT NOT NULL",
        "        [LoadedAtUtc] DATETIME2(3) NOT NULL\n"
        "            CONSTRAINT [DF_stg_" + table_name + "_LoadedAtUtc] DEFAULT SYSUTCDATETIME()",
    ]
    if table_name == "Application":
        definitions.append("        [DatasetSplit] VARCHAR(5) NOT NULL")

    for column in columns:
        identifier = str(column["column_id"])
        definitions.append(
            f"        {bracket(identifier)} {sql_type(str(column['inferred_kind']))} NULL"
        )

    constraints = [
        f"        CONSTRAINT [PK_stg_{table_name}] PRIMARY KEY CLUSTERED ([StagingRowID])",
        f"        CONSTRAINT [FK_stg_{table_name}_Batch] FOREIGN KEY ([BatchID]) "
        "REFERENCES [ctl].[ETLBatch] ([BatchID])",
    ]
    if table_name == "Application":
        constraints.append(
            "        CONSTRAINT [CK_stg_Application_DatasetSplit] "
            "CHECK ([DatasetSplit] IN ('TRAIN', 'TEST'))"
        )

    all_lines = definitions + constraints
    body = ",\n".join(all_lines)
    return (
        f"IF OBJECT_ID(N'[stg].[{table_name}]', N'U') IS NULL\n"
        "BEGIN\n"
        f"    CREATE TABLE [stg].[{table_name}]\n"
        "    (\n"
        f"{body}\n"
        "    );\n"
        "END;\n"
        "GO\n"
    )


def create_indexes_sql(table_name: str, keys: List[str]) -> str:
    statements: List[str] = []
    for position, key in enumerate(keys, start=1):
        bracketed = bracket(key)
        index_name = f"IX_stg_{table_name}_{key}"
        statements.append(
            "IF NOT EXISTS\n"
            "(\n"
            "    SELECT 1\n"
            "    FROM sys.indexes\n"
            f"    WHERE object_id = OBJECT_ID(N'[stg].[{table_name}]')\n"
            f"      AND name = N'{index_name}'\n"
            ")\n"
            f"    CREATE INDEX [{index_name}] ON [stg].[{table_name}] ({bracketed});\n"
            "GO\n"
        )
    return "\n".join(statements)


def main() -> int:
    args = parse_args()
    project = Path.cwd().resolve()
    profile_root = (project / args.profiles).resolve()
    output = (project / args.output).resolve()
    for path in [profile_root, output.parent]:
        try:
            path.relative_to(project)
        except ValueError as exc:
            raise SystemExit("Input/output must remain inside the project.") from exc
    output.parent.mkdir(parents=True, exist_ok=True)

    sections = [
        "/*\n"
        "Generated from bounded Home Credit schema profiles.\n"
        "All source columns are nullable in staging; validation occurs before NDS.\n"
        "Dependency: ctl.ETLBatch from 00_admin/001_create_control_layer.sql.\n"
        "This script creates objects only and never drops existing tables.\n"
        "*/\n\n"
        "SET NOCOUNT ON;\n"
        "SET XACT_ABORT ON;\n"
        "GO\n"
    ]

    for source_name, (table_name, keys) in TABLES.items():
        profile = profile_root / f"{source_name}.profile.json"
        if not profile.is_file() or profile.is_symlink():
            raise SystemExit(f"Missing safe profile: {profile.name}")
        columns = load_columns(profile)
        sections.append("\n" + create_table_sql(table_name, columns))
        sections.append("\n" + create_indexes_sql(table_name, keys))

    rendered = "".join(sections)
    if output.exists():
        current = output.read_text(encoding="utf-8")
        if current == rendered:
            print("Staging DDL already up to date.")
            return 0
        raise SystemExit("Output exists with different content; refusing to overwrite.")

    output.write_text(rendered, encoding="utf-8")
    print(f"Generated {len(TABLES)} staging tables.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
