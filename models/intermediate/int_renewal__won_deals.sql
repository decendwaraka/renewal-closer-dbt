-- Closed-won renewal deals attributed to a current closer.
-- Base filters (spec): renewal pipelines + won stages + closer owner + close date field.
-- Also includes Win-Back pipeline deals on its own closed-won stage (OPEN_ISSUES #12) -- Win-Back
-- was previously excluded entirely (deliberate v1 scope decision), now folded into cash/won-deal totals.
--
-- is_post_webinar_close (OPEN_ISSUES #33) now reads directly off the deal's own renewal_traffic_source
-- property -- no DEAL_CONTACT/CONTACT join needed anymore, since Celeste's interim contact-property-parsing
-- ask (stg_renewal__contact_webinar_bookings) is superseded by her deal-level property, per her 2026-08-16
-- answer.

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
        d.ap5_amount,
        d.ap5_stamped_at,
        d.ap6_amount,
        d.ap6_stamped_at,
        d.ap7_amount,
        d.ap7_stamped_at,
        d.ap8_amount,
        d.ap8_stamped_at,
        d.ap9_amount,
        d.ap9_stamped_at,
        d.ap10_amount,
        d.ap10_stamped_at,
        d.ap11_amount,
        d.ap11_stamped_at,
        d.ap12_amount,
        d.ap12_stamped_at,
        d.renewal_year_count,
        d.orig_product_category,
        d.upsell_plan,
        d.renewal_product_pitched,
        d.active_product_snapshot_at_won,
        -- Post-Webinar attribution (OPEN_ISSUES #33, Celeste 2026-08-16): deal's own renewal_traffic_source
        -- dropdown, blank for every deal except ones sourced from a renewal webinar. Replaces the interim
        -- contact-property-parsing method (stg_renewal__contact_webinar_bookings) -- live-checked, the two
        -- methods barely overlap (25 deals in common out of 194 new / 41 old), so this is a real swap, not
        -- a simplification of an equivalent rule.
        COALESCE(d.renewal_traffic_source = 'Webinar', FALSE) AS is_post_webinar_close
    FROM deals AS d
    INNER JOIN closers AS c ON d.closer_owner_id = c.owner_id
    WHERE (
        d.pipeline_id IN ({{ "'" ~ var('renewal_pipeline_ids') | join("','") ~ "'" }})
        AND d.dealstage_id IN ({{ "'" ~ var('won_stage_ids') | join("','") ~ "'" }})
    ) OR (
        d.pipeline_id = '{{ var('winback_pipeline_id') }}'
        AND d.dealstage_id IN ({{ "'" ~ var('winback_won_stage_ids') | join("','") ~ "'" }})
    )
)

SELECT * FROM won
