{{ config(severity='warn') }}
-- Visibility, not a gate: an additional payment with an amount but no Collected Date is EXCLUDED from
-- cash (Celeste, 2026-10-21 -- only payments with the date filled in count). Returns each such payment
-- so the team can ask the rep to fill the date in; the cash shows up in the month it is entered.
{% for i in range(1, 13) %}
{% if not loop.first %}UNION ALL{% endif %}
SELECT deal_id, closer_owner_id, 'ap{{ i }}' AS cash_component, ap{{ i }}_amount AS amount
FROM {{ ref('int_renewal__won_deals') }}
WHERE ap{{ i }}_amount > 0 AND ap{{ i }}_stamped_at IS NULL
{% endfor %}
