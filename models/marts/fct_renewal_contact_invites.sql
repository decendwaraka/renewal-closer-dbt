-- Invited side of Call Outcomes, contact grain. One row per
-- (contact_id, invite_flow, invite_tier, invited_date_et).
--
-- Replaces fct_renewal_stage_entries' pc_invited / rc_invited as the source for the dashboard's Invited
-- column and the denominator of Book% (metric tiles #10, #13, #16, #19, #52, #54). See
-- stg_renewal__contact_invites.sql for why the basis moved from deals to contacts on 2026-08-28.
--
-- Deliberately a flat dated fact, NOT pre-aggregated to a month, matching the convention in
-- fct_renewal_cash (cash_date_et per row) and fct_renewal_stage_entries (entry_date_et per row): the
-- frontend applies its own window, so MTD / prior-MTD / any custom range all work off one table.
--
-- NOT scoped to dim_closers. contact_owner_id is exposed raw and the reporting layer joins dim_closers
-- itself. Consequence worth knowing before someone files it as a bug: August 2026 has 2 invited contacts
-- (1 booked) on an off-roster owner, so the dashboard's per-closer rows sum to 199 invited / 101 booked
-- while this table and her report read 201 / 102. The dashboard is a closer scorecard; that gap is
-- correct, not a leak.
--
-- Book% is now plain Booked / Invited on these two marts and is capped at 100% by construction, because
-- the booked cohort is a filtered subset of this one. That is what OPEN_ISSUES #41 was chasing.

{{ config(materialized='table') }}

SELECT
    contact_id,
    contact_owner_id,
    invite_flow,
    invite_tier,
    invited_date_et
FROM {{ ref('stg_renewal__contact_invites') }}
