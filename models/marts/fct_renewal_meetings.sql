{{ config(materialized='view') }}

-- Meeting-grain fact for Call Outcomes (#10-#21), Today (#5,#6), Booking/Show (#52-#57).
-- One row per renewal meeting with category (PC/RC/PWC) and booked/completed flags.

WITH meetings AS (
    SELECT * FROM {{ ref('int_renewal__meetings') }}
),

final AS (
    SELECT
        m.meeting_id,
        m.closer_owner_id,
        cl.closer_name,
        m.activity_type,
        m.meeting_category,
        m.meeting_outcome,
        m.meeting_date_et,
        m.is_booked,
        m.is_completed
    FROM meetings AS m
    LEFT JOIN {{ ref('dim_closers') }} AS cl ON m.closer_owner_id = cl.owner_id
)

SELECT * FROM final
