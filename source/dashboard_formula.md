# Renewal Closer Dashboard — Tile Formulas

Reference sheet for every tile/KPI/card in the **Renewal - Closer** dashboard
(Lovable project `f2d85030-8092-4224-a52c-93ab7398ecaa`). Data reads live from
Snowflake `PRODUCTION.RENEWAL_MARTS`. Each tile below lists a **description**,
the **exact SQL / derived expression** from source, and the **source
table/columns**.

Source files: `src/routes/index.tsx` (layout/goals), `src/lib/snowflake.server.ts`
(SQL), `src/components/dashboard/OutcomeTables.tsx` + `PipelineTables.tsx`
(derived rates), `src/lib/dashboard-data.ts` (formatters).

---

## Date window (applies to windowed sections)

- **Default = Last 30 days (ET).** Presets: Yesterday, Last 3 / 7 / 14 / 30 days, Custom.
- **Prior period** = the equal-length window immediately before the selected one.
  Description: if you pick the last 30 days, "prior" is the 30 days before that.
  - `len = daysBetweenInclusive(start, end)`
  - `prior_end = start − 1 day`, `prior_start = prior_end − (len − 1) days`
- All dates are **ET calendar days**, inclusive, `BETWEEN start AND end`.
- **Today Snapshot** and **HubSpot Pipeline Snapshot** ignore the window — always current.

---

## Section 1 — Leaderboards (4 cards)

Each card shows a team **hero** number, a **goal/progress** bar, a **vs-prior** delta,
and a **per-closer ranked** list. Team values are pooled sums across closers.

### 1. The Rainmaker · Total Cash
- **Description:** Total cash collected in the selected window. Per closer, then summed
  for the team hero. The delta shows this window's cash minus the prior window's cash.
- **SQL:**
  ```sql
  SELECT closer_name, SUM(cash_amount) AS cash
  FROM PRODUCTION.RENEWAL_MARTS.FCT_RENEWAL_CASH
  WHERE cash_date_et BETWEEN <start> AND <end>
  GROUP BY 1
  ```
  - Team hero = `Σ cash_mtd`; `cash_vs_prior = cash(window) − cash(prior window)` (same query on prior dates).
- **Source:** `FCT_RENEWAL_CASH` (`cash_amount`, `cash_date_et`, `closer_name`).
- **Goal/target:** team $350K, per-closer $70K. Progress = value ÷ goal.

### 2. Mayo Connoisseur · Deals Won
- **Description:** Count of won deals with a close date inside the window, per closer, summed for the team.
- **SQL:**
  ```sql
  SELECT closer_name, COUNT(*) AS deals
  FROM PRODUCTION.RENEWAL_MARTS.FCT_RENEWAL_WON_DEALS
  WHERE close_date_et BETWEEN <start> AND <end>
  GROUP BY 1
  ```
- **Source:** `FCT_RENEWAL_WON_DEALS` (`close_date_et`, `closer_name`).
- **Goal:** team 30, per-closer 6.

### 3. Live Call Close %
- **Description:** Of the "live" closing calls a closer completed, what share turned into a
  won deal. Live call = a completed Renewal Call (RC) or Post-Webinar Call (PWC).
  `Close % = Deals Won ÷ Live Meetings`. The team number is a **pooled** ratio (total deals ÷
  total live meetings), not the average of each closer's rate.
- **Derived expression:**
  - `live_close_pct = live > 0 ? deals_won / live_meetings : 0`  (per closer)
  - `team.live_close_pct = teamDeals / teamLive`
- **Live meetings SQL:**
  ```sql
  SELECT closer_name,
         COUNT_IF(meeting_category IN ('RC','PWC') AND is_completed) AS live
  FROM PRODUCTION.RENEWAL_MARTS.FCT_RENEWAL_MEETINGS
  WHERE meeting_date_et BETWEEN <start> AND <end>
  GROUP BY 1
  ```
- **Source:** `deals_won` from card 2; `live` from `FCT_RENEWAL_MEETINGS`
  (`meeting_category`, `is_completed`, `meeting_date_et`).
- **Target:** 30%.

### 4. Most Valuable Asset · Avg $ per Live Call (DPL)
- **Description:** Average dollars generated per completed live call.
  `DPL = Cash ÷ Live Meetings`.
- **Derived expression:**
  - `avg_dpl = live > 0 ? cash / live_meetings : 0`  (per closer)
  - `team.avg_dpl = teamCash / teamLive`
- **Source:** `cash` (card 1) ÷ `live` (card 3).
- **Target:** $3,500.

---

## Section 2 — Today Snapshot (5 cards, always today ET)

"Today" = `DATE(CONVERT_TIMEZONE('America/New_York', CURRENT_TIMESTAMP()))`.
Not affected by the date-range selector.

### 5. Closing Calls Today
- **Description:** Number of closing calls (RC or PWC) completed today.
- **SQL:** `COUNT_IF(meeting_category IN ('RC','PWC') AND is_completed)` where `meeting_date_et = <today ET>`.
- **Source:** `FCT_RENEWAL_MEETINGS`.

### 6. Midway Calls Today
- **Description:** Number of Progress Calls (PC) completed today.
- **SQL:** `COUNT_IF(meeting_category = 'PC' AND is_completed)` where `meeting_date_et = <today ET>`.
- **Source:** `FCT_RENEWAL_MEETINGS`.
- (Cards 5 & 6 come from one query — see `queryTodayCallCounts`.)

### 7. Deals Closed Today
- **Description:** Total deals closed today across all closers.
- **Derived:** `Σ deals_today` over closers.
- **SQL (per closer):**
  ```sql
  SELECT closer_name, cash_today, cash_today_vs_yesterday, deals_today
  FROM PRODUCTION.RENEWAL_MARTS.RPT_RENEWAL_CLOSER_DASHBOARD
  ```
- **Source:** `RPT_RENEWAL_CLOSER_DASHBOARD` (`deals_today`).

