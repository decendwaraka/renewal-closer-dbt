-- Cash exploded to payment grain: one row per (deal, cash component).
-- Pattern mirrors setter-dbt/models/marts/fct_ob_cash.sql (UNION-ALL per payment).
--
-- DATE RULE (approved by Celeste Magre, 2026-10-21; supersedes the 2026-10-19 "everything at the close
-- date" rule from PR #35):
--   * base Cash Collected is dated at the deal's Renewal Close Date (close_date_et -- upsell___close_date,
--     NOT the plain Close Date);
--   * each additional payment (AP1-AP12) is dated at its OWN Collected Date (ap*_stamped_at), whenever the
--     deal closed -- an installment collected in October on a deal closed in August counts in October;
--   * an additional payment with an amount but NO Collected Date does not count (nothing to bucket it by).
--   Applies to every historical month, and works for any dashboard-selected window with no per-month
--   formula: consumers just filter cash_date_et.
--
-- This is the team's HubSpot "Total Cash Collected" as Celeste builds it for a month: the regular Cash
-- Collected report (by Renewal Close Date) plus a separate additional-payments report (by Collected
-- Date), added together. October 1-20 2026 reproduces her $545,472.31 exactly: base $512,738.99 +
-- additional payments $32,733.32 (8 payments).
--
-- Consequences to know about:
--   * "Cash today" is base cash on deals closed today plus installments collected today.
--   * Anything counting WON DEALS off this model must count the `base` component only: a payment-only
--     deal (closed in an earlier period, installment collected in this one) is not a newly won deal.
--     The dashboard's Product Mix / Cash by Product "# Won" does exactly that.
--   * A deal with no Renewal Close Date contributes no base row; its dated additional payments still count.
--
-- Cash total is base + AP1-AP12 (2026-09-01: AP5 was found live and populated -- $2,783.33 across 3
-- deals -- see stg_renewal__deals.sql header for the full story). AP1-4 are guaranteed to exist;
-- AP5-12 are wired via safe_source_column upstream and read as 0 (COALESCEd, never NULL) until
-- Fivetran syncs that index's columns, so the `> 0` filter below naturally excludes them until then --
-- no code change needed as each index goes live. (HubSpot has collected-amount/date properties for
-- AP7-AP12 that Snowflake does not; all are $0 today, but cash entered there would be ignored.)

{% set cash_components = [
    ('base', 'cash_collected', 'close_date_et'),
    ('ap1',  'ap1_amount',     hubspot_date_to_et_date('ap1_stamped_at')),
    ('ap2',  'ap2_amount',     hubspot_date_to_et_date('ap2_stamped_at')),
    ('ap3',  'ap3_amount',     hubspot_date_to_et_date('ap3_stamped_at')),
    ('ap4',  'ap4_amount',     hubspot_date_to_et_date('ap4_stamped_at')),
    ('ap5',  'ap5_amount',     hubspot_date_to_et_date('ap5_stamped_at')),
    ('ap6',  'ap6_amount',     hubspot_date_to_et_date('ap6_stamped_at')),
    ('ap7',  'ap7_amount',     hubspot_date_to_et_date('ap7_stamped_at')),
    ('ap8',  'ap8_amount',     hubspot_date_to_et_date('ap8_stamped_at')),
    ('ap9',  'ap9_amount',     hubspot_date_to_et_date('ap9_stamped_at')),
    ('ap10', 'ap10_amount',    hubspot_date_to_et_date('ap10_stamped_at')),
    ('ap11', 'ap11_amount',    hubspot_date_to_et_date('ap11_stamped_at')),
    ('ap12', 'ap12_amount',    hubspot_date_to_et_date('ap12_stamped_at')),
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
