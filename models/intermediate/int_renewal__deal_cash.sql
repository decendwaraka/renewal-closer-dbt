-- Cash exploded to payment grain: one row per (deal, cash component).
-- Pattern mirrors setter-dbt/models/marts/fct_ob_cash.sql (UNION-ALL per payment).
--
-- EVERY component is dated at the DEAL'S Renewal Close Date (close_date_et), not at the day the payment
-- came in. Changed 2026-10-19 to match the team's HubSpot "Total Cash Collected (All Payments)" report.
--
-- Why: that report adds a deal's base Cash Collected and ALL its additional payments, then buckets the
-- whole total in the month of the deal's Renewal Close Date (upsell___close_date -- NOT the plain Close
-- Date; using closedate moves Melissa's September total by $20,000). We used to date each additional
-- payment on its own collected/stamped day instead, so cash on a deal closed in one month but paid in
-- the next landed in a different month than in the report. September 2026, per closer:
--
--                       HubSpot report     this model (own-date basis)
--     Abe Underwood         $504,890.00        $501,556.66
--     Melissa Davis         $352,820.00        $355,320.00
--     Elisabeth Rogers      $225,278.66        $234,542.00
--     Sufijan Cunningham    $129,242.00        $129,242.00
--
-- With every payment dated on the close date, each of those reproduces exactly (the report has no row for
-- Henna Shakoor, who is outside its four-owner filter; she is still on dim_closers -- see below).
--
-- Consequences to know about:
--   * A month's total is no longer final the day the month ends. An installment collected in October on a
--     deal closed in September is now counted in September, so September grows as payments arrive. That is
--     the report's behavior too, which is the point, but it is a cohort view of cash, not a bank-deposit view.
--   * "Cash today" on the Today tile is therefore cash on deals CLOSED today, not money received today.
--   * The additional-payment stamped/collected dates are still staged (stg_renewal__deals) but no longer
--     decide which window a payment falls in, and an additional payment with an amount but no date is now
--     counted (the report counts it). The only date that matters is close_date_et.
--   * A deal with no Renewal Close Date still contributes nothing (nothing to bucket it by), as before.
--
-- Cash total is base + AP1-AP12 (2026-09-01: AP5 was found live and populated -- $2,783.33 across 3
-- deals -- see stg_renewal__deals.sql header for the full story). AP1-4 are guaranteed to exist;
-- AP5-12 are wired via safe_source_column upstream and read as 0 (COALESCEd, never NULL) until
-- Fivetran syncs that index's columns, so the `> 0` filter below naturally excludes them until then --
-- no code change needed as each index goes live. (HubSpot has collected-amount properties for AP7-AP10
-- and AP12 that Snowflake does not; all are $0 today, but cash entered there would be ignored.)

{% set cash_components = [
    ('base', 'cash_collected'),
    ('ap1',  'ap1_amount'),
    ('ap2',  'ap2_amount'),
    ('ap3',  'ap3_amount'),
    ('ap4',  'ap4_amount'),
    ('ap5',  'ap5_amount'),
    ('ap6',  'ap6_amount'),
    ('ap7',  'ap7_amount'),
    ('ap8',  'ap8_amount'),
    ('ap9',  'ap9_amount'),
    ('ap10', 'ap10_amount'),
    ('ap11', 'ap11_amount'),
    ('ap12', 'ap12_amount'),
] %}

WITH won AS (
    SELECT * FROM {{ ref('int_renewal__won_deals') }}
)

{% for name, amount_col in cash_components %}
{% if not loop.first %}
UNION ALL
{% endif %}
SELECT
    deal_id,
    closer_owner_id,
    '{{ name }}'      AS cash_component,
    close_date_et     AS cash_date_et,
    {{ amount_col }}  AS cash_amount
FROM won
WHERE {{ amount_col }} > 0
  AND close_date_et IS NOT NULL
{% endfor %}
