"""
Console + CSV/JSON reporting. PII rule: persisted output (--output) carries
only HubSpot record IDs and numeric/enum values, never names/emails -- the
metric definitions never request name/email properties, so this holds as
long as new metrics follow the same convention (see README).
"""

import csv
import json

from tabulate import tabulate

# ASCII-only: Windows consoles default to cp1252, which can't encode
# checkmark/warning glyphs and crashes stdout mid-report.
VERDICT_ICON = {"confirmed": "OK", "discrepancy": "DIFF", "not_checkable": "--"}


def print_console(results):
    rows = []
    for r in results:
        res = r["result"]
        rows.append(
            [
                r["metric_id"],
                r["metric_name"],
                VERDICT_ICON[res.verdict],
                res.snowflake_value,
                res.hubspot_value,
                res.detail,
            ]
        )
    print(tabulate(rows, headers=["id", "name", "verdict", "snowflake", "hubspot", "detail"]))

    for r in results:
        if r["caveats"]:
            print(f"\n{r['metric_id']} caveats:")
            for c in r["caveats"]:
                print(f"  - {c}")


def write_csv(results, path):
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["metric_id", "metric_name", "verdict", "snowflake_value", "hubspot_value", "detail", "formula_refs"])
        for r in results:
            res = r["result"]
            writer.writerow(
                [r["metric_id"], r["metric_name"], res.verdict, res.snowflake_value, res.hubspot_value, res.detail, ";".join(r["formula_refs"])]
            )


def write_json(results, path):
    payload = []
    for r in results:
        res = r["result"]
        payload.append(
            {
                "metric_id": r["metric_id"],
                "metric_name": r["metric_name"],
                "verdict": res.verdict,
                "snowflake_value": res.snowflake_value,
                "hubspot_value": res.hubspot_value,
                "detail": res.detail,
                "formula_refs": r["formula_refs"],
                "caveats": r["caveats"],
            }
        )
    with open(path, "w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2)


def print_audit(audit_result):
    print(f"metric: {audit_result['metric_id']}  window: {audit_result['window']}  owner: {audit_result['owner_id']}")
    print(f"snowflake_count={audit_result['snowflake_count']}  hubspot_count={audit_result['hubspot_count']}")
    if audit_result["missing_in_hubspot"]:
        print(f"in Snowflake but not found live in HubSpot ({len(audit_result['missing_in_hubspot'])}):")
        print("  " + ", ".join(audit_result["missing_in_hubspot"]))
    if audit_result["extra_in_hubspot"]:
        print(f"live in HubSpot but not in Snowflake -- likely sync lag ({len(audit_result['extra_in_hubspot'])}):")
        print("  " + ", ".join(audit_result["extra_in_hubspot"]))
    if not audit_result["missing_in_hubspot"] and not audit_result["extra_in_hubspot"]:
        print("exact ID-level match.")
