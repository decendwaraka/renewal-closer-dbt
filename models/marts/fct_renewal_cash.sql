{{ config(materialized='view') }}

-- Payment-grain cash fact. One row per (deal, cash component), dated in ET, with product/term
-- attributes for the Cash-by-Pipeline split. Sum cash_amount at query time for any window.

WITH cash AS (
    SELECT * FROM {{ ref('int_renewal__deal_cash') }}
),

deals AS (
    SELECT
        deal_id,
        pipeline_id,
        dealstage_id,
        renewal_year_count,
        orig_product_category,
        upsell_plan,
        renewal_product_pitched
    FROM {{ ref('int_renewal__won_deals') }}
),

product_map AS (
    SELECT upsell_plan, product_column FROM {{ ref('dim_product_map') }}
),

final AS (
    SELECT
        c.deal_id,
        c.closer_owner_id,
        cl.closer_name,
        c.cash_component,
        c.cash_date_et,
        c.cash_amount,
        d.pipeline_id,
        d.dealstage_id,
        d.renewal_year_count,
        d.orig_product_category,
        d.upsell_plan,
        -- OPEN ISSUE #2 resolved 2026-08-08: seeds/dim_product_map.csv maps upsell_plan to
        -- ACC_TIER/MM_TIER/TERM_2 per Celeste/RevOps. UNMAPPED fallback stays as a safety net for any
        -- future upsell_plan value added in HubSpot before the seed is updated to match.
        COALESCE(pm.product_column, 'UNMAPPED') AS product_column
    FROM cash AS c
    LEFT JOIN deals AS d ON c.deal_id = d.deal_id
    LEFT JOIN product_map AS pm ON d.upsell_plan = pm.upsell_plan
    LEFT JOIN {{ ref('dim_closers') }} AS cl ON c.closer_owner_id = cl.owner_id
)

SELECT * FROM final
