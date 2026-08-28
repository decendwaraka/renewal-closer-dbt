-- Book% can never exceed 100% on the contact cohort. This is the structural guarantee that closes
-- OPEN_ISSUES #41, where the old deal-stage build read over 100% because it compared two INDEPENDENT
-- tallies -- a deal could enter Scheduled in a window without ever entering Invited in it.
--
-- Asserted against the real join the dashboard issues (snowflake.server.ts, queryContactInvitesByCloser),
-- not against the tables in isolation, because the cap is a property of that join and not of either mart:
-- fct_renewal_contact_bookings deliberately holds bookings for contacts outside any invited cohort. Run
-- per (owner, flow, calendar month) over every month present, so a regression shows up on the historical
-- windows the dashboard's date picker can reach, not just the current one.
--
-- Fails if any group reports more booked contacts than invited contacts. Booked is a filtered subset of
-- invited by construction, so any row here means the join lost its anchor -- most likely someone changed
-- the LEFT JOIN's direction or moved the date predicate off the joined side.

WITH invites AS (
    SELECT
        contact_owner_id,
        invite_flow,
        DATE_TRUNC('month', invited_date_et) AS window_month,
        contact_id,
        invited_date_et
    FROM {{ ref('fct_renewal_contact_invites') }}
),

joined AS (
    SELECT
        i.contact_owner_id,
        i.invite_flow,
        i.window_month,
        COUNT(DISTINCT i.contact_id) AS invited,
        COUNT(DISTINCT CASE WHEN b.contact_id IS NOT NULL THEN i.contact_id END) AS booked
    FROM invites AS i
    LEFT JOIN {{ ref('fct_renewal_contact_bookings') }} AS b
           ON b.contact_id = i.contact_id
          AND DATE_TRUNC('month', b.booked_date_et) = i.window_month
    GROUP BY 1, 2, 3
)

SELECT * FROM joined
WHERE booked > invited
