"""
Loads validation/config/metrics.yaml into Metric/DerivedMetric objects, and
auto-generates the Pipeline Snapshot metrics (#36-51, #58-68) directly from
seeds/dim_renewal_stages.csv -- one metric per distinct snapshot_col, grouped
by pipeline. Keeping this generated rather than hand-transcribed means it can
never drift from the seed that already drives the dbt mart.
"""

import csv
from dataclasses import dataclass, field
from pathlib import Path

import yaml

CONFIG_DIR = Path(__file__).parent / "config"
REPO_ROOT = Path(__file__).parent.parent


@dataclass
class Metric:
    id: str
    name: str
    formula_refs: list
    snowflake_sql: str
    hubspot: dict
    comparison: dict
    caveats: list = field(default_factory=list)


@dataclass
class DerivedMetric:
    id: str
    name: str
    formula_refs: list
    formula: str
    caveats: list = field(default_factory=list)


def _load_raw():
    with open(CONFIG_DIR / "metrics.yaml", "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def load_metrics():
    raw = _load_raw()
    metrics = {}
    for m in raw["metrics"]:
        metrics[m["id"]] = Metric(
            id=m["id"],
            name=m["name"],
            formula_refs=m.get("formula_refs", []),
            snowflake_sql=m["snowflake"]["sql"],
            hubspot=m["hubspot"],
            comparison=m["comparison"],
            caveats=m.get("caveats", []),
        )
    for snap_id, snap in _load_pipeline_snapshot_metrics(raw).items():
        metrics[snap_id] = snap
    return metrics


def load_derived_metrics():
    raw = _load_raw()
    return {
        d["id"]: DerivedMetric(
            id=d["id"],
            name=d["name"],
            formula_refs=d.get("formula_refs", []),
            formula=d["formula"],
            caveats=d.get("caveats", []),
        )
        for d in raw.get("derived", [])
    }


def load_closers():
    """Returns [{"owner_id": ..., "closer_name": ...}, ...] from the dbt seed."""
    path = REPO_ROOT / "seeds" / "dim_closers.csv"
    with open(path, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def _load_pipeline_snapshot_metrics(raw):
    """One metric per distinct snapshot_col in dim_renewal_stages.csv.

    Snowflake side: exact mirror of fct_renewal_pipeline_snapshot.sql (LIVE,
    not date-filtered -- these are current-state stage counts).
    HubSpot side: deals filtered by dealstage IN the stage_ids sharing that
    snapshot_col, scoped to the pipeline(s) those stages belong to.
    """
    path = REPO_ROOT / "seeds" / "dim_renewal_stages.csv"
    with open(path, newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))

    by_snapshot_col = {}
    for r in rows:
        by_snapshot_col.setdefault(r["snapshot_col"], []).append(r)

    metrics = {}
    for snapshot_col, stage_rows in by_snapshot_col.items():
        stage_ids = [r["stage_id"] for r in stage_rows]
        label = stage_rows[0]["stage_label"]
        metric_id = f"pipeline_snapshot.{snapshot_col}"
        metrics[metric_id] = Metric(
            id=metric_id,
            name=f"Pipeline Snapshot -- {label}",
            formula_refs=["#36-51,#58-68 (auto-generated, see dim_renewal_stages.csv)"],
            snowflake_sql=f"""
                SELECT SUM(deal_count) AS value
                FROM PRODUCTION.RENEWAL_MARTS.FCT_RENEWAL_PIPELINE_SNAPSHOT
                WHERE snapshot_col = '{snapshot_col}'
                  AND (%(owner_id)s IS NULL OR closer_owner_id = %(owner_id)s)
            """,
            hubspot={
                "object": "deals",
                "aggregation": "count",
                "filters": [
                    {"property": "dealstage", "operator": "IN", "value": stage_ids},
                    {"property": "hubspot_owner_id", "operator": "EQ", "value": ":owner_id"},
                ],
            },
            comparison={"mode": "exact", "tolerance": 0},
            caveats=["live/current-state count -- do not pass a date window, matches dashboard's Pipeline Snapshot tiles"],
        )
    return metrics
