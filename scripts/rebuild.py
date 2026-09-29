#!/usr/bin/env python3
"""Rebuild the IRIS pilot database from scratch.

    python scripts/rebuild.py                 # drop schemas, migrate, seed, verify
    python scripts/rebuild.py --no-seed       # schema only
    python scripts/rebuild.py --verify-only   # run tests/verify.sql, change nothing

Connection: IRIS_DATABASE_URL, default matches docker-compose.yml.
Every migration runs in its own transaction; any failure stops the run with a
non-zero exit code.
"""
from __future__ import annotations

import argparse
import os
import pathlib
import sys
import time

import psycopg

ROOT = pathlib.Path(__file__).resolve().parents[1]
DEFAULT_DSN = "postgresql://iris_user:iris_password@localhost:5433/iris"
SCHEMAS = ("iris_core", "iris_staging")


def get_dsn() -> str:
    return os.environ.get("IRIS_DATABASE_URL", DEFAULT_DSN)


def connect(dsn: str, timeout_s: int = 60) -> psycopg.Connection:
    deadline = time.monotonic() + timeout_s
    while True:
        try:
            return psycopg.connect(dsn)
        except psycopg.OperationalError as exc:
            if time.monotonic() > deadline:
                raise SystemExit(f"Could not connect to database: {exc}")
            time.sleep(1)


def run_sql_file(conn: psycopg.Connection, path: pathlib.Path) -> None:
    print(f"  running {path.relative_to(ROOT).as_posix()}")
    with conn.transaction():
        conn.execute(path.read_text(encoding="utf-8"))


def rebuild(dsn: str, seed: bool = True, verify: bool = True) -> None:
    with connect(dsn) as conn:
        print("Dropping schemas")
        with conn.transaction():
            for schema in SCHEMAS:
                conn.execute(f"DROP SCHEMA IF EXISTS {schema} CASCADE")

        print("Applying migrations")
        for path in sorted((ROOT / "migrations").glob("*.sql")):
            run_sql_file(conn, path)

        if seed:
            print("Loading seed fixtures")
            run_sql_file(conn, ROOT / "seed" / "seed.sql")
        if verify:
            print("Verifying")
            run_sql_file(conn, ROOT / "tests" / "verify.sql")
    print("IRIS database rebuilt successfully." if verify else "Done.")


def verify_only(dsn: str) -> None:
    with connect(dsn) as conn:
        run_sql_file(conn, ROOT / "tests" / "verify.sql")
    print("Verification passed.")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--no-seed", action="store_true", help="skip loading fixtures (also skips verification)")
    parser.add_argument("--no-verify", action="store_true", help="skip tests/verify.sql")
    parser.add_argument("--verify-only", action="store_true", help="only run tests/verify.sql")
    args = parser.parse_args()

    dsn = get_dsn()
    try:
        if args.verify_only:
            verify_only(dsn)
        else:
            rebuild(dsn, seed=not args.no_seed, verify=not (args.no_verify or args.no_seed))
    except psycopg.Error as exc:
        print(f"FAILED: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
