-- Deal-to-contact association at pair grain: one row per (deal_id, contact_id). Backs the Live Call Close
-- Rate's "did this contact go on to win a deal" check (int_renewal__live_call_contacts). Not the same as
-- stg_renewal__deal_contacts, which rolls up to deal grain for the test-contact flag.
--
-- contact_id is resolved through stg_renewal__contact_merges, the same as stg_renewal__engagement_contacts,
-- so both sides of the meeting -> contact -> deal join agree on which contact a merged-away id now is.
--
-- DISTINCT because DEAL_CONTACT keeps one row per association type (TYPE_ID / CATEGORY), and merge
-- resolution can collapse two ids onto one. No _fivetran_deleted column on this table (verified live);
-- deleted deals drop out via stg_renewal__deals.

SELECT DISTINCT
    dc.deal_id,
    COALESCE(m.contact_id, dc.contact_id::VARCHAR) AS contact_id
FROM {{ source('hubspot_raw', 'DEAL_CONTACT') }} AS dc
LEFT JOIN {{ ref('stg_renewal__contact_merges') }} AS m
    ON dc.contact_id::VARCHAR = m.merged_contact_id
WHERE dc.contact_id IS NOT NULL
