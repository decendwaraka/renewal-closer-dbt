-- fct_renewal_live_call_contacts is one row per (meeting_id, contact_id). A duplicate would come from an
-- association table carrying the same pair twice (one row per association type) slipping past the
-- DISTINCT in staging -- harmless for the COUNT(DISTINCT contact_id) Close Rate today, but it would
-- silently break any row-count consumer. Returns offending pairs (test fails if any).

SELECT meeting_id, contact_id, COUNT(*) AS n
FROM {{ ref('fct_renewal_live_call_contacts') }}
GROUP BY meeting_id, contact_id
HAVING COUNT(*) > 1
