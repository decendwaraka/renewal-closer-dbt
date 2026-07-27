{% macro to_et_date(ts_col) %}
    CONVERT_TIMEZONE('America/New_York', {{ ts_col }})::DATE
{% endmacro %}
