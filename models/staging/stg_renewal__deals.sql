-- Renewal deals staging. Column names verified against MARKETING_DB.RAW.DEAL.
-- Deal owner is the top-level OWNER_ID (NOT property_hubspot_owner_id).
-- Fivetran collapses HubSpot triple underscores (upsell___close_date -> PROPERTY_UPSELL_CLOSE_DATE).
--
-- Cash total is base + AP1 + AP2 + AP3 + AP4 (confirmed 2026-08-06: only 4 additional payments are
-- ever allowed; AP5-AP10 properties are unused placeholders, not a sync gap — see OPEN_ISSUES Resolved #1).
-- OPEN ISSUE #2 (product field): renewal_product is dead; upsell_plan is the live product field.

WITH source AS (
    SELECT * FROM {{ source('hubspot_raw', 'DEAL') }}
    WHERE COALESCE(_fivetran_deleted, FALSE) = FALSE
),

renamed AS (
    SELECT
        deal_id,
        owner_id::VARCHAR                                           AS closer_owner_id,
        deal_pipeline_id::VARCHAR                                   AS pipeline_id,
        deal_pipeline_stage_id::VARCHAR                             AS dealstage_id,
        property_upsell_close_date                                  AS close_date,

        -- cash components (base + AP1 + AP2 + AP3 + AP4 available today)
        property_cash_collected                                     AS cash_collected,
        property_additional_payment_1_amount                        AS ap1_amount,
        property_additional_payment_1_stamped_date                  AS ap1_stamped_at,
        property_additional_payment_2_amount                        AS ap2_amount,
        property_additional_payment_2_stamped_date                  AS ap2_stamped_at,
        property_collected_amount_additional_payment_3              AS ap3_amount,
        property_collected_date_additional_payment_3                AS ap3_stamped_at,
        property_collected_amount_additional_payment_4              AS ap4_amount,
        property_collected_date_additional_payment_4                AS ap4_stamped_at,

        -- product / term attributes (for Cash-by-Pipeline split, pending mapping)
        property_renewal_year_count                                 AS renewal_year_count,
        property_renewal_product_category_originally_purchased      AS orig_product_category,
        property_upsell_plan                                        AS upsell_plan,
        property_renewal_product_pitched                            AS renewal_product_pitched
    FROM source
)

SELECT * FROM renamed
