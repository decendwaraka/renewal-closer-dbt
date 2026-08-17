{#
    Reads a column from a source table only if it actually exists there yet, falling back to a typed
    NULL otherwise -- for HubSpot properties that are confirmed real (Fivetran hasn't synced the column
    because no deal has ever had a value) so referencing them directly would break the build today.
    Checks the LIVE warehouse schema on every run (adapter.get_columns_in_relation), not a hardcoded
    list, so the moment Fivetran adds the column, the next `dbt run` picks it up automatically -- no
    code change needed then. `execute` guard: during parse-only invocations (docs generate, `dbt parse`)
    there's no live connection, so it safely falls back to NULL rather than erroring.
#}
{% macro safe_source_column(source_name, table_name, column_name, cast_type) %}
{%- set existing_cols = [] -%}
{%- if execute -%}
    {%- set relation = source(source_name, table_name) -%}
    {%- set existing_cols = adapter.get_columns_in_relation(relation) | map(attribute='name') | map('upper') | list -%}
{%- endif -%}
{%- if column_name.upper() in existing_cols -%}
{{ column_name }}
{%- else -%}
CAST(NULL AS {{ cast_type }})
{%- endif -%}
{% endmacro %}
