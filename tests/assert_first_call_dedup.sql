-- Among COMPLETED live calls (RC/PWC/WB), each (deal_id, meeting_category) must have exactly one call
-- flagged is_first_call. That is what keeps a follow-up out of the DPL / Close Rate denominator
-- (OPEN_ISSUES #23). The invariant was documented in _marts.yml but nothing enforced it, and it got
-- misread twice as a Win-Back dedup gap -- hence this test.
--
-- Scoping to is_completed is the whole point. is_first_call reads TRUE for non-completed calls: only
-- completed calls are ranked in int_renewal__meetings, and everything else falls through the
-- COALESCE(..., TRUE). So a deal with one completed plus one canceled call shows two TRUE rows and
-- looks like a dedup miss when read on its own. It isn't -- the dashboard always pairs the flag with
-- is_completed, which is exactly the population checked here.
--
-- Unlinked calls (deal_id IS NULL) are excluded on purpose: each gets its own partition by design, so
-- they always flag first and there is no duplicate to detect.
--
-- Catches both directions -- a follow-up wrongly flagged (>1) and a group with no first call at all (0).
-- Returns offending rows (test fails if any).

SELECT
    deal_id,
    meeting_category,
    COUNT(*)                AS completed_calls,
    COUNT_IF(is_first_call) AS flagged_first
FROM {{ ref('fct_renewal_meetings') }}
WHERE
    is_completed
    AND meeting_category IN ('RC', 'PWC', 'WB')
    AND deal_id IS NOT NULL
GROUP BY deal_id, meeting_category
HAVING COUNT_IF(is_first_call) != 1
