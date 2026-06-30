# CLAUDE.md

## Project Overview

Full-stack campaign dashboard app. Ruby on Rails REST API + PostgreSQL database + vanilla JS frontend, all containerized with Docker Compose.

## Architecture

```
frontend (nginx :8080)
    └── proxies /api → api (Rails :3000)
                           └── connects to db (Postgres :5432)
```

- `data/` is mounted read-only into the API container at `/app/data/`
- The exclusion config (`data/exclusion_config.yaml`) is read at request time by the controllers — not cached at boot
- Seeds run automatically on first container start via `entrypoint.sh`

## Key Files

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Orchestrates all three containers |
| `api/entrypoint.sh` | Waits for DB, runs `db:prepare` + `db:seed`, starts Rails |
| `api/config/routes.rb` | All API routes |
| `api/app/controllers/api/v1/campaigns_controller.rb` | Campaign listing + filtering |
| `api/app/controllers/api/v1/metrics_controller.rb` | Metrics aggregation with JOIN |
| `api/app/models/campaign_metric.rb` | `with_campaign_info` scope handles the dim_campaigns JOIN + exclusion filtering |
| `api/db/seeds.rb` | Seeds `dim_campaigns` from CSV, generates `campaign_metrics` |
| `frontend/nginx.conf` | Serves static files, proxies `/api` to Rails |
| `data/exclusion_config.yaml` | Per-brand campaign exclusion rules (YAML) |
| `data/dim_campaign.csv` | Source data for dim_campaigns table |

## Database Tables

- `dim_campaigns` — campaign source of truth, seeded from CSV
- `campaign_metrics` — daily performance data (impressions, clicks, spend, conversions), 30 days × 50 campaigns = 1500 rows

## API Endpoints

```
GET /health
GET /api/v1/campaigns?brand_id=&platform_name=&search=&apply_config=true
GET /api/v1/campaigns/brands
GET /api/v1/campaigns/platforms
GET /api/v1/metrics?brand_id=&platform_name=&apply_config=true&date_from=&date_to=
```

## Running Locally

```bash
docker compose up --build    # first run
docker compose up            # subsequent runs
docker compose down -v       # full reset including DB
```

## Rails Conventions Used

- API-only mode (`config.api_only = true`) — no views, no asset pipeline
- `self.table_name = 'dim_campaigns'` overrides Rails' default table name convention on the Campaign model
- `insert_all` used in seeds for bulk metric insertion (bypasses callbacks, much faster)
- No serializer gem — `as_json` + manual merging used for simplicity
- CORS is open (`origins '*'`) — fine for local dev, lock down for production

## Adding New Features

- **New endpoint**: add route to `config/routes.rb`, create controller under `app/controllers/api/v1/`
- **New table**: generate migration in `db/migrate/`, create model in `app/models/`, add seed logic to `db/seeds.rb`
- **Frontend changes**: edit `frontend/index.html`, `app.js`, `styles.css` — rebuild with `docker compose up --build frontend`
