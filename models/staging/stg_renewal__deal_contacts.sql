-- Deal -> "is this deal linked to an Internal Test contact" flag (Sub-task 3, test-contact exclusion).
-- HubSpot's Lead Status property lives on the Contact object, not Deal, so this bridges the Fivetran
-- DEAL_CONTACT association table -> CONTACT.
--
-- Live check (2026-08-13, renewal + win-back pipelines): 7274 of 7278 deals have exactly one associated
-- contact, 4 have two. There's no clean single "primary contact" signal across pipelines to pick one of
-- the two for those 4 (TYPE_ID/CATEGORY values seen: 3/HUBSPOT_DEFINED with no label, 8/"renewal",
-- 5/"Primary" -- inconsistent, not a reliable "primary" flag), so a deal is flagged test if ANY associated,
-- non-deleted contact is Internal Test. NULL-safe: a deal with no resolvable contact is not flagged.
--
-- Note: the spec's exact string "Internal Test" does not exist in PROPERTY_HS_LEAD_STATUS live values --
-- the only value containing "Internal Test" is 'Internal Test Record' (98 contacts live), which is clearly
-- the intended value and is what's used here.

WITH deal_contact AS (
    SELECT deal_id, contact_id
    FROM {{ source('hubspot_raw', 'DEAL_CONTACT') }}
),

contacts AS (
    SELECT
        id::VARCHAR                    AS contact_id,
        property_hs_lead_status         AS lead_status
    FROM {{ source('hubspot_raw', 'CONTACT') }}
    WHERE COALESCE(_fivetran_deleted, FALSE) = FALSE
),

flagged AS (
    SELECT
        dc.deal_id,
        BOOLOR_AGG(c.lead_status = 'Internal Test Record') AS is_test_contact
    FROM deal_contact AS dc
    INNER JOIN contacts AS c ON dc.contact_id::VARCHAR = c.contact_id
    GROUP BY dc.deal_id
)

SELECT * FROM flagged
