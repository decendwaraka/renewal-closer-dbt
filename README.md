# Renewal Closer dbt

dbt project powering the **Renewal - Closer** dashboard. It transforms
Fivetran-landed HubSpot data in Snowflake into the marts that back the closer
leaderboards, call-outcome tables, cash breakdowns, and live pipeline snapshot.

The dashboard front end is a separate Lovable project that reads the marts in
this project's `PRODUCTION.RENEWAL_MARTS` schema directly.

## What it produces

Five reporting marts, all keyed by closer and pre-shaped for the dashboard:

| Mart | Grain | Feeds |
|---|---|---|
| `FCT_RENEWAL_CASH` | one row per cash component | Total Cash, Avg $ / Live Call, Cash by Pipeline Type |
| `FCT_RENEWAL_WON_DEALS` | one row per closed-won deal | Deals Won, Close % numerators |
| `FCT_RENEWAL_MEETINGS` | one row per meeting | Call Outcomes, Booking & Show Rates, Today Snapshot |
| `FCT_RENEWAL_PIPELINE_SNAPSHOT` | one row per closer × stage | HubSpot Pipeline Snapshot (live, not date-filtered) |
| `RPT_RENEWAL_CLOSER_DASHBOARD` | one row per closer | Today Snapshot cards (today's cash/deals) |

## Architecture

```
HubSpot (Fivetran) → MARKETING_DB.RAW      staging (views)      intermediate (ephemeral)     marts (tables)
  DEAL              ─────────────────────►  stg_renewal__deals   int_renewal__deal_cash   ──►  fct_renewal_cash
  ENGAGEMENT_MEETING                        stg_renewal__meetings int_renewal__meetings   ──►  fct_renewal_meetings
  OWNER                                                          int_renewal__won_deals   ──►  fct_renewal_won_deals
                                                                                               fct_renewal_pipeline_snapshot
                                                                                               rpt_renewal_closer_dashboard
```

- **staging** — one model per source table, light renaming/typing. Materialized as views in `RENEWAL_STAGING`.
- **intermediate** — business logic (cash assembly, meeting categorization, won-deal selection). Ephemeral; inlined into the marts.
- **marts** — dashboard-ready tables in `RENEWAL_MARTS`.

The custom `macros/generate_schema_name.sql` uses schema names verbatim (no
target-environment prefix), so production marts live at `PRODUCTION.RENEWAL_MARTS.*`.

## Layout

```
models/
  staging/        stg_renewal__deals, stg_renewal__meetings, _sources.yml
  intermediate/   int_renewal__deal_cash, __meetings, __won_deals
  marts/          fct_* and rpt_* models + _marts.yml
macros/
  effective_cash.sql          11-component cash assembly
  renewal_outcome_flags.sql   is_booked / is_completed / meeting_category flags
  to_et_date.sql              UTC -> America/New_York calendar-day bucketing
  generate_schema_name.sql    verbatim schema naming
seeds/
  dim_closers.csv         closer roster (HubSpot owner ids)
  dim_renewal_stages.csv  stage id -> snapshot column mapping
  dim_product_map.csv     upsell_plan -> product column (partly stubbed, see below)
  dim_targets.csv         editable dashboard goals
tests/
  assert_cash_nonnegative.sql
source/                   formula spec + tile-by-tile formula reference
```

## Key definitions

Configured as vars in `dbt_project.yml`:

- **Closers** — HubSpot owner ids `82672208, 756332149, 82734543, 756339074, 76930546`.
- **Renewal pipelines** — `95211801` (Renewal Sales) and `898243912` (Renewal).
- **Won stages** — `175346331` (PIF), `229787714` (Payment Plan), `1359841456` (Closed Won).
- **Cash** — 11-component sum (base collected + additional payments 1–10), each on its own stamped date.
- **Meeting categories** — PC (progress), RC (renewal), PWC (post-webinar), derived from `hs_activity_type`.
- **Dates** — bucketed to ET calendar days via `to_et_date`; dashboard windows are inclusive `BETWEEN start AND end`.

The full tile-to-SQL-to-HubSpot mapping for all 57 dashboard formulas lives in
[source/dashboard_formula.md](source/dashboard_formula.md).

## Setup

Requires the `renewal_setter` profile (Snowflake, key-pair auth). `dev` targets
`DEVELOPMENT.renewal_dev_<user>`; `prod` targets `PRODUCTION`.

```bash
dbt deps
dbt seed
dbt build          # run + test
dbt build --target prod
```

## Known gaps

Tracked in `OPEN_ISSUES.md`. Current items affecting reported numbers:

- **Cash completeness** — warehouse cash carries base + AP1 + AP2 only (Fivetran gap); components 3–10 are not yet landed.
- **Product split** — `dim_product_map.csv` is partly stubbed (`UNMAPPED`), so the Cash-by-Pipeline product columns read $0 until the `upsell_plan -> product` mapping is finalized. The Total column is accurate.
- **Show% freshness** — the meeting source syncs roughly daily; calls dispositioned `SCHEDULED -> COMPLETED` in HubSpot after the last sync make Show% read a few points low versus live HubSpot.
- **Completed flag** — `is_completed` uses `LIKE 'COMPLETED%'`, which also counts COMPLETED-NURTURE / COMPLETED-QUALIFIED; a deviation from spec pending RevOps sign-off.
- **ET vs UTC bucketing** — day boundaries depend on `to_et_date`; edge-of-day meetings can shift between adjacent days versus a UTC view.
