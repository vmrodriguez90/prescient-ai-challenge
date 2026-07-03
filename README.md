# Prescient Technical Challenge

## 1. Introduction

**To the Prescient Technical Team,**

This document outlines the migration path from our current **exclusion-based** campaign filtering system to a new **inclusion-based** model. The goal is to eliminate manual YAML configuration, give customers self-service control over which campaigns participate in modeling, and support automated rule-based inclusion via a scheduled task.

This repository contains a working reference implementation that demonstrates the expected inclusion system (v2 API). You can run it locally to see the full data flow end-to-end before applying any changes to production systems (and check the changes in the commit history).

### Stack

| Layer | Technology |
|-------|-----------|
| Database | PostgreSQL 16 |
| API | Ruby on Rails 7.1 |
| Infrastructure | Docker + Docker Compose |

### Running the Example Project

```bash
# Start all services (DB, API)
docker compose up --build

# The API seeds 50 campaigns from `data/dim_campaign.csv` automatically on first boot 
```

| Service | URL |
|---------|-----|
| Rails API | http://localhost:3000 |
| PostgreSQL | localhost:5432 |

On first boot, the API container waits for PostgreSQL, runs migrations, and seeds the database from `data/dim_campaign.csv`. The exclusion config at `data/exclusion_config.yaml` is read at request time by the v1 campaigns controller.

---

## 2. Previous Solution: Exclusion-Based Filtering

The current system relies on a **static YAML file** that maps each brand to a list of campaign IDs to exclude. An engineer manually edits this file and redeploys the container whenever filtering rules need to change.

### How It Works

The frontend sends a request with a `brand_id`. The controller loads the YAML exclusion config from disk, looks up the campaign IDs listed under that brand, and excludes them directly in the database query (`WHERE campaign_id NOT IN (...)`) so only non-excluded campaigns are returned.

```mermaid
flowchart LR
    A[Frontend] -->|"GET /campaigns?brand_id=B1"| B[API]
    B -->|look up brand| C[exclusion_config.yaml]
    C -->|IDs to exclude| D[Query all campaigns\nexcept those IDs]
    D --> E[Response]
```

### How the Config Gets Updated

There is no API or UI for modifying the exclusion rules. When filtering needs to change, a **developer must manually edit** `data/exclusion_config.yaml`, then **redeploy the container** for the changes to take effect.

### The Exclusion Config

The file `data/exclusion_config.yaml` maps `brand_id` to an array of `campaign_id` values that should be hidden:

```yaml
# data/exclusion_config.yaml
B1:
  - campaign_1
  - campaign_2
  - campaign_3
  - campaign_4
  - campaign_5
  - campaign_6
B2:
  - campaign_1
  - campaign_2
  - campaign_3
  - campaign_7
  - campaign_8
  - campaign_9
  - campaign_10
# ... more brands
```

### How Exclusion Is Applied

The `ExclusionConfigurable` concern reads this YAML from disk on every request (no caching, enabling hot-reload):

```ruby
# api/app/controllers/concerns/exclusion_configurable.rb
module ExclusionConfigurable
  extend ActiveSupport::Concern

  EXCLUSION_CONFIG_PATH = Rails.root.join('data', 'exclusion_config.yaml')

  private

  def load_exclusion_config
    return {} unless File.exist?(EXCLUSION_CONFIG_PATH)
    YAML.safe_load(File.read(EXCLUSION_CONFIG_PATH)) || {}
  end
end
```

The filtering is applied in the campaigns endpoint at the database query level using `WHERE campaign_id NOT IN (...)`:

```ruby
# api/app/controllers/api/v1/campaigns_controller.rb (simplified)
excluded_ids = exclusion_map.fetch(params[:brand_id], [])
campaigns = campaigns.where.not(campaign_id: excluded_ids) if excluded_ids.any?
```

### Key Files (Current Exclusion System)

