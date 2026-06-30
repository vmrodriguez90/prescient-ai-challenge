# Campaign Dashboard

A full-stack web application for visualizing and filtering ad campaign data across platforms (Facebook Ads, Google Ads, Pinterest Ads). Includes a REST API backed by PostgreSQL, seeded with campaign and performance metrics data, and a vanilla JS frontend — all running in Docker.

## Stack

| Layer | Technology |
|-------|-----------|
| Database | PostgreSQL 16 |
| API | Ruby on Rails 7.1 (API-only) |
| Frontend | Vanilla JS + nginx |
| Infrastructure | Docker + Docker Compose |

## Repository Structure

```
├── api/                        # Rails REST API
│   ├── app/
│   │   ├── controllers/api/v1/ # CampaignsController, MetricsController
│   │   └── models/             # Campaign, CampaignMetric
│   ├── config/
│   │   ├── routes.rb
│   │   └── initializers/cors.rb
│   ├── db/
│   │   ├── migrate/            # Table definitions
│   │   └── seeds.rb            # Seed data from CSV + generated metrics
│   ├── Dockerfile
│   └── entrypoint.sh           # Waits for DB, runs migrations + seeds, starts Rails
├── frontend/                   # Static dashboard
│   ├── index.html
│   ├── app.js
│   ├── styles.css
│   ├── nginx.conf              # Serves static files + proxies /api to Rails
│   └── Dockerfile
├── data/
│   ├── dim_campaign.csv        # Seed source — 50 campaigns across 3 companies
│   └── exclusion_config.yaml   # Per-brand campaign exclusion rules
└── docker-compose.yml          # Orchestrates db, api, and frontend containers
```

## Running the App

```bash
docker compose up --build
```

That's it. Docker starts all three containers in order (DB → API → frontend).

| Service | URL |
|---------|-----|
| Frontend dashboard | http://localhost:8080 |
| Rails API | http://localhost:3000 |
| PostgreSQL | localhost:5432 |

On first boot the API container automatically runs migrations and seeds the database before starting the server.

## Database

Two tables are created and seeded on startup:

### `dim_campaigns`
Source of truth for all campaigns. Seeded from `data/dim_campaign.csv`.

| Column | Type |
|--------|------|
| id | bigint PK |
| company_id | string |
| brand_id | string |
| platform_name | string |
| campaign_id | string |
| campaign_name | string |
| created_at / updated_at | timestamp |

### `campaign_metrics`
Daily performance data per campaign. Generated on seed with 30 days of platform-realistic random values.

| Column | Type |
|--------|------|
| id | bigint PK |
| company_id | string |
| brand_id | string |
| platform_name | string |
| campaign_id | string |
| date | date |
| impressions | integer |
| clicks | integer |
| spend | decimal |
| conversions | integer |
| created_at / updated_at | timestamp |

## API Endpoints

Base URL: `http://localhost:3000/api/v1`

### Campaigns

| Method | Path | Description |
|--------|------|-------------|
| GET | `/campaigns` | List all campaigns |
| GET | `/campaigns/brands` | List unique brand IDs |
| GET | `/campaigns/platforms` | List unique platform names |

**Query params for `/campaigns`:**

| Param | Description |
|-------|-------------|
| `brand_id` | Filter by brand |
| `platform_name` | Filter by platform |
| `search` | Filter by campaign name (case-insensitive) |
| `apply_config=true` | Exclude campaigns listed in `exclusion_config.yaml` |

Each campaign in the response includes an `excluded` boolean indicating whether it appears in the exclusion config for its brand.

### Metrics

| Method | Path | Description |
|--------|------|-------------|
| GET | `/metrics` | Aggregated metrics per campaign (30-day default) |

**Query params for `/metrics`:**

| Param | Description |
|-------|-------------|
| `brand_id` | Filter by brand |
| `platform_name` | Filter by platform |
| `apply_config=true` | Exclude metrics for campaigns in the exclusion config |
| `date_from` | Start date (YYYY-MM-DD) |
| `date_to` | End date (YYYY-MM-DD) |

Metrics are aggregated and joined with `dim_campaigns`. When `apply_config=true`, the join filters out excluded campaigns at the SQL level. Each row includes computed `ctr`, `cpc`, and `cvr`.

### Health check

```
GET /health  →  { "status": "ok" }
```

## Frontend

The dashboard is served by nginx on port 8080, which proxies `/api` calls to the Rails container — no hardcoded URLs or CORS issues.

**Campaigns tab** — filterable table showing all campaigns with inclusion/exclusion status badges.

**Metrics tab** — aggregated performance table (impressions, clicks, CTR, spend, CPC, conversions, CVR) per campaign, also filterable and config-aware.

Both tabs share the same filter bar: brand, platform, search, and an "Apply Exclusion Config" toggle.

## Useful Commands

```bash
# Start everything
docker compose up --build

# Start only DB + API (no frontend)
docker compose up db api

# Stop all containers
docker compose down

# Stop and wipe the database volume
docker compose down -v

# View logs
docker compose logs api
docker compose logs db

# Re-seed the database
docker compose exec api bundle exec rails db:seed
```
