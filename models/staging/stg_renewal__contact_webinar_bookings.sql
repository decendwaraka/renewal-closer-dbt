-- Interim Post-Webinar attribution (Celeste/RevOps, Slack 2026-08-14) -- OPEN_ISSUES #33.
-- renewal_webinars__booked's value embeds the booking date directly (e.g. "RW 7.14.2026"), so this
-- parses it out of the current CONTACT value rather than reading CONTACT_PROPERTY_HISTORY.
-- Stopgap: Celeste is building a deal-level property for this; swap over once it ships.

WITH parsed AS (
    SELECT
        id::VARCHAR AS contact_id,
        REGEXP_SUBSTR(property_renewal_webinars_booked, '[0-9]{1,2}[.][0-9]{1,2}[.][0-9]{4}') AS date_token
    FROM {{ source('hubspot_raw', 'CONTACT') }}
    WHERE property_renewal_webinars_booked IS NOT NULL
      AND COALESCE(_fivetran_deleted, FALSE) = FALSE
)

SELECT
    contact_id,
    TRY_TO_DATE(date_token, 'MM.DD.YYYY') AS booked_at_et
FROM parsed
WHERE TRY_TO_DATE(date_token, 'MM.DD.YYYY') IS NOT NULL