| File | Role |
|------|------|
| `data/exclusion_config.yaml` | Static exclusion rules (brand -> campaign IDs) |
| `api/app/controllers/concerns/exclusion_configurable.rb` | Loads YAML at request time |
| `api/app/controllers/api/v1/campaigns_controller.rb` | In-memory exclusion filtering |

---

## 3. Problems with the Exclusion Approach

### 3.1 Manual Configuration Does Not Scale

The exclusion config is a static YAML file that requires an engineer to edit and redeploy.

**Customers should be able to manage campaign visibility themselves through our UI**, without requiring engineering intervention for every change.

### 3.2 Exclusion Undermines Data Integrity

The exclusion model defaults to "include everything" — any campaign that is **not** explicitly listed in the YAML is automatically included in modeling. 

**Explicit inclusion makes more sense to keep the integrity of our modeling data.** 

### 3.3 No Support for Automated, Rule-Based Filtering

Currently there is no way to create pattern-based rules. If a customer wants to include all campaigns matching `"Brand Search*"`, an engineer must manually identify every matching campaign ID and add the inverse to the exclusion list.

**Customers should be able to create "Inclusion Rules" based on campaign name patterns**, which will automatically update the included campaign IDs on a daily cadence via a scheduled task. When new campaigns appear in `dim_campaigns` that match an existing rule, they are automatically included — no manual intervention required.

---

## 4. Current Project Architecture

### System Topology

```mermaid
flowchart TB
    subgraph Docker Compose
        API["Rails API\nPuma :3000"]
        DB[("PostgreSQL\n:5432")]
    end

    API --> DB

    subgraph "Data Volume (read-only)"
        CSV["dim_campaign.csv"]
        YAML["exclusion_config.yaml"]
    end

    API -.->|seeds on boot| CSV
    API -.->|reads per request| YAML
```

### Database Schema

```mermaid
erDiagram
    dim_campaigns {
        id bigint PK
        company_id string
        brand_id string
        platform_name string
        campaign_id string
        campaign_name string
        created_at timestamp
        updated_at timestamp
    }
```

**`dim_campaigns`** — Campaign source of truth, maintained by the Data Engineering team. In production this table is updated daily; in this demo it is seeded from CSV (50 campaigns across 3 companies, multiple brands, 3 platforms).

### API Endpoints (v1)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/health` | Health check |
| GET | `/api/v1/campaigns` | List campaigns with optional exclusion filtering |
| GET | `/api/v1/campaigns/brands` | Unique brand IDs |
| GET | `/api/v1/campaigns/platforms` | Unique platform names |
| GET | `/api/v1/campaigns/exclusion_brands` | Brands with exclusion rules in YAML |

**Common query params:** `brand_id`, `platform_name`

### Startup Flow

The `api/entrypoint.sh` script orchestrates boot:

1. Wait for PostgreSQL to accept connections (`pg_isready`)
2. Run `rails db:prepare` (create DB if needed + run migrations)
3. Run `rails db:seed` (load CSV campaigns)
4. Start cron daemon (daily inclusion sync at midnight)
5. Start Puma server on `0.0.0.0:3000`

---

## 5. Migration Approach

We will create an **inclusion-based system** accessible through a **new v2 API**, deployed alongside the existing v1 endpoints. This ensures zero disruption to the data team or any other consumers currently relying on the exclusion-based v1 API.

```mermaid
flowchart LR
    subgraph "v1 — Unchanged"
        EX["exclusion_config.yaml"]
        V1C["v1 Controllers"]
        V1C -->|reads| EX
    end

    subgraph "v2 — New"
        IR[("inclusion_rules\ntable")]
        IC[("campaign_id_inclusions\ntable")]
        V2C["v2 Controllers"]
        EVAL["Daily Task\nevaluate rules"]
        V2C -->|queries| IC
        EVAL -->|pattern match| IR
        EVAL -->|populate| IC
    end

    DE["Data Engineering\n(external)"] -->|updates daily| DC
    DC[("dim_campaigns")] -.->|source| EVAL
```

