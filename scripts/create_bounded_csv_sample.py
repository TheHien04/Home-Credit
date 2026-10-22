#!/usr/bin/env python3
"""Create a bounded derived CSV sample while preserving the raw source."""

from __future__ import annotations

import argparse
import csv
import os
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Create a bounded prefix sample of a local CSV.")
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--rows", type=int, default=100_000)
    return parser.parse_args()


def checked_path(path: Path, root: Path, must_exist: bool) -> Path:
    resolved_root = root.resolve()
    resolved = (resolved_root / path).resolve() if not path.is_absolute() else path.resolve()
    try:
        resolved.relative_to(resolved_root)
    except ValueError as exc:
        raise SystemExit("Path must remain inside the approved root.") from exc
    if must_exist:
        if not resolved.is_file() or resolved.is_symlink() or resolved.stat().st_nlink != 1:
            raise SystemExit("Input must be a regular, single-linked, non-symlink file.")
    else:
        if resolved.exists():
            raise SystemExit("Output already exists; refusing to overwrite.")
        resolved.parent.mkdir(parents=True, exist_ok=True)
    return resolved


def main() -> int:
    args = parse_args()
    if args.rows < 1 or args.rows > 1_000_000:
        raise SystemExit("--rows must be between 1 and 1,000,000.")

    source = checked_path(args.input, args.root, must_exist=True)
    target = checked_path(args.output, args.root, must_exist=False)
    temporary = target.with_suffix(target.suffix + ".tmp")

    try:
        with source.open("r", encoding="utf-8-sig", errors="strict", newline="") as src:
            reader = csv.reader(src, strict=True)
            with temporary.open("x", encoding="utf-8", newline="") as dst:
                os.chmod(temporary, 0o600)
                writer = csv.writer(dst)
                try:
                    writer.writerow(next(reader))
                except StopIteration as exc:
                    raise SystemExit("Input CSV is empty.") from exc
                copied = 0
                for row in reader:
                    writer.writerow(row)
                    copied += 1
                    if copied >= args.rows:
                        break
        temporary.replace(target)
    finally:
        if temporary.exists():
            temporary.unlink()

    print(f"Created bounded sample with {copied} data rows.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
