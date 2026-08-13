-- Renewal meetings categorized into PC / RC / PWC / WB (spec Meeting Type Reference + OPEN_ISSUES #12),
-- attributed to closers.
-- Booked = outcome not canceled; Completed/Show = exactly COMPLETED (renewal team uses plain outcomes).

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
        m.meeting_outcome,
        m.meeting_start_at,
        {{ to_et_date('m.meeting_start_at') }}  AS meeting_date_et,
        md.deal_id,
        CASE
            WHEN m.activity_type IN ('Renewal 3 Month', 'Renewal Accelerator 3 month')
                THEN 'PC'
            WHEN m.activity_type IN (
                'Renewal Strategy', 'Renewal Strategy Alignment', 'Renewal Accelerator',
                'Renewal Accelerator Evergreen', 'Renewal Follow-up'
            ) THEN 'RC'
            WHEN m.activity_type = 'Renewal Post Webinar Call'
                THEN 'PWC'
            WHEN m.activity_type = 'Renewal Winback Call'
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
)

SELECT
    f.meeting_id,
    f.closer_owner_id,
    f.activity_type,
    f.meeting_category,
    f.meeting_outcome,
    f.meeting_date_et,
    f.deal_id,
    f.is_booked,
    f.is_completed,
    COALESCE(cr.is_first_call, TRUE) AS is_first_call
FROM filtered AS f
LEFT JOIN completed_ranked AS cr ON f.meeting_id = cr.meeting_id