### Key Principles

1. **v1 remains fully functional** — the existing exclusion YAML, controllers, and query logic are untouched. Current consumers (data team, dashboards, pipelines) experience no changes.

2. **v2 is database-backed** — inclusion rules and included campaigns are stored in PostgreSQL tables, not in a static file. This enables API-driven CRUD and customer self-service via UI.

3. **`dim_campaigns` is maintained externally** — the Data Engineering team updates this table daily with all possible campaigns for each brand. Our application treats it as a read-only source of truth.

4. **A daily scheduled task keeps inclusions current** — the rule evaluation task (`rails inclusions:sync`) evaluates active inclusion rules against `dim_campaigns` and populates `campaign_id_inclusions` with any new matches. When the Data Engineering team adds new campaigns to `dim_campaigns`, the next sync automatically picks up any that match existing wildcard rules. The task is idempotent and additive. Customers can also manually include/exclude campaigns via the v2 API at any time.

5. **`campaign_id_inclusions` is the consumer-facing table** — data pipelines and downstream consumers query this table by `brand_id` + `platform_name` to understand which campaigns are included for each brand. The `platform_name` is denormalized from `dim_campaigns` so consumers don't need to join back.

6. **Clean cutover path** — once all consumers have migrated to v2, the v1 namespace, `ExclusionConfigurable` concern, and `exclusion_config.yaml` can be removed entirely.

---

## 6. Technical Changes Detail

### 6.1 Database Changes

Two new tables are introduced alongside the existing `dim_campaigns` table.

**`inclusion_rules`** (new) — Stores brand-level wildcard patterns that define which campaigns to include. One rule per brand (enforced by unique index on `brand_id`).

| Column | Type | Constraints | Purpose |
|--------|------|-------------|---------|
| id | bigint | PK | |
| brand_id | string | NOT NULL, indexed | Which brand this rule belongs to |
| wildcard | string | NOT NULL | SQL ILIKE pattern (e.g., `%Brand Search%`) |
| created_at | timestamp | | |
| updated_at | timestamp | | |

**`campaign_id_inclusions`** (new) — Materialized results of the exclusion-to-inclusion migration and manual inclusions.

| Column | Type | Constraints | Purpose |
|--------|------|-------------|---------|
| id | bigint | PK | |
| brand_id | string | NOT NULL | |
| platform_name | string | NOT NULL | Advertising platform (e.g., `facebook_ads`) |
| campaign_id | string | NOT NULL | References dim_campaigns.campaign_id |
| inclusion_rule_id | bigint | FK, nullable | Which rule included it (null = manual/migration inclusion) |
| created_at | timestamp | | |
| updated_at | timestamp | | |

**Indexes:**
- `campaign_id_inclusions [brand_id, platform_name, campaign_id]` — unique, prevents duplicate inclusions and enables idempotent upserts
- `campaign_id_inclusions [brand_id, platform_name]` — optimizes data pipeline lookups
- `inclusion_rules [brand_id]` — unique (enforces one rule per brand)

There is no dedicated `brands` table. A brand is identified by its `brand_id` across `campaign_id_inclusions` and `inclusion_rules`. The v2 brands endpoint queries both tables to build the brand view.

`platform_name` is denormalized from `dim_campaigns` so the data pipeline can look up included campaigns by `brand_id` + `platform_name` directly, without joining back to `dim_campaigns`.

### 6.2 API Changes

#### New Routes

Added under the `api/v2` namespace in `config/routes.rb`. **v1 routes remain untouched.**

```ruby
# config/routes.rb (additions)
namespace :v2 do
  resources :brands, param: :brand_id, only: [:index, :show, :create, :update, :destroy]
end
```

