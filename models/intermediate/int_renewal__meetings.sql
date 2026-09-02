-- Renewal meetings categorized into PC / RC / PWC / WB (spec Meeting Type Reference + OPEN_ISSUES #12),
-- attributed to closers.
-- Booked = outcome not canceled; Completed/Show = exactly COMPLETED (renewal team uses plain outcomes).
--
-- Categorization matches on activity_type_key -- activity_type lowercased and trimmed -- NOT on the raw
-- string, so a re-cased duplicate of an existing type can't silently fall out of every metric. Keep every
-- literal below lowercase, and let the unit tests feed a raw HubSpot string to exercise it.
--
-- RC list, reconciled 2026-09-02 (business confirmed): `Renewal Follow-up` and `Renewal Strategy
-- Alignment` are retired from the RC bucket -- same treatment as the already-retired
-- `Renewal Accelerator Evergreen` -- none of the three map to any meeting_category and all get filtered
-- out of the model entirely. Locked in by the test_meetings_closing_call_flag_and_retired_activity_types
-- unit test. Only `Renewal Strategy` and `Renewal Accelerator` remain in RC.
--
-- is_closing_call drops a PWC from Close Rate credit when the same deal already has an
-- earlier completed RC that same calendar month (Travis, live) -- the credit belongs to the RC,
-- not a repeat count. See rc_month_anchor below; when the ordering can't be pinned down (no
-- deal_id, no RC that month, or the PWC isn't the later one) both calls count, per the agreed
-- fallback.

WITH meetings AS (
    SELECT * FROM {{ ref('stg_renewal__meetings') }}
),

closers AS (
    SELECT owner_id FROM {{ ref('dim_closers') }}
),

meeting_deals AS (
    SELECT meeting_id, deal_id FROM {{ ref('stg_renewal__meeting_deals') }}
),

categorized AS (
    SELECT
        m.meeting_id,
        m.owner_id                              AS closer_owner_id,
        m.activity_type,
        LOWER(TRIM(m.activity_type))            AS activity_type_key,
        m.meeting_outcome,
        m.meeting_start_at,
        {{ to_et_date('m.meeting_start_at') }}  AS meeting_date_et,
        md.deal_id,
        CASE
            WHEN LOWER(TRIM(m.activity_type)) IN ('renewal 3 month', 'renewal accelerator 3 month')
                THEN 'PC'
            WHEN LOWER(TRIM(m.activity_type)) IN ('renewal strategy', 'renewal accelerator')
                THEN 'RC'
            WHEN LOWER(TRIM(m.activity_type)) = 'renewal post webinar call'
                THEN 'PWC'
            WHEN LOWER(TRIM(m.activity_type)) = 'renewal winback call'
                THEN 'WB'
            ELSE NULL
        END                                     AS meeting_category,
        {{ is_meeting_booked('m.meeting_outcome') }}     AS is_booked,
        {{ is_meeting_completed('m.meeting_outcome') }}  AS is_completed
    FROM meetings AS m
    INNER JOIN closers AS c ON m.owner_id = c.owner_id
    LEFT JOIN meeting_deals AS md ON m.meeting_id = md.meeting_id
),

filtered AS (
    SELECT * FROM categorized
    WHERE meeting_category IS NOT NULL
),

-- First-call dedup (OPEN_ISSUES #23): DPL and Close Rate should only count the first LIVE call per deal
-- within a meeting-type group (RC/PWC/WB), not every follow-up call with the same member. Ranked only
-- among completed calls -- a canceled/no-show call shouldn't make the actual first completed call look
-- like a follow-up. deal_id is missing for a small share of calls (no HubSpot association); those can't
-- be identified as follow-ups, so they default to counting as a first call rather than being dropped.
completed_ranked AS (
    SELECT
        meeting_id,
        ROW_NUMBER() OVER (
            PARTITION BY COALESCE(deal_id::VARCHAR, 'unlinked-' || meeting_id::VARCHAR), meeting_category
            ORDER BY meeting_start_at
        ) = 1 AS is_first_call
    FROM filtered
    WHERE is_completed AND meeting_category IN ('RC', 'PWC', 'WB')
),

-- Travis's rule: a member's PWC in the same calendar month as an RC they already had shouldn't
-- earn its own Close Rate credit -- that credit belongs to the earlier RC. Anchored on the
-- earliest completed RC per deal per month so a later PWC that month can be compared against it.
rc_month_anchor AS (
    SELECT
        deal_id,
        DATE_TRUNC('month', meeting_date_et) AS meeting_month,
        MIN(meeting_start_at)                AS first_rc_start_at
    FROM filtered
    WHERE meeting_category = 'RC'
      AND is_completed
      AND deal_id IS NOT NULL
    GROUP BY deal_id, DATE_TRUNC('month', meeting_date_et)
)

SELECT
    f.meeting_id,
    f.closer_owner_id,
    f.activity_type,
    f.activity_type_key,
    f.meeting_category,
    f.meeting_outcome,
    f.meeting_date_et,
    f.deal_id,
    f.is_booked,
    f.is_completed,
    COALESCE(cr.is_first_call, TRUE) AS is_first_call,
    (
        f.meeting_category IN ('RC', 'PWC', 'WB')
        AND f.is_completed
        -- Deliberate fallback (Travis/Derek): only exclude a PWC when we can positively place it
        -- after a same-deal, same-month RC. Any case we can't pin down that way -- no deal_id
        -- (unlinked meeting), no RC that month, or the PWC isn't the later of the two -- counts
        -- both calls rather than guessing which one to drop.
        AND NOT (
            f.meeting_category = 'PWC'
            AND f.deal_id IS NOT NULL
            AND rc.first_rc_start_at IS NOT NULL
            AND f.meeting_start_at > rc.first_rc_start_at
        )
    ) AS is_closing_call
FROM filtered AS f
LEFT JOIN completed_ranked AS cr ON f.meeting_id = cr.meeting_id
LEFT JOIN rc_month_anchor AS rc
    ON f.deal_id = rc.deal_id
    AND DATE_TRUNC('month', f.meeting_date_et) = rc.meeting_month
