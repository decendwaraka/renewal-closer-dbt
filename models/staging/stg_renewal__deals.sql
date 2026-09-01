-- Renewal deals staging. Column names verified against MARKETING_DB.RAW.DEAL.
-- Deal owner is the top-level OWNER_ID (NOT property_hubspot_owner_id).
-- Fivetran collapses HubSpot triple underscores (upsell___close_date -> PROPERTY_UPSELL_CLOSE_DATE).
--
-- Cash total is base + AP1-AP12 (2026-09-01: found AP5 had gone live and populated -- $2,783.33 across
-- 3 deals, all missing from Elisabeth Rogers' August total -- while AP1-4/AP5-10/AP11-12 were being
-- treated as one uniform "not populated yet" group. They're not uniform: Fivetran only creates a
-- payment's collected_amount/date columns once at least one deal has a real value there, and each
-- index goes live independently as reps actually collect that many installments. AP1-4 are wired
-- directly (guaranteed to exist). AP5-12 are wired via safe_source_column (see
-- macros/safe_source_column.sql), which checks the live source schema on every run and falls back to
-- NULL if the column isn't there yet -- so each one activates with real numbers automatically the
-- moment Fivetran adds it, no further code change needed. Amounts are COALESCEd to 0 (never NULL) so
-- an unsynced or blank payment is inert in any SUM, not just the `> 0` filtered union in
-- int_renewal__deal_cash.
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

        -- PC Due midpoint start-date fallback (Travis/Celeste decision, 2026-08-15): membership
        -- midpoint = midpoint(start date, Membership Expiration Date), where start date prioritizes
        -- Renewal - Close Date (close_date above) and falls back to this plain HubSpot Close Date when
        -- Renewal - Close Date is blank (true for ~77% of renewal-pipeline deals, live-checked). Unlike
        -- close_date/membership_expiration_date, this is a REAL timestamp with time-of-day (confirmed
        -- live: only 3/2862 land on exact midnight UTC), so downstream conversion must use to_et_date,
        -- not hubspot_date_to_et_date.
        property_closedate                                          AS close_date_fallback,

        -- cash components (base + AP1-AP12, see header note)
        property_cash_collected                                     AS cash_collected,
        COALESCE(property_additional_payment_1_amount, 0)          AS ap1_amount,
        property_additional_payment_1_stamped_date                  AS ap1_stamped_at,
        COALESCE(property_additional_payment_2_amount, 0)           AS ap2_amount,
        property_additional_payment_2_stamped_date                  AS ap2_stamped_at,
        COALESCE(property_collected_amount_additional_payment_3, 0) AS ap3_amount,
        property_collected_date_additional_payment_3                AS ap3_stamped_at,
        COALESCE(property_collected_amount_additional_payment_4, 0) AS ap4_amount,
        property_collected_date_additional_payment_4                AS ap4_stamped_at,
        COALESCE({{ safe_source_column('hubspot_raw', 'DEAL', 'property_collected_amount_additional_payment_5', 'FLOAT') }}, 0)
                                                                     AS ap5_amount,
        {{ safe_source_column('hubspot_raw', 'DEAL', 'property_collected_date_additional_payment_5', 'TIMESTAMP_NTZ') }}
                                                                     AS ap5_stamped_at,
        COALESCE({{ safe_source_column('hubspot_raw', 'DEAL', 'property_collected_amount_additional_payment_6', 'FLOAT') }}, 0)
                                                                     AS ap6_amount,
        {{ safe_source_column('hubspot_raw', 'DEAL', 'property_collected_date_additional_payment_6', 'TIMESTAMP_NTZ') }}
                                                                     AS ap6_stamped_at,
        COALESCE({{ safe_source_column('hubspot_raw', 'DEAL', 'property_collected_amount_additional_payment_7', 'FLOAT') }}, 0)
                                                                     AS ap7_amount,
        {{ safe_source_column('hubspot_raw', 'DEAL', 'property_collected_date_additional_payment_7', 'TIMESTAMP_NTZ') }}
                                                                     AS ap7_stamped_at,
        COALESCE({{ safe_source_column('hubspot_raw', 'DEAL', 'property_collected_amount_additional_payment_8', 'FLOAT') }}, 0)
                                                                     AS ap8_amount,
        {{ safe_source_column('hubspot_raw', 'DEAL', 'property_collected_date_additional_payment_8', 'TIMESTAMP_NTZ') }}
                                                                     AS ap8_stamped_at,
        COALESCE({{ safe_source_column('hubspot_raw', 'DEAL', 'property_collected_amount_additional_payment_9', 'FLOAT') }}, 0)
                                                                     AS ap9_amount,
        {{ safe_source_column('hubspot_raw', 'DEAL', 'property_collected_date_additional_payment_9', 'TIMESTAMP_NTZ') }}
                                                                     AS ap9_stamped_at,
        COALESCE({{ safe_source_column('hubspot_raw', 'DEAL', 'property_collected_amount_additional_payment_10', 'FLOAT') }}, 0)
                                                                     AS ap10_amount,
        {{ safe_source_column('hubspot_raw', 'DEAL', 'property_collected_date_additional_payment_10', 'TIMESTAMP_NTZ') }}
                                                                     AS ap10_stamped_at,
        COALESCE({{ safe_source_column('hubspot_raw', 'DEAL', 'property_collected_amount_additional_payment_11', 'FLOAT') }}, 0)
                                                                     AS ap11_amount,
        {{ safe_source_column('hubspot_raw', 'DEAL', 'property_collected_date_additional_payment_11', 'TIMESTAMP_NTZ') }}
                                                                     AS ap11_stamped_at,
        COALESCE({{ safe_source_column('hubspot_raw', 'DEAL', 'property_collected_amount_additional_payment_12', 'FLOAT') }}, 0)
                                                                     AS ap12_amount,
        {{ safe_source_column('hubspot_raw', 'DEAL', 'property_collected_date_additional_payment_12', 'TIMESTAMP_NTZ') }}
                                                                     AS ap12_stamped_at,

        -- product / term attributes (for Cash-by-Pipeline split, pending mapping)
        property_renewal_year_count                                 AS renewal_year_count,
        property_renewal_product_category_originally_purchased      AS orig_product_category,
        property_upsell_plan                                        AS upsell_plan,
        property_renewal_product_pitched                            AS renewal_product_pitched,

        -- tier-of-origin (OPEN_ISSUES #8): snapshot of the member's Active Product the day before Closed
        -- Won, distinct from upsell_plan (what they're renewing into). Auto-filled via HubSpot workflow.
        property_active_product_snapshot_at_won                     AS active_product_snapshot_at_won,

        -- Post-Webinar attribution (OPEN_ISSUES #33, Celeste 2026-08-16): deal-level dropdown, blank for
        -- every deal except ones sourced from a renewal webinar. Replaces the interim contact-property-
        -- parsing method (stg_renewal__contact_webinar_bookings) -- live-checked, this property tags 194
        -- deals today vs. 41 under the old interim rule, with only 25 deals overlapping between the two,
        -- so the swap materially changes (and improves) attribution, not just simplifies it.
        property_renewal_traffic_source                             AS renewal_traffic_source,

        -- Stage-entry timestamps (PC/RC Book% cohort formula): HubSpot auto-stamps a per-stage
        -- "date entered" property, keyed by stage_id, onto the deal. Picked by the deal's CURRENT
        -- pipeline (95211801 old / 898243912 new), not COALESCE(old, new) -- COALESCE silently prefers
        -- the old pipeline's property whenever it's non-null, which is true for every migrated deal
        -- (HubSpot never clears the old stage-entry timestamp after migration). That meant a migrated
        -- deal's real, current-window new-pipeline stage entry was masked by a stale months-old date
        -- and dropped from the Book% cohort entirely -- confirmed live 2026-08-14, e.g. one closer's
        -- PC-Invited cohort undercounted ~6 vs. an actual ~55 for the same window. These are real
        -- timestamps (not midnight-anchored date properties), so downstream conversion uses to_et_date,
        -- not hubspot_date_to_et_date.
        CASE WHEN deal_pipeline_id::VARCHAR = '{{ var("new_renewal_pipeline_id") }}'
             THEN property_hs_v_2_date_entered_1359841792 ELSE property_hs_v_2_date_entered_240516941 END AS date_entered_pc_invited,
        CASE WHEN deal_pipeline_id::VARCHAR = '{{ var("new_renewal_pipeline_id") }}'
             THEN property_hs_v_2_date_entered_1359841793 ELSE property_hs_v_2_date_entered_175346325 END AS date_entered_pc_scheduled,
        CASE WHEN deal_pipeline_id::VARCHAR = '{{ var("new_renewal_pipeline_id") }}'
             THEN property_hs_v_2_date_entered_1359841800 ELSE property_hs_v_2_date_entered_240516942 END AS date_entered_rc_invited,
        CASE WHEN deal_pipeline_id::VARCHAR = '{{ var("new_renewal_pipeline_id") }}'
             THEN property_hs_v_2_date_entered_1359841801 ELSE property_hs_v_2_date_entered_186350393 END AS date_entered_rc_scheduled,

        -- Generic "date entered whatever stage the deal is CURRENTLY in" (HubSpot system property,
        -- confirmed live 100% populated across all 3 pipelines incl. Win-Back, which has no per-stage
        -- date_entered_<id> columns of its own). Since Pipeline Snapshot already buckets each deal by
        -- its current dealstage_id, this one column is enough to date-window every snapshot_col bucket.
        property_hs_v_2_date_entered_current_stage                  AS date_entered_current_stage,

        -- Membership Expiration Date (RC Due date-based logic). Midnight-anchored HubSpot date property
        -- (confirmed live: always 00:00:00+00 time-of-day), so it's a hubspot_date_to_et_date candidate,
        -- not a real timestamp -- staged raw here, converted downstream where used.
        property_membership_expiration_date                         AS membership_expiration_date
    FROM source
)

SELECT * FROM renamed
