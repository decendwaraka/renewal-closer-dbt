-- Cash amounts should never be negative. Returns offending rows (test fails if any).
SELECT deal_id, cash_component, cash_amount
FROM {{ ref('fct_renewal_cash') }}
WHERE cash_amount < 0
