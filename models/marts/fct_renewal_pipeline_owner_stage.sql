{{ config(materialized='view') }}

-- Renewal Pipeline Snapshot: every deal in the Renewal Pipeline (898243912), by deal owner and CURRENT
-- deal stage, dated by the deal's create date. Replicates the HubSpot report of the same name cell for
-- cell: all-time 48/48, and the Aug / Sep / MTD create-date windows 144/144 against live HubSpot
-- (2026-10-26; the only difference was one deal moved after the last Fivetran sync).
--
-- Grain: one row per deal, carrying create_date_et, same convention as fct_renewal_cash and
-- fct_renewal_pipeline_snapshot, so any date window can be applied downstream. Counts are therefore
-- COUNT(*) at query time, and an (owner, stage) cell with no deals has NO row -- the consumer zero-fills.
--
-- Deliberately NOT fct_renewal_pipeline_snapshot: that model is windowed by the date a deal entered its
-- current stage, drops test-contact deals, and spans the old pipeline and Win-Back. This report is
-- windowed by create date and applies no test-contact filter -- HubSpot's report has none, and adding one
-- would make the numbers diverge from it.
--
-- Report scope: Renewal Pipeline only (new_renewal_pipeline_id), and the four team closers only
-- (rep_team IS NOT NULL drops Henna Shakoor, who is off the team and not in the report's owner filter).

WITH deals AS (
    SELECT deal_id, closer_owner_id, dealstage_id, created_at
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
)

SELECT
    d.deal_id,
    c.owner_id          AS closer_owner_id,
    c.closer_name,
    s.stage_id,
    s.stage_label,
    s.snapshot_col,
    s.stage_order,
    {{ to_et_date('d.created_at') }} AS create_date_et
FROM deals AS d
INNER JOIN closers AS c ON d.closer_owner_id = c.owner_id
INNER JOIN stages AS s ON d.dealstage_id = s.stage_id
