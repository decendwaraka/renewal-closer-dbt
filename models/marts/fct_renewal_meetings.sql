{{ config(materialized='view') }}

-- Meeting-grain fact for Call Outcomes (#10-#21), Today (#5,#6), Booking/Show (#52-#57).
-- One row per renewal meeting with category (PC/RC/PWC/WB/WB_FOLLOW_UP/WB_WEBINAR/FOLLOW_UP/
-- MENTOR_HANDOFF) and booked/completed flags.
-- is_first_call (OPEN_ISSUES #23) flags the first completed call per deal within a meeting-type group --
-- Close Rate filters on it to exclude follow-up calls; Call Outcomes counts (Invited/Booked/Completed)
-- intentionally do NOT filter on it, since those are meeting-count metrics by design.
--
-- is_dpl_call (Celeste, 2026-10-19) is the Avg DPL denominator and is NOT is_closing_call: it counts
-- every call of the six types in dpl_call_types() at any outcome with no dedup, matching her HubSpot
-- report 445533588. Read it on its own -- pairing it with is_completed or is_first_call reintroduces
-- exactly the filtering her report does not do and puts DPL back to roughly 100 calls short per month.

WITH meetings AS (
    SELECT * FROM {{ ref('int_renewal__meetings') }}
),

final AS (
    SELECT
        m.meeting_id,
        m.closer_owner_id,
        cl.closer_name,
        m.activity_type,
        m.activity_type_key,
        m.meeting_category,
        m.meeting_outcome,
        m.meeting_date_et,
        m.deal_id,
        m.is_booked,
        m.is_completed,
        m.is_dpl_call,
        m.is_first_call,
        m.is_closing_call
    FROM meetings AS m
    LEFT JOIN {{ ref('dim_closers') }} AS cl ON m.closer_owner_id = cl.owner_id
)

SELECT * FROM final
