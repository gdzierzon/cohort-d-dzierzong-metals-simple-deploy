"""Load the demo schema after apply; never run automatically during Terraform."""

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import time

import psycopg


TERRAFORM_DIRECTORY = Path(__file__).resolve().parents[1]
SQL_FILE = TERRAFORM_DIRECTORY.parent / "sql" / "metals-db.sql"


def initialize(connection_details, password, sql, reset=False, skip_existing=False):
    # Only retry connection establishment; never retry SQL that may have run.
    for attempt in range(15):
        try:
            connection = psycopg.connect(
                **connection_details, password=password, connect_timeout=10
            )
            break
        except psycopg.errors.ConnectionTimeout:
            if attempt == 14:
                raise
            print("Waiting for PostgreSQL/firewall availability...", flush=True)
            time.sleep(10)

    with connection:
        existing_count = connection.execute(
            "SELECT COUNT(*) FROM information_schema.tables "
            "WHERE table_schema = 'public' AND table_name IN "
            "('elements', 'alloys', 'alloy_elements', 'coins')"
        ).fetchone()[0]
        if existing_count == 4 and skip_existing:
            print("All demo tables already exist; preserving the database.")
            return False
        if existing_count and not reset:
            raise RuntimeError(
                "Demo tables already exist. Nothing was changed. "
                "Use --reset only if you intend to drop and reload the demo data."
            )
        # One transaction rolls back the schema and seed data together on failure.
        connection.execute(sql)
    return True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument(
        "--reset", action="store_true", help="Drop and recreate existing demo tables."
    )
    mode.add_argument(
        "--skip-existing", action="store_true",
        help="Succeed without changing data if all four demo tables already exist.",
    )
    args = parser.parse_args()
    password = os.environ.get("TF_VAR_db_password")
    if not password:
        parser.error("Set TF_VAR_db_password to the password used for terraform apply.")

    result = subprocess.run(
        ["terraform", f"-chdir={TERRAFORM_DIRECTORY}", "output", "-json", "database"],
        check=True, capture_output=True, text=True,
    )
    details = json.loads(result.stdout)
    loaded = initialize(
        details, password, SQL_FILE.read_text(encoding="utf-8-sig"),
        reset=args.reset, skip_existing=args.skip_existing,
    )
    if loaded:
        print("Database schema and demo data loaded successfully.")


if __name__ == "__main__":
    try:
        main()
    except (psycopg.Error, RuntimeError, subprocess.CalledProcessError) as error:
        print(f"Database initialization failed: {error}", file=sys.stderr)
        sys.exit(1)