### 8. Cash Closed Today
- **Description:** Total cash collected today; the sub-line shows today vs yesterday.
- **Derived:** value = `Σ cash_today`; sub = `Σ cash_today_vs_yesterday`.
- **Source:** `RPT_RENEWAL_CLOSER_DASHBOARD` (`cash_today`, `cash_today_vs_yesterday`).

### 9. On Fire Today 🔥
- **Description:** The closer with the most cash collected today (only if > $0). Shows their
  initials, name, and today's cash.
- **Derived:** `top = closers sorted desc by cash_today; show top if top.cash_today > 0, else "—"`.
- **Source:** `RPT_RENEWAL_CLOSER_DASHBOARD` (`cash_today`, `closer_name`).

---

## Section 3 — Call Outcomes table (per closer + Average row)

Windowed. One query returns raw counts; the percentage columns are computed client-side.
Columns are split into **Progress Call (PC)** and **Renewal Call (RC)** groups, each with
Invited / Booked / Completed / Book% / Show% / Close%.

- **Counts SQL:**
  ```sql
  SELECT closer_name,
    COUNT_IF(meeting_category='PC')                        AS pc_invited,
    COUNT_IF(meeting_category='PC' AND is_booked)          AS pc_booked,
    COUNT_IF(meeting_category='PC' AND is_completed)       AS pc_completed,
    COUNT_IF(meeting_category='RC')                        AS rc_invited,
    COUNT_IF(meeting_category='RC' AND is_booked)          AS rc_booked,
    COUNT_IF(meeting_category='RC' AND is_completed)       AS rc_completed,
    COUNT_IF(meeting_category='PWC' AND is_completed)      AS pwc_completed
  FROM PRODUCTION.RENEWAL_MARTS.FCT_RENEWAL_MEETINGS
  WHERE meeting_date_et BETWEEN <start> AND <end>
  GROUP BY 1
  ```
- **Source:** `FCT_RENEWAL_MEETINGS` (`meeting_category`, `is_booked`, `is_completed`, `meeting_date_et`);
  `deals_won` joined in from card 2.

**Column formulas (both PC and RC):**

| Column | Description | Expression |
|---|---|---|
| Invited | Calls invited/created in window | `COUNT_IF(category = X)` |
| Booked | Of those, how many got booked | `COUNT_IF(category = X AND is_booked)` |
| Completed | Of those, how many were completed/showed | `COUNT_IF(category = X AND is_completed)` |
| **Book%** | Booked ÷ Invited | `safePct(booked, invited)` → `booked / invited × 100` |
| **Show%** | Completed ÷ Booked (show-up rate) | `safePct(completed, booked)` |
| **Close%** | Deals Won ÷ Completed (of shown calls, share that closed) | `safePct(deals_won, completed)` |

- `safePct(num, den)` returns `null` (rendered "—") when `den ≤ 0`; otherwise `num / den × 100`, rounded.
- **Average row** = **pooled** ratio: sum the numerators and denominators across all closers first,
  then divide (`Σbooked / Σinvited`, etc.). It is **not** the mean of the per-closer percentages.
