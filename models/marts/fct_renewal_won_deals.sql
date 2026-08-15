{{ config(materialized='view') }}

-- Deal-grain won-deals fact. One row per closed-won renewal deal, dated by ET close date.
-- Powers windowed deal counts: Deals Won (#2), Deals Closed Today (#7), # Closed (#33),
-- and the close-rate numerators (#15, #21, #34, #57). Count deal_id over any [start, end]
-- window on close_date_et. Complements fct_renewal_cash (payment grain) which windows on cash date.

WITH won AS (
    SELECT
        deal_id,
        closer_owner_id,
        pipeline_id,
        dealstage_id,
        close_date_et,
        is_post_webinar_close
    FROM {{ ref('int_renewal__won_deals') }}
)

SELECT
    w.deal_id,
    w.closer_owner_id,
    cl.closer_name,
    w.pipeline_id,
    w.dealstage_id,
    w.close_date_et,
    w.is_post_webinar_close
FROM won AS w
LEFT JOIN {{ ref('dim_closers') }} AS cl ON w.closer_owner_id = cl.owner_id
