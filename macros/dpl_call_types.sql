{#
    The six call types that count as a "live call" for Avg DPL (Celeste, 2026-10-19).

    Taken from her HubSpot report 445533588, which is the authority for the DPL denominator. That
    report applies NO meeting-outcome filter and NO per-deal dedup -- every call of these six types
    in the window counts once, credited to the meeting's owner and dated by the meeting date. Avg DPL
    is therefore total cash / all such calls, not cash / completed first calls. Before this, DPL ran
    off is_closing_call, which is completed-only and deduped, and came out roughly 100 calls short of
    her report for a 30-day window.

    Deliberately a macro rather than two hardcoded lists: int_renewal__live_call_contacts (Live Call
    Close Rate, the 2026-10-18 HubSpot cohort replica) already matched on this exact set, and a second
    copy inside int_renewal__meetings would be free to drift from it the next time HubSpot renames a
    meeting type -- which it did to all four Win-Back types on 2026-10-11. One list, two consumers.

    `mentor handoff` and `winback webinar` span meeting_category values (MENTOR_HANDOFF and WB_WEBINAR),
    so is_dpl_call must be derived from this list directly, never from meeting_category.

    Every literal is lowercase on purpose: both consumers match on LOWER(TRIM(activity_type)), so a
    re-cased HubSpot duplicate can't silently fall out of the denominator.
#}
{% macro dpl_call_types() %}
    'renewal accelerator',
    'renewal strategy',
    'renewal post webinar call',
    'mentor handoff',
    'winback call',
    'winback webinar'
{% endmacro %}
