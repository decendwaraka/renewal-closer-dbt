{% macro hubspot_date_to_et_date(date_col) %}
    {{ date_col }}::DATE
{% endmacro %}
