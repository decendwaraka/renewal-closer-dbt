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
-- pc_due term length (Travis/Celeste decision, 2026-08-15): confirmed NOT a fixed term property --
-- terms genuinely range 6-14 months. Instead, derive the midpoint from a start date and Membership
-- Expiration Date directly: start date = Renewal - Close Date (upsell___close_date) if populated, else
-- plain Close Date (closedate). This replaces the term-length search below, which is now moot (kept
-- for the record of what was ruled out): renewal_year_count ("1st/2nd/3rd Year+" -- renewal cycle
-- number, not term length, and 100% null for the new pipeline), property_renewal_duration (only ~13%
-- populated, scattered with implausible values like 0, 51, 122, 650, 62026, 312217), payment_terms*
-- (free text / all-null), current_subscription_month (>99% null), membership_start_date (essentially 0%
-- populated), and cycle_start_date/agreement_end_date (looked promising by label -- "Term Start Date" /
-- "Drives Membership Expiring Soon tag" -- but live-checked 2026-08-15 at 28/6064 and 12/6064 populated
-- on renewal-pipeline deals, a dead end).
--
-- PC Due WINDOW WIDTH -- PROVISIONAL (2026-08-15), symmetric +/-45 days around the midpoint. Celeste
-- never specified a width, so this was derived from live data rather than guessed, and should be
-- swapped if she answers differently. How it was derived, in case it needs re-checking:
--   * The OLD pipeline has real Due stages, and RAW.DEAL carries per-stage DATE_ENTERED_<id>/
--     DATE_EXITED_<id>. Stage EXIT is the signal (when the team acted); stage ENTRY is useless here --
--     PC Due entry has a median of 0 days from the start date, i.e. Due is just the default landing
--     stage, not a triggered state.
--   * Method validated by a control: running it on RC Due (whose 45-day rule we already know) returned
--     a median of 44 days before expiration. Near-exact recovery, so the extraction is trustworthy.
--   * PC Due exits (n=984 in-term deals) cluster just BEFORE the midpoint: p25 5 / median 21 / p75 37
--     days before it. Share of real work captured -- symmetric +/-45d: 69.0%; 45d before only: 58.0%;
--     30d before only: 48.5%; "due once past midpoint, stays due": 21.3%.
--   * So +/-45 wins on coverage AND matches rc_due's existing 45-day magnitude. The "stays due after
--     midpoint" variant is ruled out: 78.7% of progress calls are worked BEFORE the midpoint, so it
--     would flag deals as due only after the team had already worked them.
--   * Caveats: measured on the OLD pipeline (the new one has no Due stage -- the reason this is computed
--     at all), assumes the new pipeline behaves the same, and the in-term restriction dropped 984 of
--     1543 PC exits.
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
        d.membership_expiration_date,
        d.close_date,
        d.close_date_fallback,
        d.date_entered_current_stage
    FROM {{ ref('stg_renewal__deals') }} AS d
    LEFT JOIN {{ ref('stg_renewal__deal_contacts') }} AS tc ON d.deal_id = tc.deal_id
    WHERE COALESCE(tc.is_test_contact, FALSE) = FALSE
),

