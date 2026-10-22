-- PC Close % population at (deal, qualifying meeting) grain. Replicates the team's HubSpot report 445343752
-- (confirmed 2026-10-21 from its Configure / Filters screenshots, then backtested):
--   * deal has NEVER entered Renewal Call Complete - Nurture, or Renewal Call Invited / Scheduled in
--     either pipeline (stg_renewal__deals.ever_entered_pc_close_excluded_stage);
--   * deal has at least one COMPLETED Renewal 3 Month / Renewal Accelerator 3 month meeting, joined through a
--     CONTACT: meeting -> contact -> deal. The report is built on Contacts (primary) with Deals and Meetings
--     attached through each contact's associations, so a row only exists when one contact links both the
--     meeting and the deal. A direct meeting -> deal link does NOT count on its own.
--   * Won = deal currently in one of the three closed-won stages (var won_stage_ids).
-- No pipeline filter (the report has none; restricting to the renewal pipelines would give 678 deals, not
-- 2,246) and no test-contact exclusion (the report has none).
--
-- The report's "Flag - Renewal Post Webinar Completed 30d = 0" filter is deliberately NOT applied. The flag
-- needs hs_activity_type = 'Renewal Post Webinar Call', but the report only keeps 3 Month / Accelerator
-- meetings, so it is 0 on every row. Backtested all-time: without it 2,247 deals / 161 won (report: 2,246 /
-- 161); applying it per deal gives 2,218 / 132. Confirmed against the 2026-10-22 export of the report: the
-- contact-route model equals it row for row without the flag.
--
-- Dated by the MEETING start day (ET), not Renewal Close Date (Celeste approved 2026-10-21): 2,071 of the
-- 2,247 qualifying deals have no Renewal Close Date and none of them is won, so a close-date window would
-- drop every open or lost deal. Open and lost deals stay in the denominator; a won deal need not have
-- closed inside the window. All-time, this equals the report.
--
-- Count deals with COUNT(DISTINCT deal_id) at query time over any window -- a deal with several qualifying
-- meetings has several rows. Attributed to the DEAL owner (the report's attribution), not the meeting owner.
-- Owners absent from dim_closers (or no owner) are kept with a NULL closer_name so the dashboard can show
-- an Other / unassigned row and reconcile to the report's total.
--
-- Both association inputs resolve merged-away contact ids (stg_renewal__contact_merges), as in
-- int_renewal__live_call_contacts.
--
-- Why not also follow ENGAGEMENT_DEAL (the direct meeting -> deal link)? An earlier version did, and it
-- over-counted by exactly one deal (2026-10-22): a completed 3 Month meeting with NO contact that links
-- straight to three deals. HubSpot's report can't see a contactless meeting, so it never counted that deal.
-- With the contact route only, the model equals the report's export row for row (2,420 deal x meeting
-- pairs, 2,421 deal x meeting x contact rows, 2,259 deals / 161 won on 2026-10-22). It also drops any
-- exposure to stale ENGAGEMENT_DEAL rows -- Fivetran has no delete tracking for the engagement tables.

WITH meetings AS (
    SELECT
        m.meeting_id,
        {{ to_et_date('m.meeting_start_at') }} AS meeting_date_et
    FROM {{ ref('stg_renewal__meetings') }} AS m
    WHERE LOWER(TRIM(m.activity_type)) IN ({{ pc_close_call_types() }})
      AND {{ is_meeting_completed('m.meeting_outcome') }}
),

meeting_deals AS (
    SELECT DISTINCT ec.meeting_id, dc.deal_id::VARCHAR AS deal_id
    FROM {{ ref('stg_renewal__engagement_contacts') }} AS ec
    INNER JOIN {{ ref('stg_renewal__deal_contact_pairs') }} AS dc ON ec.contact_id = dc.contact_id
)

SELECT
    d.deal_id,
    m.meeting_id,
    m.meeting_date_et,
    d.closer_owner_id,
    cl.closer_name,
    d.dealstage_id IN (
        {{ "'" ~ var('won_stage_ids') | join("','") ~ "'" }}
    ) AS is_won
FROM meetings AS m
INNER JOIN meeting_deals AS md ON m.meeting_id = md.meeting_id
INNER JOIN {{ ref('stg_renewal__deals') }} AS d ON md.deal_id = d.deal_id::VARCHAR
LEFT JOIN {{ ref('dim_closers') }} AS cl ON d.closer_owner_id = cl.owner_id::VARCHAR
WHERE NOT d.ever_entered_pc_close_excluded_stage
