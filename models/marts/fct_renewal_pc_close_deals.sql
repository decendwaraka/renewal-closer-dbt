{{ config(materialized='view') }}

-- (deal, qualifying meeting)-grain fact behind PC Close % in Call Outcomes, replicating the team's HubSpot
-- report 445343752. See int_renewal__pc_close_deals for the definition. Count at query time over
-- meeting_date_et in the window, always by distinct deal:
--   COUNT(DISTINCT IFF(is_won, deal_id, NULL)) / COUNT(DISTINCT deal_id)
-- The team rate is distinct deals across ALL owners (including closer_name IS NULL = off-roster or
-- unassigned), not a sum of the per-closer rows.

SELECT
    deal_id,
    meeting_id,
    meeting_date_et,
    closer_owner_id,
    closer_name,
    is_won
FROM {{ ref('int_renewal__pc_close_deals') }}