-- PC Due midpoint (Travis/Celeste, 2026-08-15) -- see the pc_due comment block above. Consumed by
-- pc_due_computed further down.
pc_due_midpoint AS (
    SELECT
        d.deal_id,
        COALESCE(
            {{ hubspot_date_to_et_date('d.close_date') }},
            {{ to_et_date('d.close_date_fallback') }}
        ) AS membership_start_date_et,
        {{ hubspot_date_to_et_date('d.membership_expiration_date') }} AS membership_expiration_date_et,
        DATEADD(
            'day',
            FLOOR(DATEDIFF(
                'day',
                COALESCE({{ hubspot_date_to_et_date('d.close_date') }}, {{ to_et_date('d.close_date_fallback') }}),
                {{ hubspot_date_to_et_date('d.membership_expiration_date') }}
            ) / 2),
            COALESCE({{ hubspot_date_to_et_date('d.close_date') }}, {{ to_et_date('d.close_date_fallback') }})
        ) AS pc_due_midpoint_et
    FROM deals AS d
    WHERE COALESCE(d.close_date, d.close_date_fallback) IS NOT NULL
      AND d.membership_expiration_date IS NOT NULL
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
        'rc_due'        AS snapshot_col,
        -- The deal "enters" rc_due 45 days before expiration, not today -- so a windowed query sees
        -- it show up on the date it actually became due, not on whatever day the dashboard is loaded.
        DATEADD('day', -45, {{ hubspot_date_to_et_date('d.membership_expiration_date') }}) AS entry_date_et
    FROM deals AS d
    INNER JOIN new_pipeline_pre_rc_stages AS e ON d.dealstage_id = e.stage_id
    INNER JOIN closers AS cl ON d.closer_owner_id = cl.owner_id
    WHERE d.pipeline_id = '{{ var("new_renewal_pipeline_id") }}'
      AND {{ hubspot_date_to_et_date('d.membership_expiration_date') }} IS NOT NULL
      AND DATE(CONVERT_TIMEZONE('America/New_York', CURRENT_TIMESTAMP()))
          BETWEEN DATEADD('day', -45, {{ hubspot_date_to_et_date('d.membership_expiration_date') }})
              AND {{ hubspot_date_to_et_date('d.membership_expiration_date') }}
),

-- New-pipeline stages that occur before the Progress Call process starts. Narrower than the rc_due
-- equivalent above on purpose: a deal that has already reached pc_invited or later has its own bucket,
-- so only new_member is a candidate for date-based pc_due.
new_pipeline_pre_pc_stages AS (
    SELECT stage_id
    FROM stages
    WHERE pipeline_id = '{{ var("new_renewal_pipeline_id") }}'
      AND snapshot_col = 'new_member'
),

-- PROVISIONAL window -- see the PC Due WINDOW WIDTH block at the top of this file before changing 45.
-- rc_due wins ties: a deal inside BOTH windows (past its midpoint AND within 45 days of expiration) is
-- the later, more urgent state, so it's excluded here rather than double-bucketed.
pc_due_computed AS (
    SELECT
        d.deal_id,
        d.closer_owner_id,
        cl.closer_name,
        d.pipeline_id,
        'progress_call' AS stage_group,
        'pc_due'        AS snapshot_col,
        -- Mirrors rc_due: the deal "enters" pc_due when the window opens (45 days before the midpoint),
        -- not on whatever day the dashboard is loaded, so windowed queries see it on the real date.
        DATEADD('day', -45, m.pc_due_midpoint_et) AS entry_date_et
    FROM deals AS d
    INNER JOIN new_pipeline_pre_pc_stages AS e ON d.dealstage_id = e.stage_id
    INNER JOIN closers AS cl ON d.closer_owner_id = cl.owner_id
    INNER JOIN pc_due_midpoint AS m ON d.deal_id = m.deal_id
    WHERE d.pipeline_id = '{{ var("new_renewal_pipeline_id") }}'
      AND d.deal_id NOT IN (SELECT deal_id FROM rc_due_computed)
      AND DATE(CONVERT_TIMEZONE('America/New_York', CURRENT_TIMESTAMP()))
          BETWEEN DATEADD('day', -45, m.pc_due_midpoint_et)
              AND DATEADD('day',  45, m.pc_due_midpoint_et)
),

-- Deals re-bucketed into rc_due_computed or pc_due_computed are excluded here so each deal lands in
-- exactly ONE snapshot_col row -- matching the old pipeline's invariant (a deal has exactly one current
-- dealstage_id, so stages partition deals with no overlap) and avoiding inflating any "Total" that sums
-- deal_count across every snapshot_col for a pipeline.
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
    WHERE d.deal_id NOT IN (SELECT deal_id FROM rc_due_computed)
      AND d.deal_id NOT IN (SELECT deal_id FROM pc_due_computed)
),

final AS (
    SELECT closer_owner_id, closer_name, pipeline_id, stage_group, snapshot_col, deal_id, entry_date_et FROM stage_based
    UNION ALL
    SELECT closer_owner_id, closer_name, pipeline_id, stage_group, snapshot_col, deal_id, entry_date_et FROM rc_due_computed
    UNION ALL
    SELECT closer_owner_id, closer_name, pipeline_id, stage_group, snapshot_col, deal_id, entry_date_et FROM pc_due_computed
)

SELECT * FROM final
