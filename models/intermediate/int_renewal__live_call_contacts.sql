-- Live Call Close Rate at contact grain -- one row per (meeting_id, contact_id). Replicates the team's
-- HubSpot "Live to Close Rate" report (2026-10-18), which reproduced exactly from these raw tables for
-- September 2026 (24/48, 12/39, 21/44, 11/59, team 68/190).
--
-- The report's definition:
--   Denominator: distinct contacts on a COMPLETED live call owned by a closer in the window.
--   Numerator:   those contacts with ANY associated deal in a closed-won stage whose upsell___close_date
--                day is on or after the meeting day -- no upper bound (a September call that closes in
--                October counts for September), and regardless of deal owner or pipeline.
-- Close Rate = distinct won contacts / distinct contacts, counted at query time over the window so any
-- date range works. A contact counts as won for the window if any of its meetings in the window is
-- is_won_after_meeting -- which is exactly COUNT(DISTINCT IFF(is_won_after_meeting, contact_id, NULL)).
--
-- The activity-type list deliberately differs from int_renewal__meetings' meeting_category buckets, to
-- match the report exactly:
--   * includes `Mentor Handoff` and `Winback Webinar`, which aren't RC/PWC/WB live calls elsewhere;
--   * excludes the legacy `Renewal Winback Call` value (still being created alongside `Winback Call`).
-- Nor is there any first-call or PWC-after-RC dedup -- the report counts contacts, not calls.
--
-- The list moved into the dpl_call_types() macro on 2026-10-19 (Celeste): her Avg DPL report 445533588
-- turned out to use the same six types, so int_renewal__meetings.is_dpl_call now reads the same macro.
-- Keeping one definition means the next HubSpot meeting-type rename (as happened to all four Win-Back
-- types on 2026-10-11) can't fix Close Rate while silently leaving DPL broken, or vice versa.
-- The Today tiles keep using is_closing_call; only Close Rate reads this model.
--
-- No Internal Test contact exclusion either: the report has none.
--
-- Both association inputs resolve merged-away contact ids to the surviving contact
-- (stg_renewal__contact_merges). Without that, Jan-Oct 2026 missed 5 won contacts across 4 closer-months.
-- With it, every closer-month cell matches the report. The only exception is the team total for Jun-Aug,
-- where Henna Shakoor (still on dim_closers, kept deliberately so Close % uses the same roster as the
-- other leaderboard cards) adds 4/5/1 contacts the report's 4-owner filter leaves out.

WITH meetings AS (
    SELECT
        m.meeting_id,
        m.owner_id                             AS closer_owner_id,
        m.activity_type,
        {{ to_et_date('m.meeting_start_at') }} AS meeting_date_et
    FROM {{ ref('stg_renewal__meetings') }} AS m
    INNER JOIN {{ ref('dim_closers') }} AS c ON m.owner_id = c.owner_id
    WHERE LOWER(TRIM(m.activity_type)) IN ({{ dpl_call_types() }})
      AND {{ is_meeting_completed('m.meeting_outcome') }}
),

meeting_contacts AS (
    SELECT m.*, ec.contact_id
    FROM meetings AS m
    INNER JOIN {{ ref('stg_renewal__engagement_contacts') }} AS ec ON m.meeting_id = ec.meeting_id
),

won_contact_deals AS (
    SELECT
        dc.contact_id,
        {{ hubspot_date_to_et_date('d.close_date') }} AS close_date_et
    FROM {{ ref('stg_renewal__deals') }} AS d
    INNER JOIN {{ ref('stg_renewal__deal_contact_pairs') }} AS dc ON d.deal_id = dc.deal_id
    WHERE d.dealstage_id IN (
        {{ "'" ~ (var('won_stage_ids') + var('winback_won_stage_ids')) | join("','") ~ "'" }}
    )
)

SELECT
    mc.meeting_id,
    mc.contact_id,
    mc.closer_owner_id,
    mc.activity_type,
    mc.meeting_date_et,
    COUNT(w.contact_id) > 0 AS is_won_after_meeting,
    MIN(w.close_date_et)    AS first_won_close_date_et
FROM meeting_contacts AS mc
LEFT JOIN won_contact_deals AS w
    ON mc.contact_id = w.contact_id
    AND w.close_date_et >= mc.meeting_date_et
GROUP BY 1, 2, 3, 4, 5
