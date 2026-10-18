-- Meeting-to-contact association, unfiltered: one row per (meeting_id, contact_id) for every engagement.
-- Backs the contact-grain Live Call Close Rate (int_renewal__live_call_contacts). Not the same as
-- stg_renewal__meeting_contacts, which is the created-date booked side of Call Outcomes and carries its
-- own activity-type list.
--
-- contact_id is resolved through stg_renewal__contact_merges: a meeting still associated with a
-- merged-away contact is credited to the surviving contact, which is what HubSpot itself does.
--
-- DISTINCT because ENGAGEMENT_CONTACT keeps one row per association type (TYPE_ID / CATEGORY), and
-- merge resolution can collapse two ids onto one. No _fivetran_deleted column on this table (verified
-- live); the meeting-side soft-delete filter in stg_renewal__meetings is what keeps deleted meetings out.

SELECT DISTINCT
    ec.engagement_id                                AS meeting_id,
    COALESCE(m.contact_id, ec.contact_id::VARCHAR)  AS contact_id
FROM {{ source('hubspot_raw', 'ENGAGEMENT_CONTACT') }} AS ec
LEFT JOIN {{ ref('stg_renewal__contact_merges') }} AS m
    ON ec.contact_id::VARCHAR = m.merged_contact_id
WHERE ec.contact_id IS NOT NULL
