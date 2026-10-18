-- Merged-away contact id -> surviving contact id. When two HubSpot contacts are merged, the losing id is
-- deleted and HubSpot moves its meetings/deals onto the survivor, but Fivetran's association tables
-- (ENGAGEMENT_CONTACT, DEAL_CONTACT -- no _fivetran_deleted column on either) keep pointing at the dead
-- id. The survivor lists every id merged into it in hs_merged_object_ids (semicolon-separated).
--
-- Found reconciling the Live Call Close Rate against the team's HubSpot report (2026-10-18): every
-- won-contact miss (Feb Melissa -1, May Abe -1, May Sufijan -2, Aug Elisabeth -1) was a meeting still
-- associated with a merged-away contact whose won deal sits on the survivor. Resolving through this map
-- closed all of them.

SELECT DISTINCT
    TRIM(f.value::VARCHAR) AS merged_contact_id,
    c.id::VARCHAR          AS contact_id
FROM {{ source('hubspot_raw', 'CONTACT') }} AS c,
    LATERAL SPLIT_TO_TABLE(c.property_hs_merged_object_ids, ';') AS f
WHERE COALESCE(c._fivetran_deleted, FALSE) = FALSE
  AND c.property_hs_merged_object_ids IS NOT NULL
  AND TRIM(f.value::VARCHAR) <> ''