#### New Endpoints (v2 Brands CRUD)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v2/brands` | List all brands with their inclusion rule and included campaigns |
| GET | `/api/v2/brands/:brand_id` | Show one brand's inclusion rule and included campaigns |
| POST | `/api/v2/brands/:brand_id` | Create brand with wildcard and/or campaigns |
| PATCH | `/api/v2/brands/:brand_id` | Update brand's wildcard and/or add campaigns |
| DELETE | `/api/v2/brands/:brand_id` | Remove brand (its inclusion rule + all included campaigns) |

Each brand has at most **one** inclusion rule (wildcard). The `inclusion_rule_id` links the brand and its campaigns to that rule.

#### Request/Response Examples

**Create a brand with wildcard and campaigns:**
```bash
curl -X POST "http://localhost:3000/api/v2/brands/B1" \
  -H "Content-Type: application/json" \
  -d '{"wildcard": "%Search%", "campaigns": ["campaign_7", "campaign_8"]}'
```

**Update a brand's wildcard or add campaigns:**
```bash
curl -X PATCH "http://localhost:3000/api/v2/brands/B1" \
  -H "Content-Type: application/json" \
  -d '{"wildcard": "%Launch%", "campaigns": ["campaign_9"]}'
```

**Response format:**
```json
{
  "brand_id": "B1",
  "inclusion_rule_id": 1,
  "campaigns": [
    { "id": 1, "campaign_id": "campaign_7", "platform_name": "pinterest_ads", "inclusion_rule_id": 1 },
    { "id": 2, "campaign_id": "campaign_8", "platform_name": "pinterest_ads", "inclusion_rule_id": 1 }
  ]
}
```

A brand is not a dedicated table — it exists when it has records in `campaign_id_inclusions` or `inclusion_rules`. The v2 brands endpoint queries both tables to build the response. The `wildcard` is stored on the `inclusion_rules` record but not exposed in the response — only the `inclusion_rule_id` is returned.

#### Models

```ruby
# api/app/models/inclusion_rule.rb (existing, updated with association)
class InclusionRule < ApplicationRecord
  has_many :included_campaigns, class_name: 'IncludedCampaign', dependent: :nullify

  validates :brand_id, :wildcard, presence: true
  validates :brand_id, uniqueness: { message: 'already has an inclusion rule' }

  def matching_campaigns
    Campaign.where('campaign_name ILIKE ?', wildcard)
  end
end
```

```ruby
# api/app/models/included_campaign.rb (new)
class IncludedCampaign < ApplicationRecord
  self.table_name = 'campaign_id_inclusions'

  belongs_to :inclusion_rule, optional: true
  belongs_to :campaign, primary_key: :campaign_id, foreign_key: :campaign_id
end
```

### 6.3 Migration Script

Two standalone Python scripts handle the one-time migration from exclusion to inclusion data. Neither requires Rails — they run outside the API container.

**Step 1 — Generate the inclusion CSV** (no database needed):

```bash
python3 scripts/migrate_exclusions_to_inclusions.py \
  --campaigns data/dim_campaign.csv \
  --exclusions data/exclusion_config.yaml \
  --output data/campaign_id_inclusions.csv
```

Reads `dim_campaign.csv` and `exclusion_config.yaml`, inverts the exclusion rules, and writes the result to `campaign_id_inclusions.csv` with columns: `brand_id`, `platform_name`, `campaign_id`.

The script considers **all** campaigns in `dim_campaign.csv` for each brand, not just campaigns originally belonging to that brand. For example, if B1 excludes campaigns 1-6, then campaigns 7-30 (across all platforms and original brands) are included for B1.

**Step 2 — Import the CSV into PostgreSQL:**

```bash
python3 scripts/import_inclusions.py \
  --csv data/campaign_id_inclusions.csv \
  --database-url postgres://prescient:prescient@localhost:5432/prescient_development
```

Uses `ON CONFLICT DO NOTHING` on the unique index `(brand_id, platform_name, campaign_id)`, making it safe to run multiple times.

### 6.4 Scheduled Task

For ongoing inclusion syncing (evaluating wildcard rules against `dim_campaigns`), a rake task runs on a daily cron:

