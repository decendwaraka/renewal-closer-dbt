-- Cash exploded to payment grain: one row per (deal, cash component).
-- Pattern mirrors setter-dbt/models/marts/fct_ob_cash.sql (UNION-ALL per payment).
--
-- DATE RULE (changed 2026-11-02 to match the Renewal Setter dashboard's close_date cash basis -- every
-- dollar-denominated tile must report the same Total Cash across both dashboards; supersedes the
-- 2026-10-21 "AP at its own Collected Date" rule, which superseded the 2026-10-19 "everything at the
-- close date" rule from PR #35 -- so this is actually a return to the PR #35 rule):
--   * every component -- base Cash Collected AND each additional payment (AP1-AP12) -- is dated at the
--     deal's Renewal Close Date (close_date_et -- upsell___close_date, NOT the plain Close Date);
--   * an AP's own Collected Date (ap*_stamped_at) is NOT used for bucketing -- only whether the amount
--     is populated matters. An installment collected in October on a deal closed in August counts in
--     August, under the deal's close date, same as base.
--   * an additional payment with an amount but no Renewal Close Date on the deal does not count
--     (nothing to bucket it by) -- same condition base already applied.
--   Applies to every historical month, and works for any dashboard-selected window with no per-month
--   formula: consumers just filter cash_date_et.
--
-- This ties to the HubSpot "Total Cash Collected (All Payments)" report, which is deal-grain and groups
-- by Renewal Close Date -- every component rides on the deal's close date, there is no separate
-- collected-date report to add. (The 2026-10-21 rule instead matched Celeste's manual two-report
-- reconciliation for Oct 1-20 2026: $545,472.31 = base $512,738.99 + additional payments $32,733.32.
-- That manual process is superseded by this rule, not reproduced by it.)
--
-- Consequences to know about:
--   * "Cash today" is every component -- base AND any AP -- on deals closed today. An installment
--     collected today on a deal closed in an earlier period does NOT count as today's cash; it already
--     counted on its deal's close date.
--   * Anything counting WON DEALS off this model must count the `base` component only, same as before --
--     unchanged by this rule, since every component now shares base's date anyway.
--   * A deal with no Renewal Close Date contributes NO rows at all (base or AP) -- unlike the prior
--     rule, where a dated AP could still count on a close-date-less deal. None observed live as of
--     2026-11-02; closer_owner_id-scoped MI won_deals have always required a close date to be a
--     reportable win, so this is not expected to change totals in practice.
--
-- Cash total is base + AP1-AP12 (2026-09-01: AP5 was found live and populated -- $2,783.33 across 3
-- deals -- see stg_renewal__deals.sql header for the full story). AP1-4 are guaranteed to exist;
-- AP5-12 are wired via safe_source_column upstream and read as 0 (COALESCEd, never NULL) until
-- Fivetran syncs that index's columns, so the `> 0` filter below naturally excludes them until then --
-- no code change needed as each index goes live. (HubSpot has collected-amount/date properties for
-- AP7-AP12 that Snowflake does not; all are $0 today, but cash entered there would be ignored.)

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
