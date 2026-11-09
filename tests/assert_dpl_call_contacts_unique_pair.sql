-- fct_renewal_dpl_call_contacts is one row per (meeting_id, contact_id). Same guard as
-- assert_live_call_contacts_unique_pair.sql. Returns offending pairs (test fails if any).

SELECT meeting_id, contact_id, COUNT(*) AS n
FROM {{ ref('fct_renewal_dpl_call_contacts') }}
GROUP BY meeting_id, contact_id
HAVING COUNT(*) > 1
