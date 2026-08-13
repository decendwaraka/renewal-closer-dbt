{{ config(materialized='view') }}

-- Payment-grain cash fact. One row per (deal, cash component), dated in ET, with product/term
-- attributes for the Cash-by-Pipeline split. Sum cash_amount at query time for any window.
-- Two independent tier splits live here (OPEN_ISSUES #8): product_column (product mix, from
-- upsell_plan -- what they're renewing into) and tier_of_origin_column (from
-- active_product_snapshot_at_won -- what tier they were on before this renewal). Not supposed to agree.

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
        renewal_product_pitched,
        active_product_snapshot_at_won
    FROM {{ ref('int_renewal__won_deals') }}
),

product_map AS (
    SELECT upsell_plan, product_column FROM {{ ref('dim_product_map') }}
),

tier_map AS (
    SELECT active_product_snapshot_at_won, tier_of_origin_column FROM {{ ref('dim_member_tier_map') }}
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
        -- Win-Back override (2026-08-13, two independent stakeholder reports): Win-Back deals must
        -- never land in the ACC_TIER/MM_TIER/TERM_2 buckets -- they get their own "Winback Cash" line
        -- item downstream. dim_product_map.csv still has legacy Winback-flavored upsell_plan rows
        -- mapped into those tiers, but this pipeline_id check takes precedence and short-circuits them.
        CASE
            WHEN d.pipeline_id = '{{ var('winback_pipeline_id') }}' THEN 'WINBACK'
            ELSE COALESCE(pm.product_column, 'UNMAPPED')
        END AS product_column,
        d.active_product_snapshot_at_won,
        -- OPEN ISSUE #8 resolved 2026-08-12: seeds/dim_member_tier_map.csv maps
        -- active_product_snapshot_at_won to ACC_TIER/MM_TIER/TERM_2. Case-insensitive join -- live
        -- HubSpot data has inconsistent casing on the same product (e.g. 'Defi'/'DeFi Accelerator').
        -- UNMAPPED fallback covers the rare deal where the snapshot is null/erroring (e.g. no close
        -- date set yet) or a genuinely new value not seeded here.
        COALESCE(tm.tier_of_origin_column, 'UNMAPPED') AS tier_of_origin_column
    FROM cash AS c
    LEFT JOIN deals AS d ON c.deal_id = d.deal_id
    LEFT JOIN product_map AS pm ON d.upsell_plan = pm.upsell_plan
    LEFT JOIN tier_map AS tm
        ON UPPER(TRIM(d.active_product_snapshot_at_won)) = UPPER(TRIM(tm.active_product_snapshot_at_won))
    LEFT JOIN {{ ref('dim_closers') }} AS cl ON c.closer_owner_id = cl.owner_id
)

SELECT * FROM final
