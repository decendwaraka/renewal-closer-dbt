{{ config(materialized='view') }}

-- (meeting, contact)-grain fact behind the Leaderboard's Live Call Close %, matching the team's HubSpot
-- "Live to Close Rate" report. See int_renewal__live_call_contacts for the definition. Count at query time:
--   COUNT(DISTINCT IFF(is_won_after_meeting, contact_id, NULL)) / COUNT(DISTINCT contact_id)
-- over meeting_date_et in the window. The team rate is distinct contacts across all closers, not a sum
-- of the per-closer rows.

SELECT
    lc.meeting_id,
    lc.contact_id,
    lc.closer_owner_id,
    cl.closer_name,
    lc.activity_type,
    lc.meeting_date_et,
    lc.is_won_after_meeting,
    lc.first_won_close_date_et
FROM {{ ref('int_renewal__live_call_contacts') }} AS lc
LEFT JOIN {{ ref('dim_closers') }} AS cl ON lc.closer_owner_id = cl.owner_id