```bash
# Included in the container via api/crontab (runs daily at midnight)
0 0 * * * cd /app && bundle exec rails inclusions:sync

# Manual invocation
docker compose exec api bundle exec rails inclusions:sync
```

The sync task calls `InclusionSyncService`, which executes the following SQL:

```sql
INSERT INTO campaign_id_inclusions
  (brand_id, platform_name, campaign_id, inclusion_rule_id, created_at, updated_at)
SELECT DISTINCT ON (ir.brand_id, dc.platform_name, dc.campaign_id)
  ir.brand_id,
  dc.platform_name,
  dc.campaign_id,
  ir.id,
  NOW(),
  NOW()
FROM inclusion_rules ir
JOIN dim_campaigns dc ON dc.campaign_name ILIKE ir.wildcard
ORDER BY ir.brand_id, dc.platform_name, dc.campaign_id, ir.id
ON CONFLICT (brand_id, platform_name, campaign_id) DO NOTHING
```

How it works:

1. **JOIN** — matches each inclusion rule's wildcard pattern against campaign names in `dim_campaigns` using `ILIKE` (case-insensitive). For example, a rule with wildcard `%Search%` matches any campaign whose name contains "Search".
2. **DISTINCT ON** — when multiple rules for the same brand match the same campaign, only one row is kept (the one with the lowest `ir.id`), preventing duplicate insertions.
3. **ON CONFLICT DO NOTHING** — if the `(brand_id, platform_name, campaign_id)` combination already exists in `campaign_id_inclusions` (from a prior sync or manual API insertion), the row is skipped. This makes the task idempotent and additive — it only ever adds new matches, never duplicates or overwrites.

**Alternative scheduling options:**

```bash
# Heroku Scheduler
rails inclusions:sync

# Kubernetes CronJob
spec:
  schedule: "0 0 * * *"
  jobTemplate:
    spec:
      containers:
      - command: ["bundle", "exec", "rails", "inclusions:sync"]
```

---

## 7. Frontend & UI Considerations

This section describes how a frontend application would interact with the API to build a campaign inclusion management dashboard.

### 7.1 UI Flow Overview

```mermaid
flowchart TB
    subgraph "Dashboard"
        BS["Brand Selector\n(dropdown)"]
        CL["Campaign List\n(table)"]
        SF["Search & Filter\n(text + platform)"]
        RM["Rule Manager\n(wildcard input)"]
    end

    BS -->|"GET /api/v2/brands"| API
    BS -->|"user selects brand"| CL
    CL -->|"GET /api/v2/brands/:brand_id"| API
    SF -->|"GET /api/v1/campaigns?search=&platform_name="| API
    RM -->|"POST or PATCH /api/v2/brands/:brand_id"| API

    API["Rails API"]
```

### 7.2 Loading the Dashboard

When the dashboard loads, two calls populate the initial UI:

```mermaid
sequenceDiagram
    participant UI as Frontend
    participant API as Rails API

    UI->>API: GET /api/v1/campaigns/platforms
    API-->>UI: { platforms: ["facebook_ads", "google_ads", "pinterest_ads"] }

    UI->>API: GET /api/v2/brands
    API-->>UI: [{ brand_id: "B1", inclusion_rule_id: 1, campaigns: [...] }, ...]
```

| Call | Purpose | Populates |
|------|---------|-----------|
| `GET /api/v1/campaigns/platforms` | Fetch all available platforms | Platform filter dropdown |
| `GET /api/v2/brands` | Fetch all brands with their included campaigns | Brand selector dropdown |

### 7.3 Selecting a Brand

When a user selects a brand from the dropdown, fetch that brand's detail:

```mermaid
sequenceDiagram
    participant UI as Frontend
    participant API as Rails API

    UI->>API: GET /api/v2/brands/B1
    API-->>UI: { brand_id: "B1", inclusion_rule_id: 1, campaigns: [{campaign_id, platform_name, inclusion_rule_id}, ...] }

    Note over UI: Display campaigns in table
    Note over UI: Show inclusion_rule_id badge if campaign was added by rule
```

