{{ config(materialized='view') }}

-- Wide per-closer reporting table for the dashboard leaderboards (#1-#4), Today snapshot (#5-#9),
-- and vs-prior-month (#35). MTD vs same-elapsed-days prior month, plus goal columns from dim_targets.
-- Goals are TEAM totals; the dashboard sums closer rows for team progress. One row per closer.
--
-- OPEN ISSUE #1: cash columns reflect base+AP1+AP2 only (warehouse sync gap).
-- OPEN ISSUE #4: day-bucketing standardized to ET via to_et_date to match HubSpot MTD boundaries.
-- OPEN ISSUE #5: goal values in dim_targets are placeholders.

WITH anchors AS (
    SELECT DATE(CONVERT_TIMEZONE('America/New_York', CURRENT_TIMESTAMP())) AS today_et
),

bounds AS (
    SELECT
        today_et,
        DATEADD('day', -1, today_et)                                        AS yesterday_et,
        DATE_TRUNC('month', today_et)                                       AS mtd_start,
        today_et                                                            AS mtd_end,
        DATE_TRUNC('month', DATEADD('month', -1, today_et))                 AS prior_month_start,
        LEAST(
            DATEADD('day', DAY(today_et) - 1, DATE_TRUNC('month', DATEADD('month', -1, today_et))),
            LAST_DAY(DATEADD('month', -1, today_et))
        )                                                                   AS prior_mtd_end
    FROM anchors
),

cash_agg AS (
    SELECT
        c.closer_owner_id,
        SUM(CASE WHEN c.cash_date_et BETWEEN b.mtd_start AND b.mtd_end THEN c.cash_amount ELSE 0 END)                       AS cash_mtd,
        SUM(CASE WHEN c.cash_date_et BETWEEN b.prior_month_start AND b.prior_mtd_end THEN c.cash_amount ELSE 0 END)         AS cash_prior_mtd,
        SUM(CASE WHEN c.cash_date_et = b.today_et THEN c.cash_amount ELSE 0 END)                                            AS cash_today,
        SUM(CASE WHEN c.cash_date_et = b.yesterday_et THEN c.cash_amount ELSE 0 END)                                        AS cash_yesterday
    FROM {{ ref('fct_renewal_cash') }} AS c
    CROSS JOIN bounds AS b
    GROUP BY 1
),

deals_agg AS (
    SELECT
        w.closer_owner_id,
        COUNT_IF(w.close_date_et BETWEEN b.mtd_start AND b.mtd_end)                    AS deals_won_mtd,
        COUNT_IF(w.close_date_et BETWEEN b.prior_month_start AND b.prior_mtd_end)      AS deals_won_prior_mtd,
        COUNT_IF(w.close_date_et = b.today_et)                                         AS deals_today
    FROM {{ ref('int_renewal__won_deals') }} AS w
    CROSS JOIN bounds AS b
    GROUP BY 1
),

meetings_agg AS (
    SELECT
        m.closer_owner_id,
        COUNT_IF(m.meeting_category IN ('RC', 'PWC') AND m.is_completed AND m.meeting_date_et BETWEEN b.mtd_start AND b.mtd_end)               AS live_meetings_mtd,
        COUNT_IF(m.meeting_category IN ('RC', 'PWC') AND m.is_completed AND m.meeting_date_et BETWEEN b.prior_month_start AND b.prior_mtd_end) AS live_meetings_prior_mtd
    FROM {{ ref('fct_renewal_meetings') }} AS m
    CROSS JOIN bounds AS b
    GROUP BY 1
),

targets AS (
    SELECT
        MAX(CASE WHEN metric = 'total_cash' THEN target_value END)      AS goal_total_cash,
        MAX(CASE WHEN metric = 'deals_won' THEN target_value END)       AS goal_deals_won,
        MAX(CASE WHEN metric = 'live_close_pct' THEN target_value END)  AS goal_live_close_pct,
        MAX(CASE WHEN metric = 'avg_dpl' THEN target_value END)         AS goal_avg_dpl
    FROM {{ ref('dim_targets') }}
),

final AS (
    SELECT
        cl.owner_id                                                     AS closer_owner_id,
        cl.closer_name,
        b.today_et,
        b.mtd_start,
        b.mtd_end,
        b.prior_month_start,
        b.prior_mtd_end,

        COALESCE(ca.cash_mtd, 0)                                        AS cash_mtd,
        COALESCE(ca.cash_prior_mtd, 0)                                  AS cash_prior_mtd,
        COALESCE(ca.cash_mtd, 0) - COALESCE(ca.cash_prior_mtd, 0)       AS cash_vs_prior_mtd,
        COALESCE(ca.cash_today, 0)                                      AS cash_today,
        COALESCE(ca.cash_today, 0) - COALESCE(ca.cash_yesterday, 0)     AS cash_today_vs_yesterday,

        COALESCE(da.deals_won_mtd, 0)                                   AS deals_won_mtd,
        COALESCE(da.deals_won_prior_mtd, 0)                             AS deals_won_prior_mtd,
        COALESCE(da.deals_won_mtd, 0) - COALESCE(da.deals_won_prior_mtd, 0) AS deals_vs_prior_mtd,
        COALESCE(da.deals_today, 0)                                     AS deals_today,

        COALESCE(ma.live_meetings_mtd, 0)                               AS live_meetings_mtd,
        ROUND(100 * COALESCE(da.deals_won_mtd, 0) / NULLIF(ma.live_meetings_mtd, 0), 0) AS live_close_pct,
        ROUND(COALESCE(ca.cash_mtd, 0) / NULLIF(ma.live_meetings_mtd, 0), 0)            AS avg_dpl,

        t.goal_total_cash,
        t.goal_deals_won,
        t.goal_live_close_pct,
        t.goal_avg_dpl
    FROM {{ ref('dim_closers') }} AS cl
    LEFT JOIN cash_agg AS ca ON cl.owner_id = ca.closer_owner_id
    LEFT JOIN deals_agg AS da ON cl.owner_id = da.closer_owner_id
    LEFT JOIN meetings_agg AS ma ON cl.owner_id = ma.closer_owner_id
    CROSS JOIN targets AS t
    CROSS JOIN bounds AS b
)

SELECT * FROM final
