"""
Orchestrates one metric end-to-end: run the Snowflake side, run the HubSpot
side, compare, return a result. Also handles window-preset resolution and
audit-mode (record-level) checks for the metric ids that have a
straightforward id column to enumerate.
"""

from datetime import date, timedelta

import compare
import hubspot_client
import snowflake_source
from metrics import load_closers, load_derived_metrics, load_metrics

WINDOW_PRESETS = {"today", "yesterday", "last7d", "last14d", "last30d", "mtd"}

# Metric id -> (snowflake id-column query template, hubspot object, hubspot id property is always "id")
AUDIT_SUPPORTED = {
    "deals_won": (
        "SELECT deal_id FROM PRODUCTION.RENEWAL_MARTS.FCT_RENEWAL_WON_DEALS "
        "WHERE close_date_et BETWEEN %(start)s AND %(end)s "
        "AND (%(owner_id)s IS NULL OR closer_owner_id = %(owner_id)s)",
        "deals",
    ),
    "pc_completed": (
        "SELECT meeting_id FROM PRODUCTION.RENEWAL_MARTS.FCT_RENEWAL_MEETINGS "
        "WHERE meeting_category = 'PC' AND is_completed "
        "AND meeting_date_et BETWEEN %(start)s AND %(end)s "
        "AND (%(owner_id)s IS NULL OR closer_owner_id = %(owner_id)s)",
        "meetings",
    ),
    "rc_completed": (
        "SELECT meeting_id FROM PRODUCTION.RENEWAL_MARTS.FCT_RENEWAL_MEETINGS "
        "WHERE meeting_category = 'RC' AND is_completed "
        "AND meeting_date_et BETWEEN %(start)s AND %(end)s "
        "AND (%(owner_id)s IS NULL OR closer_owner_id = %(owner_id)s)",
        "meetings",
    ),
    "pwc_completed": (
        "SELECT meeting_id FROM PRODUCTION.RENEWAL_MARTS.FCT_RENEWAL_MEETINGS "
        "WHERE meeting_category = 'PWC' AND is_completed "
        "AND meeting_date_et BETWEEN %(start)s AND %(end)s "
        "AND (%(owner_id)s IS NULL OR closer_owner_id = %(owner_id)s)",
        "meetings",
    ),
}


def resolve_window(window, custom_start=None, custom_end=None):
    """Returns (start, end) as 'YYYY-MM-DD' ET-calendar-day strings.

    Default convention (per project memory): cut off at yesterday, not today,
    to avoid same-day Fivetran sync-lag false positives.
    """
    today = date.today()
    yesterday = today - timedelta(days=1)

    if window == "custom":
        if not (custom_start and custom_end):
            raise ValueError("window=custom requires --start/--end")
        return custom_start, custom_end
    if window == "today":
        return str(today), str(today)
    if window == "yesterday":
        return str(yesterday), str(yesterday)
    if window == "last7d":
        return str(yesterday - timedelta(days=6)), str(yesterday)
    if window == "last14d":
        return str(yesterday - timedelta(days=13)), str(yesterday)
    if window == "last30d":
        return str(yesterday - timedelta(days=29)), str(yesterday)
    if window == "mtd":
        return str(yesterday.replace(day=1)), str(yesterday)
    raise ValueError(f"unknown window: {window} (expected one of {WINDOW_PRESETS} or 'custom')")


def _resolve_placeholders(value, start, end, owner_id):
    sub = {":start": start, ":end": end, ":owner_id": owner_id}
    if isinstance(value, str) and value in sub:
        return sub[value]
    if isinstance(value, list):
        return [_resolve_placeholders(v, start, end, owner_id) for v in value]
    return value


def _resolve_filters(filters, start, end, owner_id):
    resolved = []
    for f in filters:
        rf = dict(f)
        rf["value"] = _resolve_placeholders(f.get("value"), start, end, owner_id)
        resolved.append(rf)
    return [f for f in resolved if not (f["property"] == "hubspot_owner_id" and f["value"] is None)]


def run_hubspot_side(metric, start, end, owner_id):
    hs = metric.hubspot
    aggregation = hs["aggregation"]

    if aggregation == "count":
        filters = _resolve_filters(hs["filters"], start, end, owner_id)
        return hubspot_client.count(hs["object"], filters), None

    if aggregation == "sum_dated_components":
        filters = _resolve_filters(hs["base_filters"], start, end, owner_id)
        total, matched = hubspot_client.sum_dated_components(
            hs["object"], filters, hs["components"], start, end
        )
        return total, matched

    raise ValueError(f"unknown hubspot aggregation: {aggregation}")


