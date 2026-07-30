{% macro hubspot_date_to_et_date(date_col) %}
    -- HubSpot DATE-typed properties (e.g. upsell___close_date, additional_payment_*_stamped_date)
    -- are stored as midnight UTC and represent a calendar date, not a moment in time.
    -- Running to_et_date()'s CONVERT_TIMEZONE on them pushes midnight UTC back to ~8pm the
    -- previous day in ET, shifting the date -1 day. Casting straight to DATE preserves the
    -- intended calendar date with no spurious timezone shift.
    -- Use to_et_date() only for genuine datetimes (e.g. hs_meeting_start_time).
    {{ date_col }}::DATE
{% endmacro %}
