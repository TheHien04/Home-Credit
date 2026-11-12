"""Prepare typed SSIS CSV input, preserving the raw files and business values."""
import argparse
import csv
import json
import os
import re
import sys
from decimal import Decimal, ROUND_HALF_UP, localcontext
from functools import lru_cache
from pathlib import Path

TABLES = {"previous_application.csv": "PreviousApplication", "bureau.csv": "BureauCredit",
          "bureau_balance.csv": "BureauBalance"}


def staging_contract(source_name: str) -> dict:
    table = TABLES.get(source_name)
    if not table:
        return {}
    ddl_path = Path(__file__).resolve().parents[4] / "sql/01_staging/010_create_staging_tables.sql"
    ddl = ddl_path.read_text(encoding="utf-8")
    block = ddl.split(f"CREATE TABLE [stg].[{table}]", 1)[1].split("CONSTRAINT [PK_", 1)[0]
    types = dict(re.findall(r"\[(\w+)\]\s+(BIGINT|DECIMAL\(\d+,\d+\)|NVARCHAR\(\d+\))", block))
    for metadata in ("StagingRowID", "BatchID", "SourceRowNumber"):
        types.pop(metadata, None)
    return types


@lru_cache(maxsize=32)
def decimal_shape(sql_type: str) -> tuple:
    precision, scale = map(int, re.findall(r"\d+", sql_type))
    return Decimal(1).scaleb(-scale), Decimal(10) ** (precision - scale)


def typed_value(value: str, sql_type: str) -> str:
    if not value or sql_type.startswith("NVARCHAR"):
        return value
    if sql_type == "BIGINT":
        if value.lstrip("-").isdigit() and len(value.lstrip("-")) <= 18:
            return value
        number = Decimal(value)
        integer = number.to_integral_value()
        if not number.is_finite() or number != integer or not -(2**63) <= integer < 2**63:
            raise ValueError("Value cannot be represented as SQL BIGINT")
        return format(integer, "f")
    quantum, limit = decimal_shape(sql_type)
    number = Decimal(value)
    if not number.is_finite():
        raise ValueError("Non-finite decimal source value")
    rounded = number.quantize(quantum, rounding=ROUND_HALF_UP)
    if abs(rounded) >= limit:
        raise ValueError("Source value overflows the deployed SQL decimal")
    return format(rounded, "f")


def prepare(source: Path, destination: Path, row_limit: int = 0) -> dict:
    if source.resolve() == destination.resolve():
        raise ValueError("Source and destination must be different files")
    if row_limit < 0:
        raise ValueError("row-limit cannot be negative")
    destination.parent.mkdir(parents=True, exist_ok=True)
    partial = destination.with_suffix(destination.suffix + ".partial")
    rows = 0
    try:
        with source.open("r", encoding="utf-8-sig", newline="", buffering=1024 * 1024) as incoming, partial.open(
            "w", encoding="utf-8", newline="", buffering=1024 * 1024
        ) as outgoing:
            reader = csv.reader(incoming, strict=True)
            header = next(reader)
            if not header or len(header) != len(set(header)) or "SourceRowNumber" in header:
                raise ValueError("Invalid or duplicate CSV header")
            contract = staging_contract(source.name)
            if contract and header != list(contract):
                raise ValueError("CSV header does not match the source columns in the staging DDL")
            writer = csv.writer(outgoing, lineterminator="\r\n")
            writer.writerow(["SourceRowNumber", *header])
            with localcontext() as context:
                context.prec = 50
                for ordinal, fields in enumerate(reader, 1):
                    if row_limit and ordinal > row_limit:
                        break
                    if len(fields) != len(header):
                        raise ValueError(f"CSV record {ordinal}: wrong number of fields")
                    if contract:
                        fields = [typed_value(value, contract[name]) for name, value in zip(header, fields)]
                    writer.writerow([ordinal, *fields])
                    rows = ordinal
                    if not row_limit and ordinal % 1_000_000 == 0:
                        print(f"{source.name}: prepared {ordinal:,} CSV records", file=sys.stderr, flush=True)
        os.replace(partial, destination)
    except BaseException:
        if partial.exists():
            partial.unlink()
        raise
    result = {"file": source.name, "rows": rows, "source_columns": len(header),
              "scope": "sample" if row_limit else "full", "row_limit": row_limit,
              "conversion": "exact SQL BIGINT / DECIMAL storage casts; sentinels retained" if contract else "ordinal only"}
    destination.with_suffix(".manifest.json").write_text(
        json.dumps(result, indent=2) + "\n", encoding="utf-8"
    )
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--row-limit", type=int, default=0, help="0 means the complete source")
    args = parser.parse_args()
    print(json.dumps(prepare(args.source, args.destination, args.row_limit)))
