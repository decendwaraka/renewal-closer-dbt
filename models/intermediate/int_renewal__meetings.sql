-- Renewal meetings categorized into PC / RC / PWC / WB (spec Meeting Type Reference + OPEN_ISSUES #12),
-- attributed to closers.
-- Booked = outcome not canceled; Completed/Show = exactly COMPLETED (renewal team uses plain outcomes).
--
-- Categorization matches on activity_type_key -- activity_type lowercased and trimmed -- NOT on the raw
-- string, so a re-cased duplicate of an existing type can't silently fall out of every metric. HubSpot
-- allows both: `Renewal Follow-Up` appeared 2026-08-24 alongside the long-standing `Renewal Follow-up`
-- and is still being created. Matching raw dropped those 17 meetings to meeting_category = NULL and then
-- out of the model, understating RC Completed by 9 and RC booked by 12 for August 2026, and growing.
-- Normalizing here rather than in staging keeps it next to the categorization it protects, and lets the
-- unit tests feed a raw HubSpot string and actually exercise it. Keep every literal below lowercase.
--
-- Report-side guard only -- the duplicate value should still be merged in HubSpot. It drops the same
-- meetings from Celeste's own True Booking Rate report, whose filter matches `Renewal Follow-up` too.
--
-- RC list, reconciled 2026-08-28 against the dashboard's SHARED_FILTERS
-- (Dashboards/renewal-closer-dashboard/src/lib/metric-catalog.ts), which documents five types:
--   * `Renewal Strategy Alignment` ADDED -- 92 meetings, 55 completed, none after 2026-06-03. Its
--     omission was an oversight; RC was understated for every window before June 2026.
--   * `Renewal Accelerator Evergreen` deliberately still EXCLUDED -- retired per Celeste, and locked in
--     by the test_meetings_closing_call_flag_and_retired_activity_types unit test. SHARED_FILTERS listing
--     it is a documentation error; fix the doc, not this CASE. (1 meeting, 2026-07-18.)
-- Neither type has a meeting in August 2026, so no current window moves.

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
            WHEN LOWER(TRIM(m.activity_type)) IN (
                'renewal strategy', 'renewal strategy alignment',
                'renewal accelerator', 'renewal follow-up'
            ) THEN 'RC'
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
    -- Excludes follow-ups on the normalized key, not the raw string, and has to stay in lockstep with the
    -- RC branch above: normalize the category while matching raw 'Renewal Follow-up' here and the 17
    -- re-cased `Renewal Follow-Up` meetings become closing calls, inflating the Leaderboard's Live Call
    -- Close % (#3) and DPL denominators by 9 for August 2026.
    -- Renewal Strategy Alignment is deliberately NOT excluded -- it's a substantive live call, not a
    -- follow-up, so joining the RC bucket makes it a closing call too. That shifts Live Call Close %,
    -- DPL, live_meetings_ex_webinar and the first-call dedup for Oct 2025 - Jun 2026 (55 completed
    -- calls). No August effect.
    (
        f.meeting_category IN ('RC', 'PWC', 'WB')
        AND f.is_completed
        AND COALESCE(f.activity_type_key, '') != 'renewal follow-up'
    ) AS is_closing_call
FROM filtered AS f
LEFT JOIN completed_ranked AS cr ON f.meeting_id = cr.meeting_id
