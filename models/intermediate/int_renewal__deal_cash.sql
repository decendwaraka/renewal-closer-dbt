-- Cash exploded to payment grain: one row per (deal, cash component).
-- Each component is dated by its own date field so date-range filters bucket it correctly.
-- Pattern mirrors setter-dbt/models/marts/fct_ob_cash.sql (UNION-ALL per payment).
--
-- OPEN ISSUE #1: warehouse only carries base + AP1 + AP2 (dated) today. AP3 amount exists but has
-- NO collected-date, and AP4-AP10 are not synced at all -> the spec's 11-component total collapses to
-- base + AP1 + AP2. When Fivetran syncs the missing amount/date pairs, add them to the list below and
-- to stg_renewal__deals; no structural change needed here.

{% set cash_components = [
    ('base', 'cash_collected', 'close_date_et'),
    ('ap1',  'ap1_amount',     to_et_date('ap1_stamped_at')),
    ('ap2',  'ap2_amount',     to_et_date('ap2_stamped_at')),
] %}

WITH won AS (
    SELECT * FROM {{ ref('int_renewal__won_deals') }}
)

{% for name, amount_col, date_sql in cash_components %}
{% if not loop.first %}
UNION ALL
{% endif %}
SELECT
    deal_id,
    closer_owner_id,
    '{{ name }}'      AS cash_component,
    {{ date_sql }}    AS cash_date_et,
    {{ amount_col }}  AS cash_amount
FROM won
WHERE {{ amount_col }} > 0
  AND {{ date_sql }} IS NOT NULL
{% endfor %}
