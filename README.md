# Marketing Analytics Engineering Pipeline

An end-to-end analytics engineering pipeline that transforms raw marketing data — ad campaign metadata, daily ad costs, and site revenue — into a clean, analytics-ready mart with key marketing performance KPIs.

---

## Problem Statement

Marketing teams typically work with data scattered across multiple sources: ad platforms (impressions, clicks, costs) and web analytics tools (sessions, pageviews, revenue). Without a unified data model, answering fundamental questions like *"What is the ROAS of our Google Ads campaigns in Brazil?"* or *"Which channel delivers the lowest CPC?"* requires manual spreadsheet work prone to errors and inconsistency.

This pipeline solves that by creating a reliable, reproducible transformation layer that joins those sources daily, computes the core KPIs, and serves them from a single table ready for BI consumption.

---

## Stack

| Layer | Technology | Role |
|---|---|---|
| Ingestion | Python + `boto3` | Upload raw CSV files to AWS S3 |
| Storage | AWS S3 | Data lake landing zone |
| Data Warehouse | Snowflake | COPY INTO raw tables, query engine |
| Transformation | dbt (data build tool) | Multi-layer SQL modeling |
| Data Quality | dbt tests | `not_null` checks on primary keys |

### Why this stack?

- **S3** acts as a cost-effective, durable landing zone that decouples ingestion from the warehouse. Files can be re-loaded without touching the source.
- **Snowflake** handles storage and compute separation cleanly, auto-suspends the warehouse when idle (`XSMALL`, 60s auto-suspend), and natively integrates with S3 external stages via `COPY INTO`.
- **dbt** brings software engineering practices to SQL: version control, modularity, documentation, and automated testing. The three-layer architecture (Staging → Intermediate → Mart) ensures each layer has a single responsibility.

---

## Data Sources

Three raw CSV files are produced upstream (e.g., by an ad platform export or a marketing ops script):

| File | Description |
|---|---|
| `ads_campaigns.csv` | Campaign metadata: ID, name, channel, country, start date, status |
| `ads_costs.csv` | Daily cost metrics per campaign: impressions, clicks, cost |
| `site_revenue.csv` | Daily site metrics per campaign: sessions, pageviews, revenue |

---

## Data Flow

```
CSV files (local)
      │
      │  services/uploader_csv.py  (Python + boto3)
      ▼
AWS S3  (s3://BUCKET/marketing_data/raw/<dataset>/year=YYYY/month=MM/)
      │
      │  Snowflake COPY INTO  (snowflake/copy_into.sql)
      ▼
Snowflake — MARKETING_DB.RAW
  ├── RAW_ADS_CAMPAIGNS
  ├── RAW_ADS_COSTS
  └── RAW_SITE_REVENUE
      │
      │  dbt run
      ▼
MARKETING_DB.STAGING  (views)
  ├── stg_ads_campaigns   — light normalization (channel lowercased, country uppercased)
  ├── stg_ads_costs       — passthrough clean select
  └── stg_site_revenue    — passthrough clean select
      │
      ▼
MARKETING_DB.INTERMEDIATE  (views)
  └── int_campaign_daily_performance  — joins costs + revenue + campaign metadata by date & campaign_id
      │
      ▼
MARKETING_DB.MART  (table)
  └── mart_campaign_performance  — final KPIs, ready for BI tools
```

---

## dbt Model Layers

### Staging (`models/staging/`)

Thin views that read directly from Snowflake RAW sources. Responsibilities:

- Select only necessary columns
- Apply light normalization (`LOWER`, `UPPER`)
- Serve as the single reference point for raw source data

### Intermediate (`models/intermediate/`)

**`int_campaign_daily_performance`** — joins the three staging models on `campaign_id` and `date`:

```
stg_ads_costs  ──LEFT JOIN──  stg_site_revenue  (on date + campaign_id)
      └──────────LEFT JOIN──  stg_ads_campaigns  (on campaign_id)
```

Produces a unified daily-grain dataset with all raw metrics in one place.

### Mart (`models/mart/`)

**`mart_campaign_performance`** — materialized as a **table**. Adds the following computed KPIs on top of the intermediate model:

| KPI | Formula | Description |
|---|---|---|
| `profit` | `revenue - cost` | Net margin per campaign/day |
| `ctr` | `clicks / impressions` | Click-through rate |
| `cpc` | `cost / clicks` | Cost per click |
| `roas` | `revenue / cost` | Return on Ad Spend |
| `rpm` | `(revenue / sessions) × 1000` | Revenue per thousand sessions |
| `pages_per_session` | `pageviews / sessions` | Engagement depth |