def run_metric(metric, start, end, owner_id=None):
    sf_value = snowflake_source.scalar(
        metric.snowflake_sql, {"start": start, "end": end, "owner_id": owner_id}
    )
    hs_value, matched_count = run_hubspot_side(metric, start, end, owner_id)

    result = compare.compare(
        metric.comparison["mode"], sf_value, hs_value, metric.comparison.get("tolerance", 0)
    )
    return {
        "metric_id": metric.id,
        "metric_name": metric.name,
        "owner_id": owner_id,
        "window": (start, end),
        "result": result,
        "caveats": metric.caveats,
        "formula_refs": metric.formula_refs,
        "hubspot_matched_count": matched_count,
    }


def run_derived(derived, base_results_by_id):
    """base_results_by_id: {metric_id: {"snowflake": x, "hubspot": y}}"""
    import re

    def eval_side(side):
        expr = derived.formula
        for metric_id in re.findall(r"[a-zA-Z_][a-zA-Z0-9_.]*", expr):
            if metric_id in base_results_by_id:
                expr = re.sub(rf"\b{re.escape(metric_id)}\b", str(base_results_by_id[metric_id][side]), expr)
        return eval(expr)  # noqa: S307 -- expr is built from our own YAML formulas + numeric substitutions only

    try:
        sf_value = eval_side("snowflake")
        hs_value = eval_side("hubspot")
    except ZeroDivisionError:
        return {
            "metric_id": derived.id,
            "metric_name": derived.name,
            "result": compare.ComparisonResult("not_checkable", None, None, "division by zero"),
            "caveats": derived.caveats,
            "formula_refs": derived.formula_refs,
        }

    result = compare.compare("ratio_tolerant", sf_value, hs_value, tolerance=0.02)
    return {
        "metric_id": derived.id,
        "metric_name": derived.name,
        "result": result,
        "caveats": derived.caveats,
        "formula_refs": derived.formula_refs,
    }


def _dependency_ids(formula, known_metric_ids):
    import re

    return [m for m in re.findall(r"[a-zA-Z_][a-zA-Z0-9_.]*", formula) if m in known_metric_ids]


def run_all(metric_ids, window, owner_id=None, custom_start=None, custom_end=None):
    start, end = resolve_window(window, custom_start, custom_end)
    metrics = load_metrics()
    derived_metrics = load_derived_metrics()

    # A derived metric (e.g. pc_close_pct) needs its base metrics (deals_won,
    # pc_completed) fetched even if the caller only asked for the ratio --
    # expand the fetch list so `--metrics pc_close_pct` alone doesn't crash
    # on an undefined name inside run_derived's eval().
    requested = list(metric_ids)
    to_fetch = set(m for m in requested if m in metrics)
    for metric_id in requested:
        if metric_id in derived_metrics:
            to_fetch.update(_dependency_ids(derived_metrics[metric_id].formula, metrics.keys()))

    base_results = {}
    results = []
    fetched_but_not_requested = to_fetch - set(requested)
    for metric_id in to_fetch:
        r = run_metric(metrics[metric_id], start, end, owner_id)
        base_results[metric_id] = {"snowflake": r["result"].snowflake_value, "hubspot": r["result"].hubspot_value}
        if metric_id not in fetched_but_not_requested:
            results.append(r)

    for metric_id in requested:
        if metric_id in derived_metrics:
            d = derived_metrics[metric_id]
            results.append(run_derived(d, base_results))

    return results


def run_audit(metric_id, start, end, owner_id):
    if metric_id not in AUDIT_SUPPORTED:
        raise ValueError(
            f"audit mode not wired for '{metric_id}' -- supported: {sorted(AUDIT_SUPPORTED)}"
        )
    sql, hs_object = AUDIT_SUPPORTED[metric_id]
    columns, rows = snowflake_source.run(sql, {"start": start, "end": end, "owner_id": owner_id})
    sf_ids = [row[0] for row in rows]

    metrics = load_metrics()
    metric = metrics[metric_id]
    filters = _resolve_filters(metric.hubspot["filters"], start, end, owner_id)
    hs_records = hubspot_client.list_records(hs_object, filters, properties=[])

    missing_in_hubspot, extra_in_hubspot = compare.audit_diff(sf_ids, hs_records)
    return {
        "metric_id": metric_id,
        "window": (start, end),
        "owner_id": owner_id,
        "snowflake_count": len(sf_ids),
        "hubspot_count": len(hs_records),
        "missing_in_hubspot": missing_in_hubspot,   # snowflake IDs not found live -- deleted/moved in HubSpot
        "extra_in_hubspot": extra_in_hubspot,        # hubspot IDs not in the warehouse -- sync lag
    }
