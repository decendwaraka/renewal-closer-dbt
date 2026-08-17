-- Deal -> "is this deal linked to an Internal Test contact" flag (Sub-task 3, test-contact exclusion),
-- plus a contact-level PC Due start-date fallback (Travis/Celeste decision, 2026-08-16 -- OPEN_ISSUES #24).
-- HubSpot's Lead Status and True Renewal Close Date properties live on the Contact object, not Deal, so
-- this bridges the Fivetran DEAL_CONTACT association table -> CONTACT for both.
--
-- Live check (2026-08-13, renewal + win-back pipelines): 7274 of 7278 deals have exactly one associated
-- contact, 4 have two. There's no clean single "primary contact" signal across pipelines to pick one of
-- the two for those 4 (TYPE_ID/CATEGORY values seen: 3/HUBSPOT_DEFINED with no label, 8/"renewal",
-- 5/"Primary" -- inconsistent, not a reliable "primary" flag), so a deal is flagged test if ANY associated,
-- non-deleted contact is Internal Test, and true_renewal_close_date picks any non-null value across
-- associated contacts (MAX -- an arbitrary but deterministic tiebreak; the ambiguous-contact case is rare
-- enough live that it isn't worth a real tiebreak rule). NULL-safe: a deal with no resolvable contact gets
-- neither.
--
-- Note: the spec's exact string "Internal Test" does not exist in PROPERTY_HS_LEAD_STATUS live values --
-- the only value containing "Internal Test" is 'Internal Test Record' (98 contacts live), which is clearly
-- the intended value and is what's used here.
--
-- true_renewal_close_date coverage (live-checked 2026-08-16): only 34% of renewal-pipeline deals with a
-- Membership Expiration Date have this via their contact -- WORSE standalone coverage than the deal-level
-- close_date/close_date_fallback COALESCE already used for PC Due (60%). But it rescues 350 deals the
-- deal-level fields miss entirely (little overlap with what deal-level already covers), so it's added as a
-- third fallback tier in fct_renewal_pipeline_snapshot.sql, not a replacement -- pushes coverage to ~65.5%.

WITH deal_contact AS (
    SELECT deal_id, contact_id
    FROM {{ source('hubspot_raw', 'DEAL_CONTACT') }}
),

contacts AS (
    SELECT
        id::VARCHAR                          AS contact_id,
        property_hs_lead_status               AS lead_status,
        property_true_renewal_close_date      AS true_renewal_close_date
    FROM {{ source('hubspot_raw', 'CONTACT') }}
    WHERE COALESCE(_fivetran_deleted, FALSE) = FALSE
),

flagged AS (
    SELECT
        dc.deal_id,
        BOOLOR_AGG(c.lead_status = 'Internal Test Record') AS is_test_contact,
        MAX(c.true_renewal_close_date)                     AS contact_true_renewal_close_date
    FROM deal_contact AS dc
    INNER JOIN contacts AS c ON dc.contact_id::VARCHAR = c.contact_id
    GROUP BY dc.deal_id
)

SELECT * FROM flagged
