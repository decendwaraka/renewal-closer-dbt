-- HubSpot Pipeline Snapshot (#36-#51). LIVE deal-stage counts per closer -- NOT date filtered.
-- Counts each closer's deals by current stage, mapped to wireframe columns via dim_renewal_stages.

WITH deals AS (
    SELECT
        deal_id,
        closer_owner_id,
        dealstage_id
    FROM {{ ref('stg_renewal__deals') }}
),

stages AS (
    SELECT stage_id, pipeline_id, stage_group, snapshot_col FROM {{ ref('dim_renewal_stages') }}
),

closers AS (
    SELECT owner_id, closer_name FROM {{ ref('dim_closers') }}
),

joined AS (
    SELECT
        d.closer_owner_id,
        cl.closer_name,
        s.pipeline_id,
        s.stage_group,
        s.snapshot_col,
        d.deal_id
    FROM deals AS d
    INNER JOIN stages AS s ON d.dealstage_id = s.stage_id
    INNER JOIN closers AS cl ON d.closer_owner_id = cl.owner_id
),

final AS (
    SELECT
        closer_owner_id,
        closer_name,
        pipeline_id,
        stage_group,
        snapshot_col,
        COUNT(deal_id) AS deal_count
    FROM joined
    GROUP BY 1, 2, 3, 4, 5
)

SELECT * FROM final
