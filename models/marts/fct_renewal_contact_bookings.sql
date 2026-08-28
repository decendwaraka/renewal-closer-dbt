-- Booked side of Call Outcomes, contact grain. One row per (contact_id, meeting_id) with the ET date the
-- meeting record was created.
--
-- Split out from fct_renewal_contact_invites rather than folded in as an is_booked flag, which is what the
-- original plan called for. A static flag on the invite row cannot answer the dashboard's date picker: the
-- window has to be applied to the booked side INDEPENDENTLY of the invited side, because that is what her
-- report does -- both sides are dated to the same range, and a contact invited in August whose booking
-- landed in July is not a booking for the August window. A single first_booked_date_et column would also
-- have been wrong for the contacts holding several bookings.
--
-- Not restricted to the invited flow. Her report does not split PC from RC anywhere, so a Renewal or
-- Post-Webinar booking counts for a Midway-invited contact. Same-flow-only was measured and moves August
-- 2026 by exactly one contact (PC 64 vs 65, RC 37 vs 37) -- not worth diverging from her report over.
-- The consequence is that PC Booked and RC Booked share this table and a contact in both flows could be
-- credited twice; verified moot for August, where the two invited cohorts are disjoint.
--
-- No ordering constraint between invite and booking, again because her report has none: a contact invited
-- Aug 20 whose meeting was created Aug 2 counts as booked from that invite. Reproduced faithfully rather
-- than silently corrected, and flagged back to her.

{{ config(materialized='table') }}

SELECT
    contact_id,
    meeting_id,
    activity_type,
    activity_type_key,
    booked_date_et
FROM {{ ref('stg_renewal__meeting_contacts') }}
