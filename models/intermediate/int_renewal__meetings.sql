-- Renewal meetings categorized into PC / RC / PWC (spec Meeting Type Reference), attributed to closers.
-- Booked = outcome not canceled; Completed/Show = exactly COMPLETED (renewal team uses plain outcomes).

WITH meetings AS (
    SELECT * FROM {{ ref('stg_renewal__meetings') }}
),

closers AS (
    SELECT owner_id FROM {{ ref('dim_closers') }}
),

categorized AS (
    SELECT
        m.meeting_id,
        m.owner_id                              AS closer_owner_id,
        m.activity_type,
        m.meeting_outcome,
        {{ to_et_date('m.meeting_start_at') }}  AS meeting_date_et,
        CASE
            WHEN m.activity_type IN ('Renewal 3 Month', 'Renewal Accelerator 3 month')
                THEN 'PC'
            WHEN m.activity_type IN (
                'Renewal Strategy', 'Renewal Strategy Alignment', 'Renewal Accelerator',
                'Renewal Accelerator Evergreen', 'Renewal Follow-up'
            ) THEN 'RC'
            WHEN m.activity_type = 'Renewal Post Webinar Call'
                THEN 'PWC'
            ELSE NULL
        END                                     AS meeting_category,
        {{ is_meeting_booked('m.meeting_outcome') }}     AS is_booked,
        {{ is_meeting_completed('m.meeting_outcome') }}  AS is_completed
    FROM meetings AS m
    INNER JOIN closers AS c ON m.owner_id = c.owner_id
)

SELECT * FROM categorized
WHERE meeting_category IS NOT NULL
