-- Cash exploded to payment grain: one row per (deal, cash component).
-- Each component is dated by its own date field so date-range filters bucket it correctly.
-- Pattern mirrors setter-dbt/models/marts/fct_ob_cash.sql (UNION-ALL per payment).
--
-- Cash total is base + AP1 + AP2 + AP3 + AP4 (all dated). Confirmed 2026-08-06: only 4 additional
-- payments are ever allowed; AP5-AP10 are unused placeholders, not a missing sync — see
-- OPEN_ISSUES Resolved #1. This is the complete component list, not a partial one.

{% set cash_components = [
    ('base', 'cash_collected', 'close_date_et'),
    ('ap1',  'ap1_amount',     hubspot_date_to_et_date('ap1_stamped_at')),
    ('ap2',  'ap2_amount',     hubspot_date_to_et_date('ap2_stamped_at')),
    ('ap3',  'ap3_amount',     hubspot_date_to_et_date('ap3_stamped_at')),
    ('ap4',  'ap4_amount',     hubspot_date_to_et_date('ap4_stamped_at')),
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
