-- Meeting-to-deal association, for first-call dedup (OPEN_ISSUES #23). A meeting can be associated with
-- more than one deal in HubSpot (e.g. an old + new deal on the same contact) -- confirmed live, a handful
-- of engagement_ids carry 2 deal_id rows in ENGAGEMENT_DEAL. When that happens, prefer whichever deal is
-- in one of the renewal/win-back pipelines this project actually tracks, since that's the deal a renewal
-- call's dedup logic cares about; MAX(deal_id) is a deterministic tiebreak if still ambiguous.

WITH assoc AS (
    SELECT engagement_id, deal_id
    FROM {{ source('hubspot_raw', 'ENGAGEMENT_DEAL') }}
),

deals AS (
    SELECT deal_id, pipeline_id FROM {{ ref('stg_renewal__deals') }}
),

ranked AS (
    SELECT
        a.engagement_id AS meeting_id,
        a.deal_id,
        ROW_NUMBER() OVER (
            PARTITION BY a.engagement_id
            ORDER BY
                CASE
                    WHEN d.pipeline_id IN ({{ "'" ~ var('renewal_pipeline_ids') | join("','") ~ "'" }})
                        OR d.pipeline_id = '{{ var('winback_pipeline_id') }}'
                    THEN 0 ELSE 1
                END,
                a.deal_id DESC
        ) AS rn
    FROM assoc AS a
    LEFT JOIN deals AS d ON a.deal_id = d.deal_id
)

SELECT meeting_id, deal_id
FROM ranked
WHERE rn = 1
