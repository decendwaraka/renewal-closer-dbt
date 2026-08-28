-- Contact-grain renewal invites: the six HubSpot CONTACT date properties that Celeste's live
-- "True Booking Rate" report ORs together, unpivoted to one row per
-- (contact_id, invite_flow, invite_tier, invited_date_et).
--
-- Why contacts and not deals (2026-08-28). Until now Call Outcomes Invited/Booked/Book% read
-- fct_renewal_stage_entries -- DEAL stage-entry dates. Celeste named those deal properties in Slack on
-- 2026-08-18 12:50 ET, but her actual report has never used them: its filter panel is these six contact
-- properties. On 2026-08-28 she settled it with "match the HubSpot report". That closes OPEN_ISSUES #41
-- (Book% over 100%) and #47 (her unreconcilable 87) in one go -- #47 was chased against RAW.DEAL for two
-- rounds and could never have landed there, because on contact properties August 2026 splits Midway 107 /
-- Renewal Call 94 with no overlap, which is her 201.
--
-- One row PER TIER, not collapsed to one per (contact, flow). A contact can hold a Midway MM date in
-- August and a Midway ACC date in September; her report ORs the properties, so that contact belongs to
-- BOTH windows. Collapsing to a MIN/MAX date would silently drop it from one of them. Downstream always
-- counts COUNT(DISTINCT contact_id), so the tier fan-out never double-counts inside a single window.
--
-- invite_flow maps to the dashboard's existing PC/RC columns: PC = the three Midway Call Invited
-- properties, RC = the three Renewal Call Invited properties. Verified disjoint for August 2026 -- 0
-- contacts carry both -- which is why 107 + 94 = 201 exactly.
--
-- PROPERTY_FOLLOW_UP_CALL_INVITED_BGP also exists on CONTACT and is deliberately NOT included: it is not
-- on her report's filter panel.
--
-- Mirrors the UNION-ALL-per-component Jinja pattern in fct_renewal_stage_entries.sql.

{% set invite_components = [
    ('PC', 'MM',  'property_midway_call_invited'),
    ('PC', 'ACC', 'property_midway_call_invited_acc'),
    ('PC', '2YR', 'property_midway_call_invited_2_yr'),
    ('RC', 'MM',  'property_renewal_call_invited'),
    ('RC', 'ACC', 'property_renewal_call_invited_acc'),
    ('RC', '2YR', 'property_renewal_call_invited_2_yr'),
] %}

WITH contacts AS (
    SELECT
        id::VARCHAR                             AS contact_id,
        property_hubspot_owner_id::VARCHAR      AS contact_owner_id,
        {% for _, _, col in invite_components -%}
        {{ col }},
        {% endfor -%}
        property_hs_lead_status                 AS lead_status
    FROM {{ source('hubspot_raw', 'CONTACT') }}
    WHERE COALESCE(_fivetran_deleted, FALSE) = FALSE
),

-- Same Internal Test Record exclusion as stg_renewal__deal_contacts.sql, applied here on the contact
-- directly rather than bridged through DEAL_CONTACT. Her report does not carry this filter, so it is a
-- deliberate (tiny) divergence for consistency with every other population in this project.
scoped AS (
    SELECT * FROM contacts
    WHERE COALESCE(lead_status, '') != 'Internal Test Record'
)

{% for flow, tier, col in invite_components %}
{% if not loop.first %}
UNION ALL
{% endif %}
SELECT
    contact_id,
    contact_owner_id,
    '{{ flow }}'            AS invite_flow,
    '{{ tier }}'            AS invite_tier,
    {{ to_et_date(col) }}   AS invited_date_et
FROM scoped
WHERE {{ col }} IS NOT NULL
{% endfor %}
