-- fct_renewal_pc_close_deals is one row per (deal_id, meeting_id). A duplicate would mean a pair reached the
-- model through both association paths (deal and contact) without the UNION collapsing it -- harmless for
-- the COUNT(DISTINCT deal_id) PC Close % today, but it would silently break any row-count consumer.
-- Returns offending pairs (test fails if any).

SELECT deal_id, meeting_id, COUNT(*) AS n
FROM {{ ref('fct_renewal_pc_close_deals') }}
GROUP BY deal_id, meeting_id
HAVING COUNT(*) > 1
