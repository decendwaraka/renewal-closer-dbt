{{ config(materialized='view') }}

-- HubSpot Pipeline Snapshot (#36-#51). Buckets each closer's deals by CURRENT stage (mapped to
-- wireframe columns via dim_renewal_stages), dated by when the deal entered that current stage.
--
-- Grain (2026-08-14, date-range redesign): one row per (deal, current snapshot_col bucket), carrying
-- entry_date_et -- deliberately NOT pre-aggregated to a deal_count, same convention as fct_renewal_cash/
-- fct_renewal_won_deals/fct_renewal_stage_entries, so any date window can be applied downstream. Before
-- this, every column here was a pure "right now" count with no date dimension at all (closed as
-- "not a bug, by design" when first raised). Redefined per stakeholder decision: each column now means
-- "deals that entered this stage during the selected date range," using the generic
-- hs_v2_date_entered_current_stage property (confirmed live 100% populated across all 3 pipelines --
-- see stg_renewal__deals.sql) rather than per-stage date_entered_<id> columns, since a deal's current
-- bucket and its current-stage entry date always refer to the same stage by construction.
--
-- Closed Won stays out of this: the frontend overrides that one column with the already-validated
-- windowed Deals Won figure (OPEN_ISSUES #21) instead of this table's own entry_date_et, so a validated
-- number isn't swapped for an untested one. Every other column here is genuinely windowed by entry_date_et.
--
-- materialized='view' (2026-08-14): this was the one "live snapshot" mart still stuck as a table --
-- every sibling live mart (fct_renewal_cash, fct_renewal_meetings, fct_renewal_won_deals,
-- fct_renewal_stage_entries) got this same fix on 2026-08-08, but this file was created after that pass
-- and never got it. As a table it only reflected HubSpot's state as of the last `dbt run`, contradicting
-- its own "LIVE" claim above -- caught because a closer's live Nurture-stage deal count didn't match
-- what was still sitting in the built table (deals had migrated pipelines since the last build).
--
-- DUE BUCKETS REMOVED (Celeste, 2026-10-19, Metrics Guide #12). The section is now "Renewal Pipeline":
-- current stage only, no PC Due and no RC Due columns. Both were synthetic, date-computed buckets the
-- new Renewal Pipeline (898243912) has no real stage for -- rc_due fired 45 days before Membership
-- Expiration Date, pc_due 15 days before the membership midpoint -- and Celeste's own report simply
-- does not have them. Deleted rather than hidden in the frontend: they were ~130 lines of derived date
-- logic (a 3-tier start-date COALESCE, a midpoint calculation, two stage-exclusion CTEs and a tie-break
-- between them) whose only consumer was the two columns she dropped, and keeping dead derivations
-- around is how they get silently rewired into something else later.
--
-- EXPECT NEW MEMBER TO RISE as a result, and that is correct, not a regression: pc_due/rc_due used to
-- pull near-expiration deals OUT of their real stage bucket and re-bucket them as Due. With the Due
-- buckets gone those deals go back to reporting under the stage they are actually sitting in, which for
-- most of them is New Member.
--
-- NO explicit pipeline_id filter here, deliberately (checked 2026-10-19 before removing the Due CTEs).
-- An `IN (renewal_pipeline_ids)` filter was the obvious companion to that removal, but it would have
-- silently emptied the whole Win-Back Pipeline section: that section reads this same model for
-- snapshot_col LIKE 'wb_%' (snowflake.server.ts), and those rows are pipeline 917643668, which is not
-- in renewal_pipeline_ids. The INNER JOIN to dim_renewal_stages already does the scoping -- the seed
-- contains stages for exactly the two renewal pipelines plus Win-Back and nothing else, so a deal in
-- any other pipeline has no stage row and drops out. The Due CTEs never provided pipeline scoping
-- either; they only ever ADDED new-pipeline rows on top of the stage join.
--
-- Test-contact exclusion (Sub-task 3, 2026-08-13): deals linked to a HubSpot contact with Lead Status
-- "Internal Test Record" are excluded here at the base deal grain, so it covers every snapshot_col
-- (Pipeline Snapshot Total and Win-Back Total are both very likely just COUNT(deal_id) downstream).

WITH deals AS (
    SELECT
        d.deal_id,
        d.closer_owner_id,
        d.pipeline_id,
        d.dealstage_id,
        d.date_entered_current_stage
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

-- Every deal lands in exactly ONE snapshot_col row: a deal has exactly one current dealstage_id, so
-- the stage join partitions deals with no overlap. That invariant used to need two NOT IN exclusions
-- to protect it from the Due re-bucketing; with the Due buckets gone it holds by construction, and
-- any Total that sums deal_count across snapshot_cols is safe.
stage_based AS (
    SELECT
        d.closer_owner_id,
        cl.closer_name,
        s.pipeline_id,
        s.stage_group,
        s.snapshot_col,
        d.deal_id,
        {{ to_et_date('d.date_entered_current_stage') }} AS entry_date_et
    FROM deals AS d
    INNER JOIN stages AS s ON d.dealstage_id = s.stage_id
    INNER JOIN closers AS cl ON d.closer_owner_id = cl.owner_id
)

SELECT * FROM stage_based
