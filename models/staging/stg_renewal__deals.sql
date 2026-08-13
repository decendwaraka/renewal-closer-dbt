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
        property_renewal_product_pitched                            AS renewal_product_pitched,

        -- tier-of-origin (OPEN_ISSUES #8): snapshot of the member's Active Product the day before Closed
        -- Won, distinct from upsell_plan (what they're renewing into). Auto-filled via HubSpot workflow.
        property_active_product_snapshot_at_won                     AS active_product_snapshot_at_won,

        -- Stage-entry timestamps (PC/RC Book% cohort formula): HubSpot auto-stamps a per-stage
        -- "date entered" property, keyed by stage_id, onto the deal. Coalesced across the old pipeline
        -- (95211801) and new Renewal Pipeline (898243912) -- confirmed live via
        -- MARKETING_DB.INFORMATION_SCHEMA.COLUMNS that all 8 underlying columns exist. These are real
        -- timestamps (not midnight-anchored date properties), so downstream conversion uses to_et_date,
        -- not hubspot_date_to_et_date.
        COALESCE(property_hs_v_2_date_entered_240516941, property_hs_v_2_date_entered_1359841792)  AS date_entered_pc_invited,
        COALESCE(property_hs_v_2_date_entered_175346325, property_hs_v_2_date_entered_1359841793)  AS date_entered_pc_scheduled,
        COALESCE(property_hs_v_2_date_entered_240516942, property_hs_v_2_date_entered_1359841800)  AS date_entered_rc_invited,
        COALESCE(property_hs_v_2_date_entered_186350393, property_hs_v_2_date_entered_1359841801)  AS date_entered_rc_scheduled,

        -- Membership Expiration Date (RC Due date-based logic). Midnight-anchored HubSpot date property
        -- (confirmed live: always 00:00:00+00 time-of-day), so it's a hubspot_date_to_et_date candidate,
        -- not a real timestamp -- staged raw here, converted downstream where used.
        property_membership_expiration_date                         AS membership_expiration_date
    FROM source
)

SELECT * FROM renamed
