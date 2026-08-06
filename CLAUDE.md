# CLAUDE.md

## Project Overview

Campaign dashboard app migrating from exclusion-based to inclusion-based campaign filtering. Ruby on Rails REST API + PostgreSQL database, containerized with Docker Compose.

## Architecture

```
api (Rails :3000)
    └── connects to db (Postgres :5432)
    └── cron daemon (daily inclusion sync)
```

- `data/` is mounted read-only into the API container at `/app/data/`
- The exclusion config (`data/exclusion_config.yaml`) is read at request time by the v1 campaigns controller — not cached at boot
- Seeds run automatically on first container start via `entrypoint.sh`
- Cron daemon starts on boot for daily inclusion sync (`api/crontab`)

## Key Files

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Orchestrates containers |
| `api/entrypoint.sh` | Waits for DB, runs `db:prepare` + `db:seed`, starts cron, starts Rails |
| `api/config/routes.rb` | All API routes (v1 + v2) |
| `api/app/controllers/api/v1/campaigns_controller.rb` | Campaign listing + exclusion filtering |
| `api/app/controllers/api/v2/brands_controller.rb` | Brand-centric inclusion management |
| `api/app/models/inclusion_rule.rb` | Wildcard pattern rules (one per brand) |
| `api/app/models/included_campaign.rb` | Materialized inclusion records (`campaign_id_inclusions` table) |
| `api/app/services/inclusion_sync_service.rb` | Syncs inclusions from rules via SQL ILIKE matching |
| `api/lib/tasks/sync_inclusions.rake` | Rake wrapper for `InclusionSyncService` |
| `scripts/migrate_exclusions_to_inclusions.py` | One-time migration: reads CSV + YAML, outputs inclusion CSV |
| `scripts/import_inclusions.py` | Imports the inclusion CSV into PostgreSQL |
| `api/crontab` | Daily cron: `inclusions:sync` at midnight |
| `api/db/seeds.rb` | Seeds `dim_campaigns` from CSV |
| `data/exclusion_config.yaml` | Legacy per-brand campaign exclusion rules (YAML) |
| `data/dim_campaign.csv` | Source data for dim_campaigns table |

## Database Tables

- `dim_campaigns` — campaign source of truth, seeded from CSV (unique on `brand_id, platform_name, campaign_id`)
- `inclusion_rules` — one wildcard pattern per brand (unique on `brand_id`)
- `campaign_id_inclusions` — materialized included campaigns; carries `company_id` (unique on `brand_id, platform_name, campaign_id`). A composite FK on `(company_id, brand_id, platform_name, campaign_id)` → `dim_campaigns` enforces that a brand can only include campaigns it actually owns, so cross-company/cross-brand leakage is impossible at the DB level.

## API Endpoints

### v1 (legacy exclusion-based)

```
GET /health
GET /api/v1/campaigns?brand_id=&platform_name=&search=
GET /api/v1/campaigns/brands
GET /api/v1/campaigns/platforms
GET /api/v1/campaigns/exclusion_brands
```

### v2 (inclusion-based)

```
GET    /api/v2/campaigns               # list included campaigns (brand_id, platform_name, company_id, search)
GET    /api/v2/brands                  # list all brands with inclusion rules + campaigns
GET    /api/v2/brands/:brand_id        # show one brand
POST   /api/v2/brands/:brand_id        # create brand with wildcard and/or campaigns
PATCH  /api/v2/brands/:brand_id        # update wildcard and/or add campaigns
DELETE /api/v2/brands/:brand_id        # remove brand, its rule, and all inclusions
```

## Running Locally

```bash
docker compose up --build    # first run
docker compose up            # subsequent runs
docker compose down -v       # full reset including DB
```

## Scripts & Tasks

```bash
# One-time migration: generate inclusion CSV from exclusion config (no DB needed)
python3 scripts/migrate_exclusions_to_inclusions.py

# Import the generated CSV into PostgreSQL
python3 scripts/import_inclusions.py --database-url postgres://prescient:prescient@localhost:5432/prescient_development

# Manual sync: evaluate inclusion rules and populate campaign_id_inclusions
docker compose exec api bundle exec rails inclusions:sync
```

## Rails Conventions Used

- API-only mode (`config.api_only = true`) — no views, no asset pipeline
- `self.table_name = 'dim_campaigns'` overrides Rails' default table name convention on the Campaign model
- `self.table_name = 'campaign_id_inclusions'` on the IncludedCampaign model
- No serializer gem — `as_json` + manual merging used for simplicity
- CORS is open (`origins '*'`) — fine for local dev, lock down for production

## Adding New Features

- **New endpoint**: add route to `config/routes.rb`, create controller under `app/controllers/api/v1/` or `api/v2/`
- **New table**: generate migration in `db/migrate/`, create model in `app/models/`, add seed logic to `db/seeds.rb`