- Note: Close% uses the *same* `deals_won` in both the PC and RC groups (deals aren't split by call type).

---

## Section 4 — Cash by Pipeline Type table

Windowed. Cash broken out per closer by renewal term/product, plus Total / #Closed / Close% / vs Prior.

- **Description:** For each closer, cash collected in the window bucketed into product columns,
  with a row Total, the number of deals closed, and the change vs the prior window.
- **SQL:**
  ```sql
  SELECT closer_name, product_column, SUM(cash_amount) AS cash
  FROM PRODUCTION.RENEWAL_MARTS.FCT_RENEWAL_CASH
  WHERE cash_date_et BETWEEN <start> AND <end>
  GROUP BY 1, 2
  ```
- **Product columns** (`product_column` → display): `MM_T1/T2/T3/RESTART` (Mastermind Renewals),
  `ACC_T1/T2/UPGRADE/RESTART` (ACC Renewals), `MM_UPGRADE`, `REFERRAL` (Other).
- **Total** = per-closer window cash (`cash_mtd`, i.e. `Σ cash_amount` in window).
- **# Closed** = deals won in window (`deals_won_mtd`, from card 2).
- **vs Prior MTD** = `cash(window) − cash(prior window)` (signed; green up / red down).
- **Close%** column: currently **non-functional** — always renders "—" (the placeholder math
  multiplies by 0). Deals-per-pipeline isn't carried in this data shape.
- **Source:** `FCT_RENEWAL_CASH` (`cash_amount`, `product_column`, `cash_date_et`, `closer_name`).

> ⚠️ **Known gap:** product columns show **$0** until RevOps ships the `upsell_plan → product`
> mapping (OPEN_ISSUES #2). The **Total** column is accurate; only the per-product split is pending.

---

## Section 5 — HubSpot Pipeline Snapshot table

**Live snapshot — NOT date filtered.** Current deal counts per closer per pipeline stage.

- **Description:** For each closer, how many deals currently sit in each pipeline stage/bucket,
  with a row Total = sum of all its stage counts.
- **SQL:**
  ```sql
  SELECT closer_name, snapshot_col, SUM(deal_count) AS deals
  FROM PRODUCTION.RENEWAL_MARTS.FCT_RENEWAL_PIPELINE_SNAPSHOT
  GROUP BY 1, 2
  ```
- **Columns** (`snapshot_col`), grouped:
  - **Progress Call:** PC Due, PC Invited, PC Scheduled, PC Not Cmplt, PC Completed
  - **Renewal Call:** RC Due, RC Invited, RC Scheduled, RC Not Cmplt
  - **Other:** Nurture, Redzone, Closed Won, Closed Lost, New Member, PC1 Compl.
- **Total** = `Σ` of all 15 columns for the row.
- **Source:** `FCT_RENEWAL_PIPELINE_SNAPSHOT` (`snapshot_col`, `deal_count`, `closer_name`).

---

## Section 6 — Booking & Show Rates table

Windowed. A condensed rate view using the **same** counts as Section 3.

- **Description:** Per closer, the PC and RC booking and show-up rates, plus the count of
  completed Post-Webinar Calls.
- **Columns:**
  | Column | Description | Expression |
  |---|---|---|
  | PC Book% | PC Booked ÷ PC Invited | `safePct(pc_booked, pc_invited)` |
  | PC Show% | PC Completed ÷ PC Booked | `safePct(pc_completed, pc_booked)` |
  | RC Book% | RC Booked ÷ RC Invited | `safePct(rc_booked, rc_invited)` |
  | RC Show% | RC Completed ÷ RC Booked | `safePct(rc_completed, rc_booked)` |
  | PWC Completed | Completed post-webinar calls (count) | `pwc_completed` |
  | PWC Close% | PWC Deals Won ÷ PWC Completed (spec #57) -- numerator scoped to post-webinar-attributed closes only (OPEN_ISSUES #33), distinct from PC/RC/WB Close% | `safePct(pwc_deals_won, pwc_completed)` |
- **Average row** = pooled ratio (`Σ` numerators ÷ `Σ` denominators), same as Section 3.
- **Source:** `FCT_RENEWAL_MEETINGS` (same query as Section 3).

---

## Appendix

### Formatters (`src/lib/dashboard-data.ts`)
- **`fmtMoneyK(n)`** — money with K-suffix: `≥1000 → $X.YK` (0 decimals if ≥100K), else `$N`.
- **`fmtMoneyKSigned(n)`** — same, with `+`/`-` sign.
- **`fmtMoney(n)`** — full dollars with thousands separators, e.g. `$4,184`.
- **`fmtPct(x)`** — `round(toRatio(x) × 100)%`.
- **`toRatio(x)`** — normalizes a percent-shaped value to a 0..1 ratio: if `x > 1`, divide by 100
  (guards against Snowflake returning `22` for 22% instead of `0.22`).
- **`safePct(num, den)`** (tables) — `den ≤ 0 → "—"`, else `num/den × 100` rounded.

### Data-source badge (`src/routes/index.tsx`)
- **● live** — all Snowflake queries succeeded.
- **● partial** — some queries succeeded; failed sections fall back to seed values (badge yellow,
  error banner lists failed sections).
- **● seed data** — Snowflake not configured / no live query succeeded; all values are seed constants.
- Seed values live in `SEED_*` constants and are used only when a query throws.

### Goals / targets
- Per closer: cash $70K, deals 6, close% 30%, DPL $3,500.
- Team: cash $350K, deals 30, close% 30%, DPL $3,500.

### Known gaps (cross-ref `OPEN_ISSUES.md`)
- **#2** Cash-by-Pipeline product split — $0 until `upsell_plan → product` mapping ships (Total accurate).
- **#4** Freshness — meeting source syncs ~daily; **Show%** reads a few points low vs live HubSpot
  (reps disposition SCHEDULED→COMPLETED after the last sync).
- **#5** ET-vs-UTC day bucketing (`to_et_date` macro).
- **#7** "Completed" uses `LIKE 'COMPLETED%'` (also counts COMPLETED-NURTURE/QUALIFIED) — deviates
  from spec, pending RevOps sign-off.
- Section 4 **Close%** column is a non-functional placeholder (renders "—").

---

## Formula Debug Reference

Per-metric debug lookup for **data engineers** and **HubSpot developers**. One collapsed card per
dashboard metric — expand a tile to trace a single number end-to-end: what it measures, the written
formula, the exact SQL/derived expression, the warehouse column it comes from, and the raw HubSpot
source (object, activity types / stage IDs / properties, and filters). The `#N` is the stable
identifier from the Formula Spec v2 (57 formulas).

**Shared filters** (assumed on every tile unless noted, so they aren't repeated below):
- **Closers** = `hubspot_owner_id ∈ (82672208 Sufijan Cunningham, 756332149 Abe Underwood, 82734543 Elisabeth Rogers, 756339074 Melissa Davis, 76930546 Henna Shakoor)`.
- **Pipelines** = Renewal Sales Pipeline `95211801` + Renewal Pipeline `898243912`.
- **Won stages** = `dealstage ∈ (Renewal Closed Won - PIF 175346331, Renewal Closed Won - Payment Plan 229787714, Closed Won 1359841456)`.
- **Deal close date** = `upsell___close_date` (Renewal - Close Date).
- **11-component cash** = `cash_collected + additional_payment__1_amount + additional_payment__2_amount + collected_amount__additional_payment_3 … _10`, each component summed on **its own** stamped/collected date field within the range. *(Warehouse `FCT_RENEWAL_CASH.cash_amount` currently carries base+AP1+AP2 only — see Appendix.)*
- **PC types** = `hs_activity_type ∈ ('Renewal 3 Month','Renewal Accelerator 3 month')`.
- **RC types** = `hs_activity_type ∈ ('Renewal Strategy','Renewal Accelerator','Renewal Accelerator Evergreen')`. (Renewal Strategy Alignment and Renewal Follow-up retired from RC, business confirmed 2026-09-02.)
- **PWC type** = `hs_activity_type = 'Renewal Post Webinar Call'`.
- **Meeting attribution/date** = `hubspot_owner_id` on the MEETING · `hs_meeting_start_time`. **Completed** = `hs_meeting_outcome = 'COMPLETED'`; **Booked** = `hs_meeting_outcome NOT IN ('CANCELED')`.

<details>
<summary><b>▶ Expand — all 57 formulas</b></summary>

#### Leaderboards

<details>
<summary><code>#1</code> · The Rainmaker — Total Cash</summary>

- **Description:** Total cash collected in the window, per closer, summed for the team hero. Delta = this window vs prior window.
- **Formula:** Σ (11-component cash) for the closer, over deals in the window.
- **SQL / derived:** `SUM(cash_amount)` from `FCT_RENEWAL_CASH WHERE cash_date_et BETWEEN start AND end GROUP BY closer_name`; team = `Σ cash_mtd`; `cash_vs_prior = cash(window) − cash(prior window)`.
- **Warehouse:** `FCT_RENEWAL_CASH` → `cash_amount`, `cash_date_et`, `closer_name`.
- **HubSpot:** DEAL · 11-component cash · Pipelines · Won stages · Closers · each component on its own date field in range.

</details>

<details>
<summary><code>#2</code> · Mayo Connoisseur — Deals Won</summary>

- **Description:** Count of won deals closing in the window, per closer, summed for the team.
- **Formula:** COUNT of closed-won deals with close date in the window.
- **SQL / derived:** `COUNT(*)` from `FCT_RENEWAL_WON_DEALS WHERE close_date_et BETWEEN start AND end GROUP BY closer_name`.
- **Warehouse:** `FCT_RENEWAL_WON_DEALS` → `close_date_et`, `closer_name`.
- **HubSpot:** DEAL · Pipelines · Won stages · Closers · `upsell___close_date` in range.

</details>

<details>
<summary><code>#3</code> · Live Call Close %</summary>

- **Description:** Of completed live calls (RC + PWC), the share that became a won deal.
- **Formula:** Deals Won ÷ Live Meetings × 100  (live = completed RC + PWC). Team = pooled Σdeals ÷ Σlive.
- **SQL / derived:** `live = COUNT_IF(meeting_category IN ('RC','PWC') AND is_completed)`; `live_close_pct = deals_won / live`.
- **Warehouse:** `FCT_RENEWAL_MEETINGS` (`meeting_category`, `is_completed`) + `deals_won` (#2).
- **HubSpot:** Numerator DEAL (won, close date in range, Closers); Denominator MEETING = **RC types + PWC type** with Completed, Closers, `hs_meeting_start_time` in range. Target 30%.

</details>

<details>
<summary><code>#4</code> · Most Valuable Asset — Avg $ per Live Call (DPL)</summary>

- **Description:** Average dollars generated per completed live call.
- **Formula:** Total Cash ÷ Live Meetings  (same denominator as #3).
- **SQL / derived:** `avg_dpl = cash / live` (per closer); team = `teamCash / teamLive`.
- **Warehouse:** `FCT_RENEWAL_CASH.cash_amount` ÷ `FCT_RENEWAL_MEETINGS` live count.
- **HubSpot:** Numerator = 11-component cash (as #1); Denominator = completed RC + PWC meetings (as #3). Target $3,500.

</details>

#### Today Snapshot (always today ET)

<details>
<summary><code>#5</code> · Closing Calls Today</summary>

- **Description:** Completed closing calls (RC + PWC) today.
- **Formula:** COUNT of completed RC + PWC meetings where meeting date = today (ET).
- **SQL / derived:** `COUNT_IF(meeting_category IN ('RC','PWC') AND is_completed)` where `meeting_date_et = DATE(CONVERT_TIMEZONE('America/New_York', CURRENT_TIMESTAMP()))`.
- **Warehouse:** `FCT_RENEWAL_MEETINGS`.
- **HubSpot:** MEETING · RC types + PWC type · Completed · Closers · `hs_meeting_start_time = today`.

</details>

<details>
<summary><code>#6</code> · Midway Calls Today</summary>

- **Description:** Completed Progress Calls (PC) today.
- **Formula:** COUNT of completed PC meetings where meeting date = today (ET).
- **SQL / derived:** `COUNT_IF(meeting_category = 'PC' AND is_completed)` where `meeting_date_et = today (ET)`.
- **Warehouse:** `FCT_RENEWAL_MEETINGS`.
- **HubSpot:** MEETING · PC types · Completed · Closers · `hs_meeting_start_time = today`.

</details>

<details>
<summary><code>#7</code> · Deals Closed Today</summary>

- **Description:** Total deals closed won today across all closers.
- **Formula:** Σ deals_today over closers.
- **SQL / derived:** `SELECT deals_today FROM RPT_RENEWAL_CLOSER_DASHBOARD` → `Σ deals_today`.
- **Warehouse:** `RPT_RENEWAL_CLOSER_DASHBOARD` → `deals_today`.
- **HubSpot:** DEAL · Pipelines · Won stages · Closers · `upsell___close_date = today`.

</details>

<details>
<summary><code>#8</code> · Cash Closed Today</summary>

- **Description:** Total cash collected today; sub-line = today vs yesterday.
- **Formula:** Σ cash_today; delta = Σ cash_today_vs_yesterday.
- **SQL / derived:** `Σ cash_today`, `Σ cash_today_vs_yesterday` from `RPT_RENEWAL_CLOSER_DASHBOARD`.
- **Warehouse:** `RPT_RENEWAL_CLOSER_DASHBOARD` → `cash_today`, `cash_today_vs_yesterday`.
- **HubSpot:** DEAL · 11-component cash · Pipelines · Won stages · Closers · each component date = today.

</details>

<details>
<summary><code>#9</code> · On Fire Today 🔥</summary>

- **Description:** Closer with the most cash collected today (only if > $0).
- **Formula:** argmax(cash_today) where cash_today > 0.
- **SQL / derived:** `top = closers sorted desc by cash_today; show if top.cash_today > 0 else "—"`.
- **Warehouse:** `RPT_RENEWAL_CLOSER_DASHBOARD` → `cash_today`, `closer_name`.
- **HubSpot:** Derived from #8 (rank closers by today's cash).

</details>

#### Call Outcomes (windowed; PC = #10–15, RC = #16–21)

<details>
<summary><code>#10</code> · PC Invited</summary>

- **Description:** All Progress Call meetings in the window, any outcome (top of PC funnel; counts meetings, not members).
- **Formula:** COUNT of PC meetings in range.
- **SQL / derived:** `COUNT_IF(meeting_category = 'PC')`.
- **Warehouse:** `FCT_RENEWAL_MEETINGS` → `pc_invited`.
- **HubSpot:** MEETING · PC types · Closers · `hs_meeting_start_time` in range (no outcome filter).

</details>

<details>
<summary><code>#11</code> · PC Booked</summary>

- **Description:** PC meetings that were booked/confirmed (not canceled).
- **Formula:** COUNT of PC meetings where outcome ≠ CANCELED.
- **SQL / derived:** `COUNT_IF(meeting_category = 'PC' AND is_booked)`.
- **Warehouse:** `FCT_RENEWAL_MEETINGS` → `pc_booked`.
- **HubSpot:** MEETING · PC types · `hs_meeting_outcome NOT IN ('CANCELED')` · Closers · date in range.

</details>

<details>
<summary><code>#12</code> · PC Completed</summary>

- **Description:** PC meetings where the member showed up (completed).
- **Formula:** COUNT of PC meetings where outcome = COMPLETED.
- **SQL / derived:** `COUNT_IF(meeting_category = 'PC' AND is_completed)`.
- **Warehouse:** `FCT_RENEWAL_MEETINGS` → `pc_completed`  *(`is_completed` = `LIKE 'COMPLETED%'`, see Appendix)*.
- **HubSpot:** MEETING · PC types · `hs_meeting_outcome = 'COMPLETED'` · Closers · date in range.

</details>

<details>
<summary><code>#13</code> · PC Book%</summary>

- **Description:** Booking rate for progress calls — share of invited that were confirmed.
- **Formula:** PC Booked ÷ PC Invited × 100.
- **SQL / derived:** `safePct(pc_booked, pc_invited)` (`den ≤ 0 → "—"`).
- **Warehouse:** derived from `FCT_RENEWAL_MEETINGS.pc_booked`, `pc_invited`.
- **HubSpot:** ratio of #11 ÷ #10.

</details>

<details>
<summary><code>#14</code> · PC Show%</summary>

- **Description:** Show rate for booked progress calls.
- **Formula:** PC Completed ÷ PC Booked × 100.
- **SQL / derived:** `safePct(pc_completed, pc_booked)`.
- **Warehouse:** derived from `FCT_RENEWAL_MEETINGS.pc_completed`, `pc_booked`.
- **HubSpot:** ratio of #12 ÷ #11.

</details>

<details>
<summary><code>#15</code> · PC Close%</summary>

- **Description:** Close efficiency relative to PC volume. Numerator = **all** closed-won deals for the closer (not only PC-sourced).
- **Formula:** Closed-Won Deals ÷ PC Completed × 100.
- **SQL / derived:** `safePct(deals_won, pc_completed)`.
- **Warehouse:** `deals_won` (#2) ÷ `FCT_RENEWAL_MEETINGS.pc_completed`.
- **HubSpot:** Numerator DEAL (won, close date in range, Closers); Denominator = #12.

</details>

<details>
<summary><code>#16</code> · RC Invited</summary>

- **Description:** All Renewal Call meetings in the window, any outcome (top of RC funnel).
- **Formula:** COUNT of RC meetings in range.
- **SQL / derived:** `COUNT_IF(meeting_category = 'RC')`.
- **Warehouse:** `FCT_RENEWAL_MEETINGS` → `rc_invited`.
- **HubSpot:** MEETING · RC types · Closers · date in range (no outcome filter).

</details>

<details>
<summary><code>#17</code> · RC Booked</summary>

- **Description:** RC meetings that were booked/confirmed (not canceled).
- **Formula:** COUNT of RC meetings where outcome ≠ CANCELED.
- **SQL / derived:** `COUNT_IF(meeting_category = 'RC' AND is_booked)`.
- **Warehouse:** `FCT_RENEWAL_MEETINGS` → `rc_booked`.
- **HubSpot:** MEETING · RC types · `hs_meeting_outcome NOT IN ('CANCELED')` · Closers · date in range.

</details>

<details>
<summary><code>#18</code> · RC Completed</summary>

- **Description:** RC meetings where the member showed up (completed).
- **Formula:** COUNT of RC meetings where outcome = COMPLETED.
- **SQL / derived:** `COUNT_IF(meeting_category = 'RC' AND is_completed)`.
- **Warehouse:** `FCT_RENEWAL_MEETINGS` → `rc_completed`  *(`is_completed` = `LIKE 'COMPLETED%'`)*.
- **HubSpot:** MEETING · RC types · `hs_meeting_outcome = 'COMPLETED'` · Closers · date in range.

</details>

<details>
<summary><code>#19</code> · RC Book%</summary>

- **Description:** Booking rate for renewal calls.
- **Formula:** RC Booked ÷ RC Invited × 100.
- **SQL / derived:** `safePct(rc_booked, rc_invited)`.
- **Warehouse:** derived from `FCT_RENEWAL_MEETINGS.rc_booked`, `rc_invited`.
- **HubSpot:** ratio of #17 ÷ #16.

</details>

<details>
<summary><code>#20</code> · RC Show%</summary>

- **Description:** Show rate for booked renewal calls.
- **Formula:** RC Completed ÷ RC Booked × 100.
- **SQL / derived:** `safePct(rc_completed, rc_booked)`.
- **Warehouse:** derived from `FCT_RENEWAL_MEETINGS.rc_completed`, `rc_booked`.
- **HubSpot:** ratio of #18 ÷ #17.

</details>

<details>
<summary><code>#21</code> · RC Close%</summary>

- **Description:** Close efficiency relative to RC volume. Numerator = **all** closed-won deals for the closer.
- **Formula:** Closed-Won Deals ÷ RC Completed × 100.
- **SQL / derived:** `safePct(deals_won, rc_completed)`.
- **Warehouse:** `deals_won` (#2) ÷ `FCT_RENEWAL_MEETINGS.rc_completed`.
- **HubSpot:** Numerator DEAL (won, close date in range, Closers); Denominator = #18.

</details>

#### Cash by Pipeline Type (windowed)

<details>
<summary><code>#22</code> · MM T1 Renewal Cash</summary>

- **Description:** Cash from first-year Mastermind renewals (Gold/Platinum/Bronze).
- **Formula:** Σ (11-component cash) for MM Tier-1 deals in window.
- **SQL / derived:** `SUM(cash_amount) … GROUP BY product_column` → column `MM_T1`.
- **Warehouse:** `FCT_RENEWAL_CASH` → `cash_amount`, `product_column = 'MM_T1'` *(currently $0 until mapping ships)*.
- **HubSpot:** DEAL · 11-component cash · Pipelines · Won stages · Closers · `renewal_product ∈ ('MM Gold','MM Platinum','MM Bronze')` · `renewal_year_count = '1st Year'`.

</details>

<details>
<summary><code>#23</code> · MM T2 Renewal Cash</summary>

- **Description:** Cash from second-year Mastermind renewals.
- **Formula / SQL:** Σ 11-component cash; `product_column = 'MM_T2'`.
- **Warehouse:** `FCT_RENEWAL_CASH.product_column = 'MM_T2'`.
- **HubSpot:** as #22 but `renewal_year_count = '2nd Year'`.

</details>

<details>
<summary><code>#24</code> · MM T3 Renewal Cash</summary>

- **Description:** Cash from third-year+ Mastermind renewals.
- **Formula / SQL:** Σ 11-component cash; `product_column = 'MM_T3'`.
- **Warehouse:** `FCT_RENEWAL_CASH.product_column = 'MM_T3'`.
- **HubSpot:** as #22 but `renewal_year_count = '3rd Year+'`.

</details>

<details>
<summary><code>#25</code> · MM Restart Cash</summary>

- **Description:** Cash from Mastermind restart deals.
- **Formula / SQL:** Σ 11-component cash; `product_column = 'MM_RESTART'`.
- **Warehouse:** `FCT_RENEWAL_CASH.product_column = 'MM_RESTART'`.
- **HubSpot:** DEAL · Pipelines · Won stages · Closers · `renewal_product = 'Restart'` · `renewal___product_category_originally_purchased = 'Mastermind'`.

</details>

<details>
<summary><code>#26</code> · ACC T1 Renewal Cash</summary>

- **Description:** Cash from first-year Accelerator renewals.
- **Formula / SQL:** Σ 11-component cash; `product_column = 'ACC_T1'`.
- **Warehouse:** `FCT_RENEWAL_CASH.product_column = 'ACC_T1'`.
- **HubSpot:** `renewal_product = 'Accelerator'` · `renewal_year_count = '1st Year'`.

</details>

<details>
<summary><code>#27</code> · ACC T2 Renewal Cash</summary>

- **Description:** Cash from 2nd + 3rd-year+ Accelerator renewals (T2 absorbs 3rd Year+; no ACC T3 column).
- **Formula / SQL:** Σ 11-component cash; `product_column = 'ACC_T2'`.
- **Warehouse:** `FCT_RENEWAL_CASH.product_column = 'ACC_T2'`.
- **HubSpot:** `renewal_product = 'Accelerator'` · `renewal_year_count ∈ ('2nd Year','3rd Year+')`.

</details>

<details>
<summary><code>#28</code> · ACC Upgrade Cash</summary>

- **Description:** Cash from Accelerator upgrade deals.
- **Formula / SQL:** Σ 11-component cash; `product_column = 'ACC_UPGRADE'`.
- **Warehouse:** `FCT_RENEWAL_CASH.product_column = 'ACC_UPGRADE'`.
- **HubSpot:** `renewal_product = 'Accelerator Upgrade'`.

</details>

<details>
<summary><code>#29</code> · ACC Restart Cash</summary>

- **Description:** Cash from Accelerator restart deals.
- **Formula / SQL:** Σ 11-component cash; `product_column = 'ACC_RESTART'`.
- **Warehouse:** `FCT_RENEWAL_CASH.product_column = 'ACC_RESTART'`.
- **HubSpot:** `renewal_product = 'Restart'` · `renewal___product_category_originally_purchased = 'Accelerator'`.

</details>

<details>
<summary><code>#30</code> · MM Upgrade Cash</summary>

- **Description:** Cash from Mastermind upgrade deals (Bronze→Gold, Gold→Platinum).
- **Formula / SQL:** Σ 11-component cash; `product_column = 'MM_UPGRADE'`.
- **Warehouse:** `FCT_RENEWAL_CASH.product_column = 'MM_UPGRADE'`.
- **HubSpot:** `renewal_product ∈ ('MM Upgrade — Bronze to Gold','MM Upgrade — Gold to Platinum')`.

</details>

<details>
<summary><code>#31</code> · Referral Cash</summary>

- **Description:** Cash from referral deals (only column keyed off pipeline type, not product).
- **Formula / SQL:** Σ 11-component cash; `product_column = 'REFERRAL'`.
- **Warehouse:** `FCT_RENEWAL_CASH.product_column = 'REFERRAL'`.
- **HubSpot:** DEAL · Pipelines · Won stages · Closers · `renewal_pipeline_type = 'Referral'`.

</details>

<details>
<summary><code>#32</code> · Total Cash (row total)</summary>

- **Description:** Total cash per closer for the window.
- **Formula:** Sum of the 10 product columns (#22–#31). *(Dashboard uses the independent true `SUM(cash_amount)` for accuracy while product columns are unmapped.)*
- **SQL / derived:** `total = c.cash_mtd`.
- **Warehouse:** `FCT_RENEWAL_CASH.cash_amount` (per-closer window sum).
- **HubSpot:** DEAL · 11-component cash · Pipelines · Won stages · Closers.

</details>

<details>
<summary><code>#33</code> · # Closed</summary>

- **Description:** Count of closed-won deals per closer in the window.
- **Formula:** COUNT of won deals, close date in range.
- **SQL / derived:** `closed = deals_won_mtd` (= #2).
- **Warehouse:** `FCT_RENEWAL_WON_DEALS`.
- **HubSpot:** DEAL · Pipelines · Won stages · Closers · `upsell___close_date` in range.

</details>

<details>
<summary><code>#34</code> · Close% (Cash by Pipeline)</summary>

- **Description:** Share of the closer's assigned pipeline deals that closed.
- **Formula:** # Closed ÷ total pipeline deals assigned to the closer × 100.
- **SQL / derived:** currently renders **"—"** — the denominator (total assigned pipeline deals) is not carried into the cash-pipeline row shape, so the column is not computed (see Appendix).
- **Warehouse:** numerator `FCT_RENEWAL_WON_DEALS`; denominator not wired in (would come from `FCT_RENEWAL_PIPELINE_SNAPSHOT`).
- **HubSpot:** Numerator = #33; Denominator = all deals in the renewal Pipelines owned by the closer.

</details>

<details>
<summary><code>#35</code> · vs Prior MTD</summary>

- **Description:** Cash change vs the comparison period.
- **Formula (spec):** current-month MTD cash − prior-month cash for the same elapsed days. **Implementation:** cash(selected window) − cash(immediately preceding equal-length window).
- **SQL / derived:** `vs_prior = c.cash_vs_prior_mtd = cash(window) − cash(prior window)`.
- **Warehouse:** two `FCT_RENEWAL_CASH` sums (window + prior window).
- **HubSpot:** DEAL · 11-component cash for each period · Pipelines · Won stages · Closers.

</details>

#### HubSpot Pipeline Snapshot (live, no date filter)

<details>
<summary><code>#36</code> · PC Due</summary>

- **Description:** Deals currently in Midway Check In Due.
- **Formula / SQL:** `SUM(deal_count)` where `snapshot_col = 'pc_due'`.
- **Warehouse:** `FCT_RENEWAL_PIPELINE_SNAPSHOT` → `pc_due`.
- **HubSpot:** DEAL · pipeline `95211801` · `dealstage = 'Midway Check In Due' (175326088)` · Closers.

</details>

<details>
<summary><code>#37</code> · PC Invited</summary>

- **Description:** Deals currently in Midway Check In Invited.
- **Formula / SQL:** `SUM(deal_count)` where `snapshot_col = 'pc_invited'`.
- **Warehouse:** `FCT_RENEWAL_PIPELINE_SNAPSHOT` → `pc_invited`.
- **HubSpot:** pipeline `95211801` · `dealstage = 'Midway Check In Invited' (240516941)` · Closers.

</details>

<details>
<summary><code>#38</code> · PC Scheduled</summary>

- **Description:** Deals currently in Midway Check In Scheduled.
- **Formula / SQL:** `SUM(deal_count)` where `snapshot_col = 'pc_scheduled'`.
- **Warehouse:** `FCT_RENEWAL_PIPELINE_SNAPSHOT` → `pc_scheduled`.
- **HubSpot:** pipeline `95211801` · `dealstage = 'Midway Check In Scheduled' (175346325)` · Closers.

</details>

<details>
<summary><code>#39</code> · PC Not Cmplt</summary>

- **Description:** Deals currently in Midway Check in Not Complete.
- **Formula / SQL:** `SUM(deal_count)` where `snapshot_col = 'pc_not_cmplt'`.
- **Warehouse:** `FCT_RENEWAL_PIPELINE_SNAPSHOT` → `pc_not_cmplt`.
- **HubSpot:** pipeline `95211801` · `dealstage = 'Midway Check in Not Complete' (200475939)` · Closers.

</details>

<details>
<summary><code>#40</code> · PC Completed</summary>

- **Description:** Deals currently in Midway Check in Complete - Nurture.
- **Formula / SQL:** `SUM(deal_count)` where `snapshot_col = 'pc_completed'`.
- **Warehouse:** `FCT_RENEWAL_PIPELINE_SNAPSHOT` → `pc_completed`.
- **HubSpot:** pipeline `95211801` · `dealstage = 'Midway Check in Complete - Nurture' (186330445)` · Closers.

</details>

<details>
<summary><code>#41</code> · RC Due</summary>

- **Description:** Deals currently in Renewal Call Due.
- **Formula / SQL:** `SUM(deal_count)` where `snapshot_col = 'rc_due'`.
- **Warehouse:** `FCT_RENEWAL_PIPELINE_SNAPSHOT` → `rc_due`.
- **HubSpot:** pipeline `95211801` · `dealstage = 'Renewal Call Due' (203001161)` · Closers.

</details>

<details>
<summary><code>#42</code> · RC Invited</summary>

- **Description:** Deals currently in Renewal Call Invited.
- **Formula / SQL:** `SUM(deal_count)` where `snapshot_col = 'rc_invited'`.
- **Warehouse:** `FCT_RENEWAL_PIPELINE_SNAPSHOT` → `rc_invited`.
- **HubSpot:** pipeline `95211801` · `dealstage = 'Renewal Call Invited' (240516942)` · Closers.

</details>

<details>
<summary><code>#43</code> · RC Scheduled</summary>

- **Description:** Deals currently in Renewal Call Scheduled.
- **Formula / SQL:** `SUM(deal_count)` where `snapshot_col = 'rc_scheduled'`.
- **Warehouse:** `FCT_RENEWAL_PIPELINE_SNAPSHOT` → `rc_scheduled`.
- **HubSpot:** pipeline `95211801` · `dealstage = 'Renewal Call Scheduled' (186350393)` · Closers.

</details>

<details>
<summary><code>#44</code> · RC Not Cmplt</summary>

- **Description:** Deals currently in Renewal Call Not Complete.
- **Formula / SQL:** `SUM(deal_count)` where `snapshot_col = 'rc_not_cmplt'`.
- **Warehouse:** `FCT_RENEWAL_PIPELINE_SNAPSHOT` → `rc_not_cmplt`.
- **HubSpot:** pipeline `95211801` · `dealstage = 'Renewal Call Not Complete' (175346326)` · Closers.

</details>

<details>
<summary><code>#45</code> · Nurture</summary>

- **Description:** Deals in post-call nurture stages. Excludes Midway Complete (that's #40).
- **Formula / SQL:** `SUM(deal_count)` where `snapshot_col = 'nurture'`.
- **Warehouse:** `FCT_RENEWAL_PIPELINE_SNAPSHOT` → `nurture`.
- **HubSpot:** pipeline `95211801` · `dealstage ∈ ('Renewal Call Complete - Nurture' 200616252, 'Follow Up Call Complete - Nurture' 1021424915)` · Closers.

</details>

<details>
<summary><code>#46</code> · Redzone</summary>

- **Description:** Deals currently in Renewal Red Zone.
- **Formula / SQL:** `SUM(deal_count)` where `snapshot_col = 'redzone'`.
- **Warehouse:** `FCT_RENEWAL_PIPELINE_SNAPSHOT` → `redzone`.
- **HubSpot:** pipeline `95211801` · `dealstage = 'Renewal Red Zone' (175346329)` · Closers.

</details>

<details>
<summary><code>#47</code> · Closed Won (both pipelines)</summary>

- **Description:** Deals currently in a closed-won stage across both pipelines.
- **Formula / SQL:** `SUM(deal_count)` where `snapshot_col = 'closed_won'`.
- **Warehouse:** `FCT_RENEWAL_PIPELINE_SNAPSHOT` → `closed_won`.
- **HubSpot:** DEAL · Pipelines (both) · Won stages (`175346331`, `229787714`, `1359841456`) · Closers.

</details>

<details>
<summary><code>#48</code> · Closed Lost</summary>

- **Description:** Deals currently in a lost stage.
- **Formula / SQL:** `SUM(deal_count)` where `snapshot_col = 'closed_lost'`.
- **Warehouse:** `FCT_RENEWAL_PIPELINE_SNAPSHOT` → `closed_lost`.
- **HubSpot:** pipeline `95211801` · `dealstage ∈ ('Renewal Deal Lost' 175346332, 'Renewal Deal DNC' 209616300)` · Closers.

</details>

<details>
<summary><code>#49</code> · New Member</summary>

- **Description:** Deals currently in New Member (Renewal Pipeline).
- **Formula / SQL:** `SUM(deal_count)` where `snapshot_col = 'new_member'`.
- **Warehouse:** `FCT_RENEWAL_PIPELINE_SNAPSHOT` → `new_member`.
- **HubSpot:** pipeline `898243912` · `dealstage = 'New Member' (1359829634)` · Closers.

</details>

<details>
<summary><code>#50</code> · PC1 Completed</summary>

- **Description:** Deals currently in Progress Call 1 Completed (Renewal Pipeline).
- **Formula / SQL:** `SUM(deal_count)` where `snapshot_col = 'pc1_completed'`.
- **Warehouse:** `FCT_RENEWAL_PIPELINE_SNAPSHOT` → `pc1_completed`.
- **HubSpot:** pipeline `898243912` · `dealstage = 'Progress Call 1 Completed' (1359841795)` · Closers.

</details>

<details>
<summary><code>#51</code> · Total (Pipeline Snapshot)</summary>

- **Description:** Total deals across all 15 displayed stages per closer. Follow Up Due/Invited/Scheduled/Not Complete are excluded.
- **Formula:** Σ of #36–#50.
- **SQL / derived:** `rowTotal = Σ(all 15 snapshot_col values for the row)`.
- **Warehouse:** `FCT_RENEWAL_PIPELINE_SNAPSHOT` (all columns).
- **HubSpot:** union of the stages in #36–#50.

</details>

#### Booking & Show Rates (windowed)

<details>
<summary><code>#52</code> · PC Book%</summary>

- **Description:** Booking rate for progress calls (same as #13).
- **Formula:** PC Booked ÷ PC Invited × 100.
- **SQL / derived:** `safePct(pc_booked, pc_invited)`.
- **Warehouse:** `FCT_RENEWAL_MEETINGS.pc_booked`, `pc_invited`.
- **HubSpot:** #11 ÷ #10.

</details>

<details>
<summary><code>#53</code> · PC Show%</summary>

- **Description:** Show rate for booked progress calls (same as #14).
- **Formula:** PC Completed ÷ PC Booked × 100.
- **SQL / derived:** `safePct(pc_completed, pc_booked)`.
- **Warehouse:** `FCT_RENEWAL_MEETINGS.pc_completed`, `pc_booked`.
- **HubSpot:** #12 ÷ #11.

</details>

<details>
<summary><code>#54</code> · RC Book%</summary>

- **Description:** Booking rate for renewal calls (same as #19).
- **Formula:** RC Booked ÷ RC Invited × 100.
- **SQL / derived:** `safePct(rc_booked, rc_invited)`.
- **Warehouse:** `FCT_RENEWAL_MEETINGS.rc_booked`, `rc_invited`.
- **HubSpot:** #17 ÷ #16.

</details>

<details>
<summary><code>#55</code> · RC Show%</summary>

- **Description:** Show rate for booked renewal calls (same as #20).
- **Formula:** RC Completed ÷ RC Booked × 100.
- **SQL / derived:** `safePct(rc_completed, rc_booked)`.
- **Warehouse:** `FCT_RENEWAL_MEETINGS.rc_completed`, `rc_booked`.
- **HubSpot:** #18 ÷ #17.

</details>

<details>
<summary><code>#56</code> · PWC Completed</summary>

- **Description:** Completed Post Webinar Call meetings in the window.
- **Formula:** COUNT of PWC meetings where outcome = COMPLETED.
- **SQL / derived:** `COUNT_IF(meeting_category = 'PWC' AND is_completed)`.
- **Warehouse:** `FCT_RENEWAL_MEETINGS` → `pwc_completed`.
- **HubSpot:** MEETING · PWC type · `hs_meeting_outcome = 'COMPLETED'` · Closers · `hs_meeting_start_time` in range.

</details>

<details>
<summary><code>#57</code> · PWC Close%</summary>

- **Description:** Close rate from completed Post Webinar calls.
- **Formula:** Closed-Won Deals ÷ PWC Completed × 100.
- **SQL / derived:** `safePct(deals_won, pwc_completed)` (colored via `closeColor`; pooled Average row uses `Σdeals_won / Σpwc_completed`).
- **Warehouse:** `deals_won` (#2) ÷ `FCT_RENEWAL_MEETINGS.pwc_completed`.
- **HubSpot:** Numerator DEAL (won, close date in range, Closers); Denominator = #56.

</details>

</details>
