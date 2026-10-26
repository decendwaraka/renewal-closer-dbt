{{ config(materialized='view') }}

-- Renewal Pipeline Snapshot: every deal currently in the Renewal Pipeline (898243912), broken down by
-- deal owner and CURRENT deal stage. Replicates the HubSpot report of the same name cell for cell
-- (48/48 cells checked live against HubSpot and raw Snowflake, 2026-10-26).
--
-- Grain: one row per (closer, stage), zeros included (a closer with no deals in a stage still gets a
-- row, e.g. Red Zone), so the frontend can pivot without back-filling gaps.
--
-- Deliberately NOT the same as fct_renewal_pipeline_snapshot: that model is windowed by the date a deal
-- entered its current stage, drops test-contact deals, and spans the old pipeline and Win-Back. This
-- report is all-time, unwindowed, and applies none of those filters -- HubSpot's report has no test-contact
-- or date filter, and adding either would make the numbers diverge from it.
--
-- Report scope: Renewal Pipeline only (new_renewal_pipeline_id), and the four team closers only
-- (rep_team IS NOT NULL drops Henna Shakoor, who is off the team and not in the report's owner filter).

WITH deals AS (
    SELECT deal_id, closer_owner_id, dealstage_id
    FROM {{ ref('stg_renewal__deals') }}
    WHERE pipeline_id = '{{ var("new_renewal_pipeline_id") }}'
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
            WHEN 'new_member'    THEN 1
            WHEN 'pc_invited'    THEN 2
            WHEN 'pc_scheduled'  THEN 3
            WHEN 'pc_not_cmplt'  THEN 4
            WHEN 'pc_completed'  THEN 5
            WHEN 'rc_invited'    THEN 6
            WHEN 'rc_scheduled'  THEN 7
            WHEN 'rc_not_cmplt'  THEN 8
            WHEN 'nurture'       THEN 9
            WHEN 'redzone'       THEN 10
            WHEN 'closed_won'    THEN 11
            WHEN 'closed_lost'   THEN 12
        END AS stage_order
    FROM {{ ref('dim_renewal_stages') }}
    WHERE pipeline_id = '{{ var("new_renewal_pipeline_id") }}'
),

counts AS (
    SELECT closer_owner_id, dealstage_id, COUNT(DISTINCT deal_id) AS deal_count
    FROM deals
    GROUP BY 1, 2
)

SELECT
    c.owner_id          AS closer_owner_id,
    c.closer_name,
    s.stage_id,
    s.stage_label,
    s.snapshot_col,
    s.stage_order,
    COALESCE(n.deal_count, 0) AS deal_count
FROM closers AS c
CROSS JOIN stages AS s
LEFT JOIN counts AS n
    ON n.closer_owner_id = c.owner_id AND n.dealstage_id = s.stage_id
