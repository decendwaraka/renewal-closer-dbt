{#
    The two meeting types that put a deal into PC Close % (HubSpot report 445343752, Celeste 2026-10-21):
    "Call and meeting type is any of Renewal 3 Month or Renewal Accelerator 3 month", with the meeting
    outcome exactly Completed (is_meeting_completed -- COMPLETED - NURTURE / - QUALIFIED don't count).

    One list so the next HubSpot rename is a one-line fix, like dpl_call_types(). Lowercase on purpose:
    consumers match on LOWER(TRIM(activity_type)).
#}
{% macro pc_close_call_types() %}
    'renewal 3 month',
    'renewal accelerator 3 month'
{% endmacro %}