The response includes every included campaign for that brand. Each campaign's `inclusion_rule_id` tells the UI whether it was added by a wildcard rule (non-null) or manually (null).

### 7.4 Searching for Campaigns to Add

To let users browse available campaigns and add them to a brand, use the v1 campaigns endpoint:

```mermaid
sequenceDiagram
    participant UI as Frontend
    participant API as Rails API

    UI->>API: GET /api/v1/campaigns?search=Search&platform_name=google_ads
    API-->>UI: { campaigns: [...], meta: { total: 5, config_applied: false } }

    Note over UI: Display search results
    Note over UI: User selects campaigns to include
    UI->>API: PATCH /api/v2/brands/B1 { campaigns: ["campaign_13", "campaign_14"] }
    API-->>UI: { brand_id: "B1", inclusion_rule_id: 1, campaigns: [...updated list...] }
```

| Query param | Purpose | Example |
|-------------|---------|---------|
| `search` | Filter campaigns by name (case-insensitive, partial match) | `?search=Launch` |
| `platform_name` | Filter by advertising platform | `?platform_name=google_ads` |
| `brand_id` | Filter by brand | `?brand_id=B1` |
| `company_id` | Filter by company | `?company_id=C1` |

### 7.5 Managing Inclusion Rules (Wildcards)

Each brand can have **one** wildcard rule that automatically includes matching campaigns. The UI should provide an input for the wildcard pattern:

```mermaid
sequenceDiagram
    participant UI as Frontend
    participant API as Rails API

    Note over UI: User sets wildcard: %Search% and adds a campaign
    UI->>API: PATCH /api/v2/brands/B1 { wildcard: "%Search%", campaigns: ["campaign_8"] }
    API-->>UI: { brand_id: "B1", inclusion_rule_id: 1, campaigns: [...updated list...] }

    Note over UI: User changes the wildcard
    UI->>API: PATCH /api/v2/brands/B1 { wildcard: "%Launch%" }
    API-->>UI: { brand_id: "B1", inclusion_rule_id: 1, campaigns: [...] }
```

- **POST** creates a new brand — fails if the brand already exists
- **PATCH** updates an existing brand — can change the wildcard, add campaigns, or both
- The wildcard uses SQL `ILIKE` syntax: `%` matches any sequence of characters (e.g., `%Search%` matches "Brand Search", "Search Campaign", etc.)
- The nightly sync (`rails inclusions:sync`) evaluates the wildcard against `dim_campaigns` and adds any new matches to `campaign_id_inclusions`. Manual API changes take effect immediately.

### 7.6 Deleting a Brand

```mermaid
sequenceDiagram
    participant UI as Frontend
    participant API as Rails API

    Note over UI: User clicks delete, confirm dialog shown
    UI->>API: DELETE /api/v2/brands/B1
    API-->>UI: 204 No Content

    Note over UI: Remove brand from dropdown, clear campaign list
```

`DELETE` removes the brand's inclusion rule **and** all its included campaigns. This is irreversible — the UI should show a confirmation dialog before sending the request.

### 7.7 Endpoint Reference for Frontend

| UI Action | Endpoint | Method |
|-----------|----------|--------|
| Load platform filter | `/api/v1/campaigns/platforms` | GET |
| Load brand dropdown | `/api/v2/brands` | GET |
| Select a brand | `/api/v2/brands/:brand_id` | GET |
| Search available campaigns | `/api/v1/campaigns?search=&platform_name=` | GET |
| Create a brand with rule/campaigns | `/api/v2/brands/:brand_id` | POST |
| Update rule or add campaigns | `/api/v2/brands/:brand_id` | PATCH |
| Delete a brand | `/api/v2/brands/:brand_id` | DELETE |
