"""
Thin wrapper around scripts/snowflake_client.py (key-pair auth, same
account/role/warehouse as ~/.dbt/profiles.yml) -- reused as-is, not
reimplemented. See scripts/snowflake_client.py for the auth details.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent / "scripts"))

from snowflake_client import get_connection  # noqa: E402


def run(sql, params=None, **overrides):
    """Run a parametrized query (pyformat: %(name)s) against PRODUCTION.RENEWAL_MARTS.

    Defaults to the prod database/schema used by the dashboard marts --
    pass database="DEVELOPMENT" explicitly to point at a dev target instead.
    """
    overrides.setdefault("database", "PRODUCTION")
    overrides.setdefault("schema", "RENEWAL_MARTS")
    conn = get_connection(**overrides)
    try:
        cur = conn.cursor()
        cur.execute(sql, params or {})
        columns = [c[0] for c in cur.description]
        rows = cur.fetchall()
        return columns, rows
    finally:
        conn.close()


def scalar(sql, params=None, **overrides):
    """Run a query expected to return a single row with a single `value` column."""
    columns, rows = run(sql, params, **overrides)
    if not rows:
        return None
    return rows[0][columns.index("value")]
