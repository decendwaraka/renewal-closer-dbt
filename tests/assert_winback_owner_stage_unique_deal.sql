-- fct_winback_pipeline_owner_stage is one row per deal. A deal has exactly one current stage and at most
-- one owner, so the joins cannot fan out unless dim_renewal_stages or dim_closers gains a duplicate key --
-- which would silently inflate every count. Returns offending deals (test fails if any).

SELECT deal_id, COUNT(*) AS n
FROM {{ ref('fct_winback_pipeline_owner_stage') }}
GROUP BY deal_id
HAVING COUNT(*) > 1
