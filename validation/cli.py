"""
CLI entrypoint. Run from inside validation/ (flat imports, no package init):

Examples:
  python cli.py --window last7d --metrics pc_completed,deals_won
  python cli.py --window yesterday --all
  python cli.py --window last30d --all --owner 82672208
  python cli.py --metric pc_completed --owner 82672208 --window last7d --mode audit
  python cli.py --window last7d --all --output out.csv
"""

import argparse
import sys

import report
from hubspot_client import HubSpotAuthError
from metrics import load_derived_metrics, load_metrics
from runner import resolve_window, run_all, run_audit


def main():
    parser = argparse.ArgumentParser(description="Validate Renewal Closer dashboard metrics: Snowflake vs HubSpot")
    parser.add_argument("--metrics", help="comma-separated metric ids")
    parser.add_argument("--metric", help="single metric id (used with --mode audit)")
    parser.add_argument("--all", action="store_true", help="run every declared metric (base + derived)")
    parser.add_argument("--window", default="yesterday", help="today|yesterday|last7d|last14d|last30d|mtd|custom")
    parser.add_argument("--start", help="required if --window custom")
    parser.add_argument("--end", help="required if --window custom")
    parser.add_argument("--owner", help="closer owner_id; omit for team-level totals")
    parser.add_argument("--mode", default="aggregate", choices=["aggregate", "audit"])
    parser.add_argument("--output", help="write CSV (aggregate mode) to this path; .json also supported")
    args = parser.parse_args()

    if args.window == "today":
        print("note: --window today includes same-day Fivetran sync lag; discrepancies may be expected, not bugs.", file=sys.stderr)

    try:
        if args.mode == "audit":
            if not args.metric:
                parser.error("--mode audit requires --metric")
            start, end = resolve_window(args.window, args.start, args.end)
            result = run_audit(args.metric, start, end, args.owner)
            report.print_audit(result)
            return

        if args.all:
            metric_ids = list(load_metrics().keys()) + list(load_derived_metrics().keys())
        elif args.metrics:
            metric_ids = [m.strip() for m in args.metrics.split(",")]
        else:
            parser.error("provide --metrics, --all, or --mode audit with --metric")

        results = run_all(metric_ids, args.window, args.owner, args.start, args.end)
        report.print_console(results)

        if args.output:
            if args.output.endswith(".json"):
                report.write_json(results, args.output)
            else:
                report.write_csv(results, args.output)
            print(f"\nwrote {args.output}")

    except HubSpotAuthError as e:
        print(f"error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    sys.exit(main())
