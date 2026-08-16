"""Comparison strategies between a Snowflake value and a HubSpot value."""

from dataclasses import dataclass


@dataclass
class ComparisonResult:
    verdict: str        # "confirmed" | "discrepancy" | "not_checkable"
    snowflake_value: object
    hubspot_value: object
    detail: str = ""


def compare(mode, snowflake_value, hubspot_value, tolerance=0):
    if snowflake_value is None or hubspot_value is None:
        return ComparisonResult("not_checkable", snowflake_value, hubspot_value, "one side returned no data")

    sf = float(snowflake_value)
    hs = float(hubspot_value)

    if mode == "exact":
        if abs(sf - hs) <= tolerance:
            return ComparisonResult("confirmed", sf, hs)
        return ComparisonResult(
            "discrepancy", sf, hs, f"diff={sf - hs:+.2f} (tolerance={tolerance})"
        )

    if mode == "ratio_tolerant":
        if hs == 0 and sf == 0:
            return ComparisonResult("confirmed", sf, hs)
        if hs == 0 or sf == 0:
            return ComparisonResult("discrepancy", sf, hs, "one side is zero, ratio undefined")
        ratio = sf / hs
        if abs(ratio - 1) <= tolerance:
            return ComparisonResult("confirmed", sf, hs, f"ratio={ratio:.3f}")
        return ComparisonResult("discrepancy", sf, hs, f"ratio={ratio:.3f} outside tolerance={tolerance}")

    raise ValueError(f"unknown comparison mode: {mode}")


def audit_diff(snowflake_ids, hubspot_records):
    """Record-level diff for audit mode. Returns (missing_in_hubspot, extra_in_hubspot)."""
    sf_ids = set(str(i) for i in snowflake_ids)
    hs_ids = set(r["id"] for r in hubspot_records)
    return sorted(sf_ids - hs_ids), sorted(hs_ids - sf_ids)
