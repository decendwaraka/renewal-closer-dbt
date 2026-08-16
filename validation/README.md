# Renewal Closer validation framework

Compares Renewal Closer dashboard metrics between `PRODUCTION.RENEWAL_MARTS`
(Snowflake) and live HubSpot. Seeded from this codebase's metric glossary
(`metric-catalog.ts`, `source/dashboard_formula.md`, the dbt seeds) — **not**
from the real live-HubSpot-dashboard's actual filter list, which doesn't
exist yet. When that list arrives, this is where it goes.

## Setup

```
pip install -r requirements.txt
```

Snowflake auth is reused as-is from `scripts/snowflake_client.py` (key-pair,
same account/role as `~/.dbt/profiles.yml`) — nothing to configure.

HubSpot needs its own credential (the MCP HubSpot connector used in chat is
session-auth'd and can't be used from a standalone script):

1. HubSpot → Settings → Integrations → Private Apps → create one.
2. Grant read-only scopes: `crm.objects.deals.read`, `crm.objects.contacts.read`,
   `crm.objects.owners.read`, `crm.schemas.deals.read`, and meetings-engagement
   read access (confirm the exact scope name at creation time).
3. `export HUBSPOT_PRIVATE_APP_TOKEN=...` (or put it in an untracked `.env` —
   never commit it; `.env` must be gitignored).
4. Rotate the token after heavy use.

**Before the first real run**, confirm every property name marked `# CONFIRM`
in `config/metrics.yaml` against HubSpot's live schema (`get_properties`/
`search_properties`) — Fivetran's staging aliases are not always the live
HubSpot API name verbatim (e.g. `property_upsell_close_date` in Snowflake is
`upsell___close_date` in HubSpot, already confirmed; several others in this
file are still best guesses).

## Running

Run from inside `validation/` (flat imports, no package `__init__.py`):

```
python cli.py --window last7d --metrics pc_completed,deals_won
python cli.py --window yesterday --all
python cli.py --window last30d --all --owner 82672208
python cli.py --metric pc_completed --owner 82672208 --window last7d --mode audit
python cli.py --window last7d --all --output out.csv
```

Default window is **yesterday**, not today — same-day Fivetran sync lag
produces false-positive gaps (documented repeatedly in project memory).
`--window today` works but prints a warning.

Omit `--owner` for team-level totals; pass a `dim_closers.csv` `owner_id` for
a single closer.

## Adding or updating a metric

Everything lives in `config/metrics.yaml`. Each entry declares:
- `snowflake.sql` — a parametrized query (`%(start)s`/`%(end)s`/`%(owner_id)s`)
  against the mart, returning a single `value` column.
- `hubspot` — object type, filters (`:start`/`:end`/`:owner_id` placeholders),
  and `aggregation` (`count` or `sum_dated_components`).
- `comparison` — `exact` (with a tolerance) or `ratio_tolerant`.
- `caveats` — anything already known (sync lag, deal-stage-basis vs
  meeting-basis, etc.) so the report can label expected drift correctly.

Ratios (Book%/Show%/Close%/DPL/Live Close%) are declared under `derived:`
instead — a formula string referencing other metric ids, evaluated
independently on each side after the base metrics run. HubSpot's search API
has no native division, so ratios are never queried directly.

Pipeline Snapshot metrics (`pipeline_snapshot.<snapshot_col>`) are **not**
hand-written in the YAML — `metrics.py` generates one per distinct
`snapshot_col` in `seeds/dim_renewal_stages.csv` directly, so they can never
drift from the seed that drives the actual dbt mart. Run
`python -c "from metrics import load_metrics; print(sorted(load_metrics()))"`
to see the full generated list.

### Swapping in the real HubSpot-dashboard filter list

When the user supplies the actual filters the live HubSpot dashboard uses:
edit only the `hubspot:` block (or `base_filters:`/`components:` for cash
metrics) of the relevant metric id(s). `runner.py`/`compare.py`/`cli.py`
don't reference metric-specific logic and need no changes.

## Audit mode

`--mode audit` does a record-level diff (gold-standard check, reused from
the `validate-metric` skill's Step 3): pulls the exact ID list from Snowflake
for a window, fetches matching HubSpot records, and reports IDs present on
only one side. Currently wired for `deals_won`, `pc_completed`,
`rc_completed`, `pwc_completed` (see `runner.AUDIT_SUPPORTED`) — these are
the metrics with a clean single id column to enumerate. Extend
`AUDIT_SUPPORTED` in `runner.py` to add more.

## PII

Persisted output (`--output`) never carries customer names/emails — every
metric definition requests only IDs and numeric/enum properties. Keep new
metrics to that convention; if a future check genuinely needs a name/email
field, fetch it for console display only and never pass it to
`report.write_csv`/`write_json`.
