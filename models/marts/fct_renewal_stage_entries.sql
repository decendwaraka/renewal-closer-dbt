{{ config(materialized='view') }}

-- Stage-entry fact (cohort-based PC/RC Book%, replacing the old live-snapshot Invited/Scheduled ratio):
-- one row per (deal_id, closer_owner_id, stage_entry_type, entry_date_et), dated by whichever ET calendar
-- day HubSpot stamped the deal as entering that stage. Deliberately NOT pre-aggregated to "this month" --
-- exposes per-deal dated rows so any date window (MTD, prior-MTD, etc.) can be applied downstream,
-- consistent with fct_renewal_cash exposing cash_date_et per row rather than pre-aggregating.
--
-- Book% formula (per stakeholder): (deals entered Invited this month so far) / (deals entered Scheduled
-- this month so far), computed the same way for PC and RC against their respective stage pairs.
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

scoped AS (
    SELECT d.*
    FROM deals AS d
    INNER JOIN closers AS c ON d.closer_owner_id = c.owner_id
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
