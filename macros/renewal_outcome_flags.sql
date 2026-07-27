{# Meeting outcome flags.
   Spec claimed the renewal team uses plain outcomes only, but Snowflake data shows sub-outcomes DO occur
   (COMPLETED - NURTURE, COMPLETED - QUALIFIED) — see OPEN_ISSUES #7. A "COMPLETED - *" call did complete,
   so Completed/Show counts use LIKE 'COMPLETED%' (matches setter-dbt outcome_bucket), NOT exact equality.
   Booked = not canceled (NULL outcomes excluded, per strict spec NOT IN ('CANCELED') semantics). #}

{% macro is_meeting_booked(outcome_col) %}
    ({{ outcome_col }} IS NOT NULL AND {{ outcome_col }} NOT IN ('CANCELED', 'CANCELLED'))
{% endmacro %}

{% macro is_meeting_completed(outcome_col) %}
    ({{ outcome_col }} LIKE 'COMPLETED%')
{% endmacro %}
