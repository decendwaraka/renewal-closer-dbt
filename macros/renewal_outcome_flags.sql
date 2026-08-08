{# Meeting outcome flags.
   Sub-outcomes DO occur in the data (COMPLETED - NURTURE, COMPLETED - QUALIFIED) even though the spec
   says the renewal team only uses plain outcomes — see OPEN_ISSUES Resolved (#7, 2026-08-06). Decision:
   follow the spec literally — Completed/Show uses exact `= 'COMPLETED'`, excluding sub-outcomes.
   Booked = not canceled (NULL outcomes excluded, per strict spec NOT IN ('CANCELED') semantics). #}

{% macro is_meeting_booked(outcome_col) %}
    ({{ outcome_col }} IS NOT NULL AND {{ outcome_col }} NOT IN ('CANCELED', 'CANCELLED'))
{% endmacro %}

{% macro is_meeting_completed(outcome_col) %}
    ({{ outcome_col }} = 'COMPLETED')
{% endmacro %}
