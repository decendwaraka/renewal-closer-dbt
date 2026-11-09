{{ config(severity='warn') }}
{#
    The deleted-meeting detector (renewal-setter scripts/detect_deleted_meetings.py, GitHub Actions)
    stopped running or stopped succeeding. New HubSpot deletions would then stay in
    stg_renewal__meetings and inflate DPL calls and Call Outcomes. Any row returned is a warning.

    Warn, not error: this reads no model and blocks nothing, and the detector's own workflow already
    fails loudly when it breaks.

    Recent: any successful run (recent window or full sweep) within 18 hours. The schedule is every
    6 hours, but GitHub delays scheduled runs by hours, so 18 hours means two or more missed slots.
    Full sweep: scheduled daily, so 48 hours without one is an outage.
    Success = exit_code 0, or 3 (finished with some ids unchecked; confirmed ones were written).
#}
WITH ok_runs AS (
    SELECT scope, run_at
    FROM {{ source('hubspot_raw', 'HUBSPOT_DELETED_MEETINGS_RUNS') }}
    WHERE exit_code IN (0, 3)
)

SELECT
    'no successful detector run in 18 hours' AS problem,
    MAX(run_at) AS last_success
FROM ok_runs
HAVING COALESCE(MAX(run_at), '1970-01-01'::TIMESTAMP_NTZ) < DATEADD(HOUR, -18, SYSDATE())

UNION ALL

SELECT
    'no successful full sweep in 48 hours' AS problem,
    MAX(CASE WHEN scope = 'full' THEN run_at END) AS last_success
FROM ok_runs
HAVING COALESCE(MAX(CASE WHEN scope = 'full' THEN run_at END), '1970-01-01'::TIMESTAMP_NTZ)
    < DATEADD(HOUR, -48, SYSDATE())
