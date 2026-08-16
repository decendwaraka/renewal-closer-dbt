"""
Minimal HubSpot CRM v3 client for the validation framework.

Auth: HUBSPOT_PRIVATE_APP_TOKEN env var only. No default/fallback token --
fail loudly if it's unset rather than silently querying with no auth.

Uses the search API's `total` for counts rather than HubSpot's grouped
"reporting" aggregation -- the latter was found off-by-one against ground
truth during manual validation (see project memory, call-outcomes-live-
validation). For sums, there is no native aggregation in the v3 search API,
so matching records are paged in full and summed client-side.
"""

import os
import time

import requests

BASE_URL = "https://api.hubapi.com"
PAGE_SIZE = 200
_OPERATOR_MAP = {
    "EQ": "EQ",
    "IN": "IN",
    "BETWEEN": "BETWEEN",
    "GT": "GT",
    "GTE": "GTE",
    "LT": "LT",
    "LTE": "LTE",
    "HAS_PROPERTY": "HAS_PROPERTY",
}


class HubSpotAuthError(RuntimeError):
    pass


def _token():
    token = os.environ.get("HUBSPOT_PRIVATE_APP_TOKEN")
    if not token:
        raise HubSpotAuthError(
            "HUBSPOT_PRIVATE_APP_TOKEN is not set. Create a HubSpot Private App "
            "(read-only CRM scopes) and export the token before running validation "
            "-- see validation/README.md."
        )
    return token


def _headers():
    return {
        "Authorization": f"Bearer {_token()}",
        "Content-Type": "application/json",
    }


def _build_filter(f):
    operator = _OPERATOR_MAP[f["operator"]]
    filt = {"propertyName": f["property"], "operator": operator}
    if operator == "IN":
        filt["values"] = f["value"]
    elif operator == "BETWEEN":
        filt["value"], filt["highValue"] = f["value"]
    elif operator == "HAS_PROPERTY":
        pass
    else:
        filt["value"] = f["value"]
    return filt


def _post_search(object_type, filters, properties, limit, after=None):
    url = f"{BASE_URL}/crm/v3/objects/{object_type}/search"
    body = {
        "filterGroups": [{"filters": [_build_filter(f) for f in filters]}],
        "properties": properties or [],
        "limit": limit,
    }
    if after:
        body["after"] = after

    resp = requests.post(url, headers=_headers(), json=body, timeout=30)
    if resp.status_code == 429:
        time.sleep(1)
        resp = requests.post(url, headers=_headers(), json=body, timeout=30)
    resp.raise_for_status()
    return resp.json()


def count(object_type, filters):
    """Exact count of matching records via search `total` (limit=1, no properties)."""
    data = _post_search(object_type, filters, properties=[], limit=1)
    return data["total"]


def list_records(object_type, filters, properties):
    """Page through every matching record, returning id + requested properties only.

    Caller is responsible for only requesting PII-safe properties (IDs / enums /
    numeric fields) when the result may be written to disk -- see report.py.
    """
    results = []
    after = None
    while True:
        data = _post_search(object_type, filters, properties=properties, limit=PAGE_SIZE, after=after)
        for r in data.get("results", []):
            results.append({"id": r["id"], **r.get("properties", {})})
        paging = data.get("paging", {}).get("next", {})
        after = paging.get("after")
        if not after:
            break
    return results


def batch_read(object_type, ids, properties):
    """Fetch specific records by ID (used for audit-mode record-level diffs)."""
    url = f"{BASE_URL}/crm/v3/objects/{object_type}/batch/read"
    out = []
    for i in range(0, len(ids), 100):
        chunk = ids[i : i + 100]
        body = {"properties": properties, "inputs": [{"id": _id} for _id in chunk]}
        resp = requests.post(url, headers=_headers(), json=body, timeout=30)
        resp.raise_for_status()
        for r in resp.json().get("results", []):
            out.append({"id": r["id"], **r.get("properties", {})})
    return out


def sum_dated_components(object_type, filters, components, start_et, end_et):
    """Sum component amounts whose own stamped date falls in [start_et, end_et].

    `components` is a list of {"amount_prop": ..., "date_prop": ...} dicts --
    mirrors int_renewal__deal_cash.sql's per-component date bucketing (each
    cash component is dated by its own stamped-date field, not the deal's
    close date). Returns (total, matched_record_count).
    """
    props = []
    for c in components:
        props.extend([c["amount_prop"], c["date_prop"]])
    records = list_records(object_type, filters, properties=sorted(set(props)))

    total = 0.0
    for rec in records:
        for c in components:
            date_val = rec.get(c["date_prop"])
            amount_val = rec.get(c["amount_prop"])
            if not date_val or not amount_val:
                continue
            date_str = date_val[:10]  # HubSpot dates come back as ISO datetime/date strings
            if start_et <= date_str <= end_et:
                total += float(amount_val)
    return total, len(records)
