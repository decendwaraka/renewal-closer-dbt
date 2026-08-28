-- Renewal meetings staging. Column names verified against MARKETING_DB.RAW.ENGAGEMENT_MEETING.
-- Meeting owner is PROPERTY_HUBSPOT_OWNER_ID (differs from deals, which use OWNER_ID).
-- Meeting date field is PROPERTY_HS_MEETING_START_TIME (verified present; use this, not hs_timestamp).
--
-- activity_type is passed through RAW. Case/whitespace normalization happens in int_renewal__meetings,
-- which is also where categorization lives -- keeping the two together means the unit tests can feed a
-- raw HubSpot string and actually exercise the normalization.

WITH source AS (
    SELECT * FROM {{ source('hubspot_raw', 'ENGAGEMENT_MEETING') }}
    WHERE COALESCE(_fivetran_deleted, FALSE) = FALSE
),

renamed AS (
    SELECT
        engagement_id                          AS meeting_id,
        property_hubspot_owner_id::VARCHAR      AS owner_id,
        property_hs_activity_type               AS activity_type,
        property_hs_meeting_outcome             AS meeting_outcome,
        property_hs_meeting_start_time          AS meeting_start_at
    FROM source
)

SELECT * FROM renamed
