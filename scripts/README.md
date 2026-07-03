# Migration Scripts

Standalone Python scripts for migrating from exclusion-based to inclusion-based campaign filtering. No Rails environment required.

## Prerequisites

- Python 3.7+
- PyYAML: `pip install pyyaml`
- psycopg2 (only for the import script): `pip install psycopg2-binary`

## Usage

Run both scripts from the **project root** directory.

### Step 1: Generate the inclusion CSV

```bash
python3 scripts/migrate_exclusions_to_inclusions.py
```

This reads `data/dim_campaign.csv` and `data/exclusion_config.yaml`, inverts the exclusion rules, and writes the result to `data/campaign_id_inclusions.csv`.

Custom paths can be specified:

```bash
python3 scripts/migrate_exclusions_to_inclusions.py \
  --campaigns data/dim_campaign.csv \
  --exclusions data/exclusion_config.yaml \
  --output data/campaign_id_inclusions.csv
```

### Step 2: Import the CSV into PostgreSQL

```bash
python3 scripts/import_inclusions.py \
  --database-url postgres://prescient:prescient@localhost:5432/prescient_development
```

Or use the `DATABASE_URL` environment variable:

```bash
export DATABASE_URL=postgres://prescient:prescient@localhost:5432/prescient_development
python3 scripts/import_inclusions.py
```

The import is idempotent — running it multiple times skips existing records.