All division-by-zero cases are handled with `CASE WHEN` guards that return `0`.

---

## Project Structure

```
├── data/raw/                      # Local raw CSV files
├── models/
│   ├── staging/                   # Source-aligned views
│   │   ├── sources.yaml           # dbt source declarations (MARKETING_DB.RAW)
│   │   ├── schema.yml             # Column-level tests
│   │   ├── stg_ads_campaigns.sql
│   │   ├── stg_ads_costs.sql
│   │   └── stg_site_revenue.sql
│   ├── intermediate/
│   │   └── int_campaign_daily_performance.sql
│   └── mart/
│       └── mart_campaign_performance.sql
├── macros/
│   └── generate_schema_name.sql   # Overrides dbt default schema naming
├── services/
│   └── uploader_csv.py            # S3 ingestion script
├── snowflake/
│   ├── setup.sql                  # DDL: database, schemas, warehouse, stage, raw tables
│   └── copy_into.sql              # Load S3 stage → Snowflake raw tables
└── dbt_project.yml
```

---

## Snowflake Schema Layout

```
MARKETING_DB
├── RAW          — raw tables loaded via COPY INTO from S3
├── STAGING      — dbt staging views
├── INTERMEDIATE — dbt intermediate views
└── MART         — dbt mart table (final analytics output)
```

---

## Getting Started

### Prerequisites

- Python 3.8+
- A Snowflake account
- An AWS account with an S3 bucket
- dbt Core with the Snowflake adapter (`dbt-snowflake`)

### 1. Install dependencies

```bash
pip install dbt-snowflake boto3 python-dotenv pandas
```

### 2. Configure environment variables

Create a `.env` file at the project root:

```env
BUCKET_NAME=your-s3-bucket-name
```

### 3. Set up Snowflake

Run `snowflake/setup.sql` in your Snowflake worksheet to create the database, schemas, warehouse, file format, raw tables, and S3 external stage. Update the stage credentials in that file with your AWS key and secret before running.

### 4. Configure the dbt profile

Add the following to your `~/.dbt/profiles.yml`:

```yaml
marketing_pipeline:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: <your_account>
      user: <your_user>
      password: <your_password>
      role: <your_role>
      database: MARKETING_DB
      warehouse: COMPUTE_WH
      schema: RAW
      threads: 4
```

### 5. Upload raw data to S3

```bash
python services/uploader_csv.py
```

Files are uploaded to a date-partitioned path: `marketing_data/raw/<dataset>/year=YYYY/month=MM/`.

### 6. Load data into Snowflake

Run the COPY INTO statements in your Snowflake worksheet (`snowflake/copy_into.sql`).

### 7. Run dbt

```bash
# Validate connections and configuration
dbt debug

# Build all models
dbt run

# Run data quality tests
dbt test
```

---

## Data Quality Tests

dbt tests are defined in `models/staging/schema.yml` and enforce:

| Model | Column | Test |
|---|---|---|
| `stg_ads_campaigns` | `campaign_id` | `not_null` |
| `stg_ads_costs` | `campaign_id` | `not_null` |
| `stg_site_revenue` | `campaign_id` | `not_null` |

Failed tests are surfaced in `target/run_results.json`.

---

## Output

The final mart table `MARKETING_DB.MART.MART_CAMPAIGN_PERFORMANCE` exposes one row per `(date, campaign_id)` with the following columns:

| Column | Type | Description |
|---|---|---|
| `date` | DATE | Reporting date |
| `campaign_id` | STRING | Campaign identifier |
| `campaign_name` | STRING | Human-readable campaign name |
| `channel` | STRING | Ad channel (google, meta, etc.) |
| `country` | STRING | Target country (ISO uppercased) |
| `impressions` | INT | Total ad impressions |
| `clicks` | INT | Total ad clicks |
| `cost` | FLOAT | Total ad spend |
| `sessions` | INT | Website sessions attributed |
| `pageviews` | INT | Total pageviews |
| `revenue` | FLOAT | Revenue attributed to campaign |
| `profit` | FLOAT | `revenue - cost` |
| `ctr` | FLOAT | Click-through rate |
| `cpc` | FLOAT | Cost per click |
| `roas` | FLOAT | Return on Ad Spend |
| `rpm` | FLOAT | Revenue per thousand sessions |
| `pages_per_session` | FLOAT | Average pages viewed per session |

This table is ready to be connected to any BI tool (Metabase, Looker, Power BI, Tableau, etc.) for dashboarding and ad-hoc analysis.
