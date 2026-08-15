-- Closed-won renewal deals attributed to a current closer.
-- Base filters (spec): renewal pipelines + won stages + closer owner + close date field.
-- Also includes Win-Back pipeline deals on its own closed-won stage (OPEN_ISSUES #12) -- Win-Back
-- was previously excluded entirely (deliberate v1 scope decision), now folded into cash/won-deal totals.

WITH deals AS (
    SELECT * FROM {{ ref('stg_renewal__deals') }}
),

closers AS (
    SELECT owner_id FROM {{ ref('dim_closers') }}
),

won AS (
    SELECT
        d.deal_id,
        d.closer_owner_id,
        d.pipeline_id,
        d.dealstage_id,
        {{ hubspot_date_to_et_date('d.close_date') }}  AS close_date_et,
        d.cash_collected,
        d.ap1_amount,
        d.ap1_stamped_at,
        d.ap2_amount,
        d.ap2_stamped_at,
        d.ap3_amount,
        d.ap3_stamped_at,
        d.ap4_amount,
        d.ap4_stamped_at,
        d.renewal_year_count,
        d.orig_product_category,
        d.upsell_plan,
        d.renewal_product_pitched,
        d.active_product_snapshot_at_won
    FROM deals AS d
    INNER JOIN closers AS c ON d.closer_owner_id = c.owner_id
    WHERE (
        d.pipeline_id IN ({{ "'" ~ var('renewal_pipeline_ids') | join("','") ~ "'" }})
        AND d.dealstage_id IN ({{ "'" ~ var('won_stage_ids') | join("','") ~ "'" }})
    ) OR (
        d.pipeline_id = '{{ var('winback_pipeline_id') }}'
        AND d.dealstage_id IN ({{ "'" ~ var('winback_won_stage_ids') | join("','") ~ "'" }})
    )
),

-- Post-Webinar attribution (OPEN_ISSUES #33): a deal counts as post-webinar-attributed if any
-- associated contact booked a post-renewal-webinar call within 30 days before/on the close date.
deal_contact AS (
    SELECT deal_id, contact_id
    FROM {{ source('hubspot_raw', 'DEAL_CONTACT') }}
),

post_webinar_flag AS (
    SELECT
        dc.deal_id,
        BOOLOR_AGG(
            pwb.booked_at_et BETWEEN DATEADD('day', -30, w.close_date_et) AND w.close_date_et
        ) AS is_post_webinar_close
    FROM won AS w
    INNER JOIN deal_contact AS dc ON w.deal_id = dc.deal_id
    LEFT JOIN {{ ref('stg_renewal__contact_webinar_bookings') }} AS pwb
        ON pwb.contact_id = dc.contact_id::VARCHAR
    GROUP BY dc.deal_id
)

SELECT
    w.*,
    COALESCE(pwf.is_post_webinar_close, FALSE) AS is_post_webinar_close
FROM won AS w
LEFT JOIN post_webinar_flag AS pwf ON w.deal_id = pwf.deal_id
