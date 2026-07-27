{% macro effective_cash(cash_col, amount_col) %}
    COALESCE(NULLIF({{ cash_col }}, 0), {{ amount_col }})
{% endmacro %}
