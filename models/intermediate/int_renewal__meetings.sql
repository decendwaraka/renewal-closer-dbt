-- Renewal meetings categorized into PC / RC / PWC / WB (spec Meeting Type Reference + OPEN_ISSUES #12),
-- attributed to closers.
-- Booked = outcome not canceled; Completed/Show = exactly COMPLETED (renewal team uses plain outcomes).
--
-- Categorization matches on activity_type_key -- activity_type lowercased and trimmed -- NOT on the raw
-- string, so a re-cased duplicate of an existing type can't silently fall out of every metric. Keep every
-- literal below lowercase, and let the unit tests feed a raw HubSpot string to exercise it.
--
-- RC list, reconciled 2026-09-02 (business confirmed): `Renewal Follow-up`, `Renewal Strategy
-- Alignment` and `Renewal Accelerator Evergreen` are all retired from the RC bucket -- none of them
-- earn Close Rate or DPL credit, and only `Renewal Strategy` and `Renewal Accelerator` remain in RC.
--
-- Follow-up and Mentor Handoff restored to Call Outcomes, 2026-10-19 (Celeste, Metrics Guide #2/#3b):
-- retiring `Renewal Follow-up` from RC also dropped it out of the model entirely, so the Call Outcomes
-- table stopped showing calls the team had actually run (~75 completed Follow-ups in a 30-day window)
-- and closers' activity looked lower than it was. `Mentor Handoff` had never been categorized at all.
-- Both now get their own meeting_category -- FOLLOW_UP and MENTOR_HANDOFF -- exactly as WB_FOLLOW_UP /
-- WB_WEBINAR do: counted on Call Outcomes, deliberately left OUT of the IN ('RC','PWC','WB') lists
-- below so they are never first-call ranked and never earn Close Rate credit. The business reason is
-- that neither is a renewal pitch: a Follow-up revisits a call that already happened, and a Mentor
-- Handoff transfers the member to a mentor, so crediting either with a close would double-count the
-- original RC. `Renewal Strategy Alignment` STAYS fully retired (Celeste, 2026-10-19) -- it was not
-- part of this restore and still maps to no category.
--
-- is_dpl_call is a separate flag, NOT derived from meeting_category: Celeste's Avg DPL report
-- 445533588 counts `mentor handoff` (MENTOR_HANDOFF) and `winback webinar` (WB_WEBINAR) alongside the
-- RC/PWC/WB types, so the DPL denominator cuts across categories. See the dpl_call_types() macro for
-- why it is shared with int_renewal__live_call_contacts and why there is no outcome filter or dedup.
--
-- is_closing_call drops a PWC from Close Rate credit when the same deal already has a completed RC
-- that same calendar month (Travis, live) -- the credit belongs to the RC, not a repeat count. This
-- applies regardless of which of the two happened first within the month (fixed 2026-10-05,
-- OPEN_ISSUES Close Rate contact-count review): the PWC is dropped whenever a same-month RC exists,
-- not only when the RC is the earlier of the two. See rc_month_anchor below; when the ordering can't
-- be pinned down at all (no deal_id, or no RC that month) both calls count, per the agreed fallback.
--
-- is_closing_call also requires is_first_call for RC/PWC/WB (fixed 2026-10-05, same review): without
-- it, two completed calls in the same category on the same deal (e.g. two RCs on one member in one
-- month) both earned Close Rate credit. is_first_call already identifies the earlier call per
-- (deal_id, meeting_category); is_closing_call now defers to it instead of re-deriving its own
-- dedup. Unlinked meetings (deal_id IS NULL) are unaffected -- they default is_first_call to TRUE,
-- same as before.
--
-- Win-Back types, reconciled 2026-10-11 (Celeste): HubSpot renamed the Win-Back meeting types, and
-- for hs_activity_type the stored value IS the label, so the rename changed the value too.
-- `Renewal Winback Call` is no longer a HubSpot option; `Winback Call` replaced it (in use since
-- 2026-08-04, ~100 calls this model was silently dropping). Both map to WB. The Follow-Up and
-- Webinar types (old and new names) count on Call Outcomes only, per Celeste -- they get their own
-- categories, WB_FOLLOW_UP and WB_WEBINAR, so they stay out of is_first_call / is_closing_call and
-- never earn Close Rate or DPL credit. The dashboard folds all three into the Win-Back row, same
-- way it folds PWC into RC.

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
            WHEN LOWER(TRIM(m.activity_type)) IN ('renewal winback call', 'winback call')
                THEN 'WB'
            WHEN LOWER(TRIM(m.activity_type)) IN ('renewal winback follow-up', 'winback follow-up')
                THEN 'WB_FOLLOW_UP'
            WHEN LOWER(TRIM(m.activity_type)) IN ('renewal winback webinar call', 'winback webinar')
                THEN 'WB_WEBINAR'
            -- Call Outcomes only (Celeste, 2026-10-19). Both spellings of Follow-up exist in live
            -- HubSpot data; LOWER(TRIM()) already collapses the Follow-up/Follow-Up casing pair, so
            -- these two literals are the hyphen/space variants, not the casing ones.
            WHEN LOWER(TRIM(m.activity_type)) IN ('renewal follow-up', 'renewal follow up')
                THEN 'FOLLOW_UP'
            WHEN LOWER(TRIM(m.activity_type)) = 'mentor handoff'
                THEN 'MENTOR_HANDOFF'
            ELSE NULL
        END                                     AS meeting_category,
        -- Avg DPL denominator (Celeste, 2026-10-19, HubSpot report 445533588): every call of the six
        -- DPL types, ANY outcome, no dedup. Flagged off activity_type_key rather than meeting_category
        -- because the six types span four categories (RC, PWC, WB, WB_WEBINAR, MENTOR_HANDOFF).
        LOWER(TRIM(m.activity_type)) IN ({{ dpl_call_types() }})  AS is_dpl_call,
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
    f.is_dpl_call,
    COALESCE(cr.is_first_call, TRUE) AS is_first_call,
    (
        f.meeting_category IN ('RC', 'PWC', 'WB')
        AND f.is_completed
        -- First-call dedup: a repeat completed call in the same category on the same deal (e.g. a
        -- second RC on one member in one month) never earns its own Close Rate credit.
        AND COALESCE(cr.is_first_call, TRUE)
        -- Deliberate fallback (Travis/Derek): only exclude a PWC when we can positively place a
        -- same-deal, same-month RC against it. Any case we can't pin down that way -- no deal_id
        -- (unlinked meeting) or no RC that month -- counts both calls rather than guessing which
        -- one to drop. Order within the month no longer matters: the credit belongs to the RC
        -- whether the PWC landed before or after it.
        AND NOT (
            f.meeting_category = 'PWC'
            AND f.deal_id IS NOT NULL
            AND rc.first_rc_start_at IS NOT NULL
        )
    ) AS is_closing_call
FROM filtered AS f
LEFT JOIN completed_ranked AS cr ON f.meeting_id = cr.meeting_id
LEFT JOIN rc_month_anchor AS rc
    ON f.deal_id = rc.deal_id
    AND DATE_TRUNC('month', f.meeting_date_et) = rc.meeting_month
