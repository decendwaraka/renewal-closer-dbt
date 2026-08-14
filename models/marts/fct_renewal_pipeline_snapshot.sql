{{ config(materialized='view') }}

-- HubSpot Pipeline Snapshot (#36-#51). LIVE deal-stage counts per closer -- NOT date filtered.
-- Counts each closer's deals by current stage, mapped to wireframe columns via dim_renewal_stages.
--
-- materialized='view' (2026-08-14): this was the one "live snapshot" mart still stuck as a table --
-- every sibling live mart (fct_renewal_cash, fct_renewal_meetings, fct_renewal_won_deals,
-- fct_renewal_stage_entries) got this same fix on 2026-08-08, but this file was created after that pass
-- and never got it. As a table it only reflected HubSpot's state as of the last `dbt run`, contradicting
-- its own "LIVE" claim above -- caught because a closer's live Nurture-stage deal count didn't match
-- what was still sitting in the built table (deals had migrated pipelines since the last build).
--
-- STALE AS OF 2026-08-14: the "10 actual stage IDs" below was enumerated by grouping live deal data
-- (a stage with zero deals at query time doesn't show up that way), same blind spot that caused the
-- Nurture/Redzone gap this file's dim_renewal_stages seed just got fixed for. The new pipeline's raw
-- Fivetran-synced MARKETING_DB.RAW.DEAL_PIPELINE_STAGE table lists 26 defined stages, not 10 -- including
-- a "Renewal Call Due" (1376144296) and a "Progress Call 1 Due" / "Progress Call 2 Due" pair, which may
-- make the date-based rc_due workaround below (and the still-open pc_due gap) unnecessary. Not
-- investigated further here -- scoped this pass to Nurture/Redzone only -- but worth a fresh look before
-- adding more date-based workarounds: query DEAL_PIPELINE_STAGE for the full defined stage list instead
-- of relying on which stages currently hold a deal.
--
-- rc_due date-based fix (2026-08-13, investigation): the new Renewal Pipeline (898243912) has no
-- "Due"-equivalent stage at all (confirmed live: its 10 actual stage IDs don't include anything Due-like),
-- so deals that migrated there were silently dropping out of rc_due entirely -- rc_due used to come purely
-- from a stage_id match against dim_renewal_stages, which only has rc_due/pc_due rows for the OLD pipeline.
-- Fixed by computing rc_due from Membership Expiration Date for the new pipeline only: a deal counts as
-- rc_due once today is within the last 45 days before that date, provided it hasn't already reached an
-- RC-or-later stage (which already has its own snapshot_col bucket above -- this is what prevents double-
-- counting the same deal in two buckets). Membership Expiration Date coverage is good for BOTH pipelines
-- live (99.5% old, 94.2% new), so unifying both onto date-based logic was an option -- deliberately not
-- taken: the old pipeline's stage-based Due tracking already works and is validated, so there's no reason
-- to touch it; only the new pipeline actually has the confirmed bug being fixed here.
--
-- pc_due is NOT touched by this change (still stage-based, still missing for the new pipeline) -- blocked
-- on finding a reliable membership-term-length (6/7/12 month) property. Investigated and ruled out live:
-- renewal_year_count ("1st/2nd/3rd Year+" -- renewal cycle number, not term length, and 100% null for the
-- new pipeline), property_renewal_duration (only ~13% populated, and scattered with implausible values
-- like 0, 51, 122, 650, 62026, 312217 -- not a clean {6,7,12} set), payment_terms* (free text / all-null),
-- current_subscription_month (>99% null), and membership_start_date (essentially 0% populated, so term
-- can't be derived as a start/expiration diff either). Needs stakeholder input on the correct source.
--
-- Test-contact exclusion (Sub-task 3, 2026-08-13): deals linked to a HubSpot contact with Lead Status
-- "Internal Test Record" are excluded here at the base deal grain, so it covers every snapshot_col
-- (Pipeline Snapshot Total and Win-Back Total are both very likely just SUM(deal_count) downstream).

WITH deals AS (
    SELECT
        d.deal_id,
        d.closer_owner_id,
        d.pipeline_id,
        d.dealstage_id,
        d.membership_expiration_date
    FROM {{ ref('stg_renewal__deals') }} AS d
    LEFT JOIN {{ ref('stg_renewal__deal_contacts') }} AS tc ON d.deal_id = tc.deal_id
    WHERE COALESCE(tc.is_test_contact, FALSE) = FALSE
),

stages AS (
    SELECT stage_id, pipeline_id, stage_group, snapshot_col FROM {{ ref('dim_renewal_stages') }}
),

closers AS (
    SELECT owner_id, closer_name FROM {{ ref('dim_closers') }}
),

-- New-pipeline stages that occur before the Renewal Call process starts. A deal sitting in one of these
-- is a candidate for date-based rc_due; once it reaches rc_invited/rc_scheduled/rc_not_cmplt or closes it
-- already has its own bucket below and should not also show up as still "due".
new_pipeline_pre_rc_stages AS (
    SELECT stage_id
    FROM stages
    WHERE pipeline_id = '{{ var("new_renewal_pipeline_id") }}'
      AND snapshot_col IN ('new_member', 'pc_invited', 'pc_scheduled', 'pc_not_cmplt', 'pc_completed')
),

rc_due_computed AS (
    SELECT
        d.deal_id,
        d.closer_owner_id,
        cl.closer_name,
        d.pipeline_id,
        'renewal_call'  AS stage_group,
        'rc_due'        AS snapshot_col
    FROM deals AS d
    INNER JOIN new_pipeline_pre_rc_stages AS e ON d.dealstage_id = e.stage_id
    INNER JOIN closers AS cl ON d.closer_owner_id = cl.owner_id
    WHERE d.pipeline_id = '{{ var("new_renewal_pipeline_id") }}'
      AND {{ hubspot_date_to_et_date('d.membership_expiration_date') }} IS NOT NULL
      AND DATE(CONVERT_TIMEZONE('America/New_York', CURRENT_TIMESTAMP()))
          BETWEEN DATEADD('day', -45, {{ hubspot_date_to_et_date('d.membership_expiration_date') }})
              AND {{ hubspot_date_to_et_date('d.membership_expiration_date') }}
),

-- Deals re-bucketed into rc_due_computed are excluded here so each deal lands in exactly ONE snapshot_col
-- row -- matching the old pipeline's invariant (a deal has exactly one current dealstage_id, so stages
-- partition deals with no overlap) and avoiding inflating any "Total" that sums deal_count across every
-- snapshot_col for a pipeline.
stage_based AS (
    SELECT
        d.closer_owner_id,
        cl.closer_name,
        s.pipeline_id,
        s.stage_group,
        s.snapshot_col,
        d.deal_id
    FROM deals AS d
    INNER JOIN stages AS s ON d.dealstage_id = s.stage_id
    INNER JOIN closers AS cl ON d.closer_owner_id = cl.owner_id
    WHERE d.deal_id NOT IN (SELECT deal_id FROM rc_due_computed)
),

combined AS (
    SELECT closer_owner_id, closer_name, pipeline_id, stage_group, snapshot_col, deal_id FROM stage_based
    UNION ALL
    SELECT closer_owner_id, closer_name, pipeline_id, stage_group, snapshot_col, deal_id FROM rc_due_computed
),

final AS (
    SELECT
        closer_owner_id,
        closer_name,
        pipeline_id,
        stage_group,
        snapshot_col,
        COUNT(deal_id) AS deal_count
    FROM combined
    GROUP BY 1, 2, 3, 4, 5
)

SELECT * FROM final
