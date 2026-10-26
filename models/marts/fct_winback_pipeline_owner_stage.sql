{{ config(materialized='view') }}

-- Winback Pipeline Snapshot: every deal in the Winbacks Pipeline (917643668), by deal owner and CURRENT
-- deal stage, dated by the deal's create date. Replicates the HubSpot report of the same name cell for
-- cell (all-time, 2026-10-26): 39 of 40 cells exact against live HubSpot; the one difference was a deal
-- moved after the last Fivetran sync.
--
-- Same shape as fct_renewal_pipeline_owner_stage: one row per deal carrying create_date_et, counts are
-- COUNT(*) at query time, and an (owner, stage) cell with no deals has NO row -- the consumer zero-fills.
--
-- Differs from the Renewal model in the owner rule. The HubSpot report's second filter group is
-- "Deal owner is unknown", and ~500 Winback deals have no owner, so unowned deals are kept under
-- closer_name 'Unassigned' (closer_owner_id NULL) instead of being dropped by an inner join. Owners that
-- are neither a team closer nor blank (Henna Shakoor, off the team, and a handful of one-off owners) are
-- outside the report's owner filter and stay excluded.
--
-- No test-contact filter, matching the report.

WITH deals AS (
    SELECT deal_id, closer_owner_id, dealstage_id, created_at
    FROM {{ ref('stg_renewal__deals') }}
    WHERE pipeline_id = '{{ var("winback_pipeline_id") }}'
),

closers AS (
    SELECT owner_id, closer_name FROM {{ ref('dim_closers') }}
    WHERE rep_team IS NOT NULL
),

stages AS (
    SELECT
        stage_id,
        stage_label,
        snapshot_col,
        -- report column order, left to right
        CASE snapshot_col
            WHEN 'wb_eligible'     THEN 1
            WHEN 'wb_attempting'   THEN 2
            WHEN 'wb_booked'       THEN 3
            WHEN 'wb_not_complete' THEN 4
            WHEN 'wb_nurture'      THEN 5
            WHEN 'wb_redzone'      THEN 6
            WHEN 'wb_closed_won'   THEN 7
            WHEN 'wb_closed_lost'  THEN 8
        END AS stage_order
    FROM {{ ref('dim_renewal_stages') }}
    WHERE pipeline_id = '{{ var("winback_pipeline_id") }}'
)

SELECT
    d.deal_id,
    d.closer_owner_id,
    COALESCE(c.closer_name, 'Unassigned') AS closer_name,
    s.stage_id,
    s.stage_label,
    s.snapshot_col,
    s.stage_order,
    {{ to_et_date('d.created_at') }} AS create_date_et
FROM deals AS d
LEFT JOIN closers AS c ON d.closer_owner_id = c.owner_id
INNER JOIN stages AS s ON d.dealstage_id = s.stage_id
WHERE c.owner_id IS NOT NULL OR d.closer_owner_id IS NULL
