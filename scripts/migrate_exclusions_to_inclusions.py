#!/usr/bin/env python3
"""Convert exclusion_config.yaml to campaign_id_inclusions.csv (inverse logic).

Takes dim_campaign.csv and exclusion_config.yaml as inputs, inverts the
exclusion rules into inclusion records, and writes the result as a CSV.

Campaigns are grouped BY BRAND: a brand only ever includes campaigns it owns
(minus its own exclusions). This preserves company/brand ownership — a campaign
owned by one company is never assigned to a brand in another.

Usage:
    python scripts/migrate_exclusions_to_inclusions.py
    python scripts/migrate_exclusions_to_inclusions.py \
        --campaigns data/dim_campaign.csv \
        --exclusions data/exclusion_config.yaml \
        --output data/campaign_id_inclusions.csv
"""

import argparse
import collections
import csv
import sys

try:
    import yaml
except ImportError:
    print("Error: PyYAML is required. Install it with: pip install pyyaml")
    sys.exit(1)


def load_campaigns_by_brand(path):
    """Load dim_campaign.csv grouped by brand.

    Returns dict of brand_id -> set of (company_id, platform_name, campaign_id).
    """
    by_brand = collections.defaultdict(set)
    with open(path, newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            by_brand[row["brand_id"]].add(
                (row["company_id"], row["platform_name"], row["campaign_id"])
            )
    return by_brand


def load_exclusion_config(path):
    """Load exclusion_config.yaml. Returns dict of brand_id -> [campaign_ids]."""
    with open(path) as f:
        config = yaml.safe_load(f)
    return config or {}


def invert_exclusions(by_brand, exclusion_map):
    """For each brand, yield (brand_id, excluded_ids, included) where `included`
    is the brand's own campaigns minus its exclusions."""
    for brand_id in sorted(exclusion_map.keys()):
        owned = by_brand.get(brand_id)
        if not owned:
            print(
                f"WARNING: brand {brand_id} is in the exclusion config but absent "
                f"from dim_campaign.csv; skipping.",
                file=sys.stderr,
            )
            continue

        excluded_ids = set(exclusion_map[brand_id] or [])

        owned_ids = {cid for _, _, cid in owned}
        for cid in sorted(excluded_ids - owned_ids):
            print(
                f"WARNING: brand {brand_id} excludes {cid}, which it does not own; "
                f"exclusion has no effect.",
                file=sys.stderr,
            )

        included = sorted(t for t in owned if t[2] not in excluded_ids)
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
        by_brand = load_campaigns_by_brand(args.campaigns)
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

    for brand_id, excluded_ids, included in invert_exclusions(by_brand, exclusion_map):
        owned_count = len(by_brand.get(brand_id, ()))
        for company_id, platform, cid in included:
            rows.append(
                {
                    "company_id": company_id,
                    "brand_id": brand_id,
                    "platform_name": platform,
                    "campaign_id": cid,
                }
            )
        total_excluded += len(excluded_ids)
        total_included += len(included)
        print(f"Brand {brand_id}: {len(excluded_ids)} excluded -> {len(included)} included")

        # A brand can never include more than it owns; guard against regressions
        # of the cross-company leak this script was written to fix.
        if len(included) > owned_count:
            print(
                f"Error: brand {brand_id} produced {len(included)} inclusions but "
                f"owns only {owned_count} campaigns.",
                file=sys.stderr,
            )
            sys.exit(1)

    with open(args.output, "w", newline="") as f:
        writer = csv.DictWriter(
            f, fieldnames=["company_id", "brand_id", "platform_name", "campaign_id"]
        )
        writer.writeheader()
        writer.writerows(rows)

    print()
    print("Migration complete.")
    print(f"  Total campaigns excluded (v1): {total_excluded}")
    print(f"  Total campaigns included (v2): {total_included}")
    print(f"  Output written to: {args.output}")


if __name__ == "__main__":
    main()
