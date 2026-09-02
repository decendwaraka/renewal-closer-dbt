-- Renewal meetings -> contacts, dated by when the meeting RECORD was created. This is the "booked" side
-- of Celeste's True Booking Rate report: one row per (contact_id, meeting_id) for every renewal-type
-- meeting whose hs_createdate falls in the window.
--
-- Deliberately NOT built on int_renewal__meetings, even though that is where meeting categorization lives.
-- int_renewal__meetings INNER JOINs dim_closers on the MEETING owner, and her report attributes on the
-- CONTACT owner and puts no condition at all on who owns the meeting. Reusing it would drop bookings whose
-- meeting sits with a non-closer and understate the numerator. Confirmed against live August 2026: without
-- the meeting-owner restriction this reproduces her report exactly (201 invited / 102 booked / 50.75%
-- against her 201 / 101 / 50.25%, the +1 being ordinary Fivetran sync drift).
--
-- The type list below is the union of the (now-retired-type-trimmed) PC, RC and PWC branches of
-- int_renewal__meetings, matched on the same LOWER(TRIM(...)) key for the same reason: HubSpot allows the
-- same activity type under several casings (e.g. `Renewal Follow-Up` with a capital U, which appeared
-- 2026-08-24 and was still being created before Follow-up was retired) and matching raw would miss them.
--
-- Two deliberate differences from her six literal activity types, both EXCLUSIONS:
--   * `Renewal Winback Call` still EXCLUDED. It is not on her filter panel and is category WB, not a
--     renewal booking. This one is load-bearing: 153 of its 158 meetings were created in August 2026, so
--     folding it in would inflate the booked side substantially.
--   * `Renewal Follow-up` and `Renewal Strategy Alignment` are now BOTH excluded (business confirmed
--     2026-09-02), retiring them from Booked the same way int_renewal__meetings retired them from RC.
--     `Renewal Strategy Alignment` was never on her panel to begin with (it was added here 2026-08-28 only
--     to track int_renewal__meetings' RC bucket at the time). `Renewal Follow-up` IS one of her six panel
--     types, so this is a deliberate divergence from her live report, not a bug -- expect this table to
--     undercount her "True Booked" figure by however many Follow-up meetings fall in the window, going
--     forward. 91 Strategy Alignment + some volume of Follow-up meetings affected; Strategy Alignment's 91
--     are all Oct 2025 - Jun 2026 (zero in August), so historical ranges move more than the current window.
-- Keep every remaining literal below lowercase, and in lockstep with the CASE in int_renewal__meetings.
--
-- No meeting-outcome filter. A booking counts the moment the meeting record exists, regardless of whether
-- the call later completed, no-showed or was canceled -- her report has no outcome condition. Completed
-- and Show% keep their own meeting-record basis and are untouched by this model.

WITH meetings AS (
    SELECT
        meeting_id,
        activity_type,
        LOWER(TRIM(activity_type)) AS activity_type_key,
        created_at
    FROM {{ ref('stg_renewal__meetings') }}
),

renewal_meetings AS (
    SELECT * FROM meetings
    WHERE activity_type_key IN (
        -- PC
        'renewal 3 month', 'renewal accelerator 3 month',
        -- RC
        'renewal strategy',
        'renewal accelerator',
        -- PWC
        'renewal post webinar call'
    )
    AND created_at IS NOT NULL
),

-- ENGAGEMENT_CONTACT has no _fivetran_deleted column (verified against the live table); the meeting-side
-- soft-delete filter in stg_renewal__meetings is what keeps deleted meetings out.
engagement_contact AS (
    SELECT
        engagement_id,
        contact_id::VARCHAR AS contact_id
    FROM {{ source('hubspot_raw', 'ENGAGEMENT_CONTACT') }}
    WHERE contact_id IS NOT NULL
)

SELECT
    ec.contact_id,
    m.meeting_id,
    m.activity_type,
    m.activity_type_key,
    {{ to_et_date('m.created_at') }} AS booked_date_et
FROM renewal_meetings AS m
INNER JOIN engagement_contact AS ec ON m.meeting_id = ec.engagement_id
