{{ config(materialized='view') }}

-- (meeting, contact)-grain fact behind the Avg DPL denominator. See int_renewal__dpl_call_contacts.
-- Count at query time, per closer, then sum the closers for the team:
--   COUNT(DISTINCT contact_id) over meeting_date_et in the window, GROUP BY closer_name

SELECT
    d.meeting_id,
    d.contact_id,
    d.closer_owner_id,
    cl.closer_name,
    d.activity_type,
    d.meeting_outcome,
    d.meeting_date_et
FROM {{ ref('int_renewal__dpl_call_contacts') }} AS d
LEFT JOIN {{ ref('dim_closers') }} AS cl ON d.closer_owner_id = cl.owner_id
