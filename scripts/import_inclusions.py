#!/usr/bin/env python3
"""Import campaign_id_inclusions.csv into the campaign_id_inclusions database table.

Reads the CSV produced by migrate_exclusions_to_inclusions.py and inserts
rows into PostgreSQL, skipping duplicates via ON CONFLICT DO NOTHING.

Usage:
    python scripts/import_inclusions.py \
        --database-url postgres://prescient:prescient@localhost:5432/prescient_development

    # Or use the DATABASE_URL environment variable:
    DATABASE_URL=postgres://... python scripts/import_inclusions.py
"""

import argparse
import csv
import os
import sys

try:
    import psycopg2
except ImportError:
    print("Error: psycopg2 is required. Install it with: pip install psycopg2-binary")
    sys.exit(1)

INSERT_SQL = """
    INSERT INTO campaign_id_inclusions
        (brand_id, platform_name, campaign_id, inclusion_rule_id, created_at, updated_at)
    VALUES (%s, %s, %s, NULL, NOW(), NOW())
    ON CONFLICT (brand_id, platform_name, campaign_id) DO NOTHING
"""


def import_csv(conn, csv_path):
    """Read CSV and insert rows. Returns (total, inserted) counts."""
    with open(csv_path, newline="") as f:
        reader = csv.DictReader(f)
        rows = [(r["brand_id"], r["platform_name"], r["campaign_id"]) for r in reader]

    total = len(rows)
    inserted = 0

    with conn.cursor() as cur:
        for row in rows:
            cur.execute(INSERT_SQL, row)
            inserted += cur.rowcount
        conn.commit()

    return total, inserted


def main():
    parser = argparse.ArgumentParser(
        description="Import campaign_id_inclusions.csv into PostgreSQL"
    )
    parser.add_argument(
        "--csv",
        default="data/campaign_id_inclusions.csv",
        help="Path to the inclusions CSV",
    )
    parser.add_argument(
        "--database-url",
        default=os.environ.get("DATABASE_URL"),
        help="PostgreSQL connection URL (or set DATABASE_URL env var)",
    )
    args = parser.parse_args()

    if not args.database_url:
        print("Error: --database-url is required (or set DATABASE_URL env var)")
        sys.exit(1)

    if not os.path.exists(args.csv):
        print(f"Error: CSV file not found: {args.csv}")
        sys.exit(1)

    try:
        conn = psycopg2.connect(args.database_url)
    except psycopg2.Error as e:
        print(f"Error connecting to database: {e}")
        sys.exit(1)

    try:
        total, inserted = import_csv(conn, args.csv)
        skipped = total - inserted
        print(f"Import complete.")
        print(f"  Rows read:    {total}")
        print(f"  Rows inserted: {inserted}")
        print(f"  Rows skipped:  {skipped} (already existed)")
    except Exception as e:
        conn.rollback()
        print(f"Error during import: {e}")
        sys.exit(1)
    finally:
        conn.close()


if __name__ == "__main__":
    main()
