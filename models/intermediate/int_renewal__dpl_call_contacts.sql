-- Avg DPL denominator at contact grain -- one row per (meeting_id, contact_id). Source of truth since
-- 2026-11-09 is the team's "Renewal Closers Dashboard" artifact: DPL = cash collected / DISTINCT CONTACTS
-- with a meeting of the six DPL types (dpl_call_types()) in the window, ANY outcome (pending, canceled and
-- blank included), credited to the meeting owner and dated by meeting day (ET). The artifact counts
-- distinct contacts per rep and sums the reps for the team, so count per closer at query time and add up.
--
-- Replaces fct_renewal_meetings.is_dpl_call (a meeting count) as the DPL denominator. For Oct 2026 the two
-- read 275 contacts vs 291 meetings: a contact rebooked or followed up within the month counts once.
--
-- A meeting with no associated contact contributes nothing, as in the artifact (it reads contacts off
-- the meetings). Contact ids are merge-resolved by stg_renewal__engagement_contacts.

WITH meetings AS (
    SELECT
        m.meeting_id,
        m.owner_id                             AS closer_owner_id,
        m.activity_type,
        m.meeting_outcome,
        {{ to_et_date('m.meeting_start_at') }} AS meeting_date_et
    FROM {{ ref('stg_renewal__meetings') }} AS m
    INNER JOIN {{ ref('dim_closers') }} AS c ON m.owner_id = c.owner_id
    WHERE LOWER(TRIM(m.activity_type)) IN ({{ dpl_call_types() }})
)

SELECT
    m.meeting_id,
    ec.contact_id,
    m.closer_owner_id,
    m.activity_type,
    m.meeting_outcome,
    m.meeting_date_et
FROM meetings AS m
INNER JOIN {{ ref('stg_renewal__engagement_contacts') }} AS ec ON m.meeting_id = ec.meeting_id
