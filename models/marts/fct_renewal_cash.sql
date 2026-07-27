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
        -- OPEN ISSUE #2: product_column is UNMAPPED until RevOps confirms the upsell_plan mapping.
        COALESCE(pm.product_column, 'UNMAPPED') AS product_column
    FROM cash AS c
    LEFT JOIN deals AS d ON c.deal_id = d.deal_id
    LEFT JOIN product_map AS pm ON d.upsell_plan = pm.upsell_plan
    LEFT JOIN {{ ref('dim_closers') }} AS cl ON c.closer_owner_id = cl.owner_id
)

SELECT * FROM final
