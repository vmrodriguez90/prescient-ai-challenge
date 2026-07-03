#!/usr/bin/env python3
"""Convert exclusion_config.yaml to campaign_id_inclusions.csv (inverse logic).

Takes dim_campaign.csv and exclusion_config.yaml as inputs, inverts the
exclusion rules into inclusion records, and writes the result as a CSV.

Usage:
    python scripts/migrate_exclusions_to_inclusions.py
    python scripts/migrate_exclusions_to_inclusions.py \
        --campaigns data/dim_campaign.csv \
        --exclusions data/exclusion_config.yaml \
        --output data/campaign_id_inclusions.csv
"""

import argparse
import csv
import sys

try:
    import yaml
except ImportError:
    print("Error: PyYAML is required. Install it with: pip install pyyaml")
    sys.exit(1)


def load_campaigns(path):
    """Load dim_campaign.csv and return distinct (platform_name, campaign_id) pairs."""
    seen = set()
    with open(path, newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            pair = (row["platform_name"], row["campaign_id"])
            seen.add(pair)
    return sorted(seen)


def load_exclusion_config(path):
    """Load exclusion_config.yaml. Returns dict of brand_id -> [campaign_ids]."""
    with open(path) as f:
        config = yaml.safe_load(f)
    return config or {}


def invert_exclusions(all_campaigns, exclusion_map):
    """For each brand, yield (brand_id, platform_name, campaign_id) for non-excluded campaigns."""
    for brand_id in sorted(exclusion_map.keys()):
        excluded_ids = set(exclusion_map[brand_id])
        included = [
            (platform, cid)
            for platform, cid in all_campaigns
            if cid not in excluded_ids
        ]
        yield brand_id, excluded_ids, included


def main():
    parser = argparse.ArgumentParser(
        description="Convert exclusion config to inclusion CSV"
    )
    parser.add_argument(
        "--campaigns", default="data/dim_campaign.csv", help="Path to dim_campaign.csv"
    )
    parser.add_argument(
        "--exclusions",
        default="data/exclusion_config.yaml",
        help="Path to exclusion_config.yaml",
    )
    parser.add_argument(
        "--output",
        default="data/campaign_id_inclusions.csv",
        help="Output CSV path",
    )
    args = parser.parse_args()

    try:
        all_campaigns = load_campaigns(args.campaigns)
    except FileNotFoundError:
        print(f"Error: Campaign file not found: {args.campaigns}")
        sys.exit(1)

    try:
        exclusion_map = load_exclusion_config(args.exclusions)
    except FileNotFoundError:
        print(f"No exclusion config found at {args.exclusions}. Nothing to migrate.")
        sys.exit(0)

    if not exclusion_map:
        print("Exclusion config is empty. Nothing to migrate.")
        sys.exit(0)

    total_excluded = 0
    total_included = 0
    rows = []

    for brand_id, excluded_ids, included in invert_exclusions(
        all_campaigns, exclusion_map
    ):
        for platform, cid in included:
            rows.append(
                {"brand_id": brand_id, "platform_name": platform, "campaign_id": cid}
            )
        total_excluded += len(excluded_ids)
        total_included += len(included)
        print(
            f"Brand {brand_id}: {len(excluded_ids)} excluded -> {len(included)} included"
        )

    with open(args.output, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["brand_id", "platform_name", "campaign_id"])
        writer.writeheader()
        writer.writerows(rows)

    print()
    print("Migration complete.")
    print(f"  Total campaigns excluded (v1): {total_excluded}")
    print(f"  Total campaigns included (v2): {total_included}")
    print(f"  Output written to: {args.output}")


if __name__ == "__main__":
    main()
