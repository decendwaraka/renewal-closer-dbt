{{ config(materialized='view') }}

-- Stage-entry fact (cohort-based PC/RC Book%, replacing the old live-snapshot Invited/Scheduled ratio):
-- one row per (deal_id, closer_owner_id, stage_entry_type, entry_date_et), dated by whichever ET calendar
-- day HubSpot stamped the deal as entering that stage. Deliberately NOT pre-aggregated to "this month" --
-- exposes per-deal dated rows so any date window (MTD, prior-MTD, etc.) can be applied downstream,
-- consistent with fct_renewal_cash exposing cash_date_et per row rather than pre-aggregating.
--
-- Book% formula (Celeste, in-app comment on metric tile #13, 2026-08-13): "any deal who entered
-- PC/Midway invited stage this month so far VS any deal who entered PC/Midway Scheduled this month."
-- (deals entered Invited this month so far) / (deals entered Scheduled this month so far), computed
-- the same way for PC and RC against their respective stage pairs. Two INDEPENDENT tallies, not a
-- deal-linked cohort -- built and confirmed to her exactly as stated on 2026-08-14. This is also why
-- Book% can mathematically exceed 100% (OPEN_ISSUES #41): a deal entering Scheduled without ever
-- entering Invited in the same window (or vice versa) has nothing on the other side of the ratio.
-- That's an accepted consequence of her stated rule, not an open formula question.
--
-- As of 2026-08-17 this also backs the Call Outcomes Invited/Booked columns themselves, not just the
-- Book% ratio. Those columns previously read fct_renewal_pipeline_snapshot -- a CURRENT-stage bucket,
-- which drops any deal that entered Invited and then progressed, so it undercounted badly (PC Booked
-- 40 vs 110 actual over Jul 19 - Aug 17). Book% and its two inputs now come from one table, so the
-- displayed columns and the displayed ratio can no longer disagree.
--
-- Scoped to the renewal pipelines (old 95211801 + new 898243912) -- PC/RC Invited/Scheduled stages only
-- exist there; Win-Back (917643668) has its own wb_* stages with no Invited/Scheduled equivalent, so its
-- date_entered_* columns are always NULL and it's excluded via the pipeline_id filter below.
--
-- Mirrors int_renewal__deal_cash.sql's UNION-ALL-per-component pattern.

{% set stage_entry_components = [
    ('pc_invited',   'date_entered_pc_invited'),
    ('pc_scheduled', 'date_entered_pc_scheduled'),
    ('rc_invited',   'date_entered_rc_invited'),
    ('rc_scheduled', 'date_entered_rc_scheduled'),
] %}

WITH deals AS (
    SELECT * FROM {{ ref('stg_renewal__deals') }}
    WHERE pipeline_id IN ({{ "'" ~ var('renewal_pipeline_ids') | join("','") ~ "'" }})
),

closers AS (
    SELECT owner_id FROM {{ ref('dim_closers') }}
),

-- Test-contact exclusion (2026-08-17): deals linked to a HubSpot contact with Lead Status
-- "Internal Test Record" are dropped here, matching fct_renewal_pipeline_snapshot.sql. This table
-- was built as a Book%-only input, where the exclusion was missing; it now also feeds the Call
-- Outcomes Invited/Booked columns directly, so the two marts have to agree on population or the
-- same closer's Invited count differs between two sections of the dashboard. Zero rows affected
-- when added (live-checked over Jul 19 - Aug 17: 0 test-contact deals across all four stage types)
-- -- structural consistency, not a number change.
scoped AS (
    SELECT d.*
    FROM deals AS d
    INNER JOIN closers AS c ON d.closer_owner_id = c.owner_id
    LEFT JOIN {{ ref('stg_renewal__deal_contacts') }} AS tc ON d.deal_id = tc.deal_id
    WHERE COALESCE(tc.is_test_contact, FALSE) = FALSE
)

{% for name, date_col in stage_entry_components %}
{% if not loop.first %}
UNION ALL
{% endif %}
SELECT
    deal_id,
    closer_owner_id,
    '{{ name }}'                AS stage_entry_type,
    {{ to_et_date(date_col) }}  AS entry_date_et
FROM scoped
WHERE {{ date_col }} IS NOT NULL
{% endfor %}
