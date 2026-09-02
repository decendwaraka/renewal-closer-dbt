  
**RENEWALS CLOSER DASHBOARD**

**FORMULA SPECIFICATION DOCUMENT**

Wireframe v1  |  Lovable \+ Snowflake

Decentralized Masters  |  June 2026

Owner: Abdullah  |  Sponsor: Bryan Fill (CRO)

v2 — Updated per Celeste feedback (June 29, 2026\)

**OVERVIEW**

This document specifies every formula for the Renewals Closer Dashboard. This is a single-view dashboard (no rep/manager split). The dashboard will be built on Lovable with Snowflake as the data source, pulling from HubSpot.

**Total formulas in this document: 57\.**

*v2 Changes: (1) Added Renewal Post Webinar Call as a third meeting type category. (2) Added Renewal Pipeline deal stages to reference table and Pipeline Snapshot. (3) Split Live Calls Today into Closing Calls Today \+ Midway Calls Today per Bryan. (4) Fixed Card \#10 wording: counts meetings, not unique members.*

**BASE FILTERS (ALL DEAL METRICS)**

| Filter | Value |
| :---- | :---- |
| Pipelines | Renewal Sales Pipeline (95211801), Renewal Pipeline (898243912) |
| Won Stages | Renewal Closed Won \- PIF (175346331), Renewal Closed Won \- Payment Plan (229787714), Closed Won (1359841456) |
| Closer Attribution | hubspot\_owner\_id (Deal owner) |
| Close Date Field | Renewal \- Close Date (upsell\_\_\_close\_date) |

**CURRENT CLOSERS**

| Name | HubSpot Owner ID |
| :---- | :---- |
| Sufijan Cunningham | 82672208 |
| Abe Underwood | 756332149 |
| Elisabeth Rogers | 82734543 |
| Melissa Davis | 756339074 |
| Henna Shakoor | 76930546 |

**CASH CALCULATION REFERENCE (11 COMPONENTS)**

**Total Cash \= cash\_collected \+ Additional Payments 1 through 10\. Each component uses its own date field within the date range. All components share the same pipeline \+ won stage \+ closer filters.**

| \# | Amount Property | Date Property |
| :---- | :---- | :---- |
| Base | cash\_collected | Renewal \- Close Date (upsell\_\_\_close\_date) |
| AP1 | additional\_payment\_\_1\_amount | additional\_payment\_\_1\_stamped\_date |
| AP2 | additional\_payment\_\_2\_amount | additional\_payment\_\_2\_stamped\_date |
| AP3 | collected\_amount\_\_additional\_payment\_3 | collected\_date\_additional\_payment\_3 |
| AP4 | collected\_amount\_\_additional\_payment\_4 | collected\_date\_additional\_payment\_4 |
| AP5 | collected\_amount\_\_additional\_payment\_5 | collected\_date\_additional\_payment\_5 |
| AP6 | collected\_amount\_\_additional\_payment\_6 | collected\_date\_additional\_payment\_6 |
| AP7 | collected\_amount\_\_additional\_payment\_7 | collected\_date\_additional\_payment\_7 |
| AP8 | collected\_amount\_\_additional\_payment\_8 | collected\_date\_additional\_payment\_8 |
| AP9 | collected\_amount\_\_additional\_payment\_9 | collected\_date\_additional\_payment\_9 |
| AP10 | collected\_amount\_\_additional\_payment\_10 | collected\_date\_additional\_payment\_10 |

*AP1 and AP2 use legacy naming (additional\_payment\_\_X\_amount). AP3 through AP10 use newer naming (collected\_amount\_\_additional\_payment\_X). Both are on the DEAL object.*

**MEETING TYPE REFERENCE (CLOSER CALLS)**

| Category | hs\_activity\_type Values |
| :---- | :---- |
| Progress Call (PC) | Renewal 3 Month, Renewal Accelerator 3 month |
| Renewal Call (RC) | Renewal Strategy, Renewal Accelerator, Renewal Accelerator Evergreen |
| Post Webinar Call (PWC) | Renewal Post Webinar Call |

**v2: Added Post Webinar Call (PWC) as a third meeting type category per Celeste. PWC is neither a midway/progress call nor a renewal/strategy call.**

**2026-09-02 addendum: Renewal Strategy Alignment and Renewal Follow-up retired from RC (business confirmed) — removed from the RC types list above and from every formula below that references it.**

**All meeting metrics use hs\_meeting\_outcome \= 'COMPLETED' for live/completed calls. Renewal team does not use sub-outcomes (QUALIFIED, NURTURE, DQ).**

*Meeting attribution: hubspot\_owner\_id on the MEETING object. Date field: hs\_meeting\_start\_time.*

**DEAL STAGE REFERENCE**

These stages are used for the HubSpot Pipeline Snapshot table. Deals are counted by their current stage.

**Renewal Sales Pipeline (95211801)**

| Group | Stage | Stage ID |
| :---- | :---- | :---- |
| Progress Call | Midway Check In Due | 175326088 |
| Progress Call | Midway Check In Invited | 240516941 |
| Progress Call | Midway Check In Scheduled | 175346325 |
| Progress Call | Midway Check in Not Complete | 200475939 |
| Progress Call | Midway Check in Complete \- Nurture | 186330445 |
| Follow Up | Follow Up Call Due | 1021424911 |
| Follow Up | Follow Up Call Invited | 1021424912 |
| Follow Up | Follow Up Call Scheduled | 1021424913 |
| Follow Up | Follow Up Call Not Complete | 1021424914 |
| Follow Up | Follow Up Call Complete \- Nurture | 1021424915 |
| Renewal Call | Renewal Call Due | 203001161 |
| Renewal Call | Renewal Call Invited | 240516942 |
| Renewal Call | Renewal Call Scheduled | 186350393 |
| Renewal Call | Renewal Call Not Complete | 175346326 |
| Renewal Call | Renewal Call Complete \- Nurture | 200616252 |
| Other | Renewal Red Zone | 175346329 |
| Other | Renewal Closed Won \- PIF | 175346331 |
| Other | Renewal Closed Won \- Payment Plan | 229787714 |
| Other | Renewal Deal Lost | 175346332 |
| Other | Renewal Deal DNC | 209616300 |

**Renewal Pipeline (898243912)**

*v2: Added per Celeste feedback.*

| Group | Stage | Stage ID |
| :---- | :---- | :---- |
| In Progress | New Member | 1359829634 |
| In Progress | Progress Call 1 Completed | 1359841795 |
| Other | Closed Won | 1359841456 |

*Follow Up stages exist in the Renewal Sales Pipeline but are NOT shown as a separate group in the wireframe. Follow Up Complete \- Nurture is included in the 'Nurture' column under Other. Follow Up Due/Invited/Scheduled/Not Complete deals are excluded from the pipeline snapshot table.*

**PRODUCT AND YEAR COUNT MAPPINGS (CASH BY PIPELINE)**

| Column | renewal\_product Filter | Additional Filter |
| :---- | :---- | :---- |
| MM T1 Renewal | MM Gold, MM Platinum, MM Bronze | renewal\_year\_count \= '1st Year' |
| MM T2 Renewal | MM Gold, MM Platinum, MM Bronze | renewal\_year\_count \= '2nd Year' |
| MM T3 Renewal | MM Gold, MM Platinum, MM Bronze | renewal\_year\_count \= '3rd Year+' |
| MM Restart | Restart | renewal\_\_\_product\_category\_originally\_purchased \= 'Mastermind' |
| ACC T1 Renewal | Accelerator | renewal\_year\_count \= '1st Year' |
| ACC T2 Renewal | Accelerator | renewal\_year\_count in ('2nd Year', '3rd Year+') |
| ACC Upgrade | Accelerator Upgrade | (none) |
| ACC Restart | Restart | renewal\_\_\_product\_category\_originally\_purchased \= 'Accelerator' |
| MM Upgrade | MM Upgrade \- Bronze to Gold, MM Upgrade \- Gold to Platinum | (none) |
| Referral | (uses renewal\_pipeline\_type \= 'Referral') | (none) |

**Confirmed: ACC Renewal and ACC Restart are separate categories. Renewal \= member renews for a year. Restart \= member restarts membership (2-6 months). Confirmed by Bryan and Celeste (June 29, 2026).**

**LEADERBOARDS**

Four competitive leaderboards showing MTD performance with goal tracking and month-over-month comparison.

| \#1  The Rainmaker (Total Cash) |  |
| :---- | :---- |
| *All closed won cash attributed to each closer for the period. Uses 11-component cash formula. Includes goal progress bar and MoM comparison.* |  |
| **Object** | DEAL |
| **Cash Formula** | 11-component: cash\_collected \+ AP1 through AP10 (see Cash Calculation Reference) |
| **Each Component** | Sum of amount field where its corresponding date field is within the date range |
| **Filter 1** | pipeline in (Renewal Sales Pipeline, Renewal Pipeline) |
| **Filter 2** | dealstage in (Renewal Closed Won \- PIF, Renewal Closed Won \- Payment Plan, Closed Won) |
| **Filter 3** | hubspot\_owner\_id in (82672208 Sufijan Cunningham, 756332149 Abe Underwood, 82734543 Elisabeth Rogers, 756339074 Melissa Davis, 76930546 Henna Shakoor) |
| **Formula** | Sum of all 11 components |
| **Group By** | hubspot\_owner\_id |
| **Goal** | $350K team total (placeholder, confirm actual target) |
| **MoM** | Current MTD cash minus same elapsed days in prior month |
| **Settings** | Prefix: $  |  Decimals: 0  |  Rank descending  |  Show progress bar |

| \#2  Mayo Connoisseur (Deals Won) |  |
| :---- | :---- |
| *Count of closed won deals attributed to each closer. Includes goal progress bar and MoM comparison.* |  |
| **Object** | DEAL |
| **Metric** | Count of deals |
| **Date Field** | Renewal \- Close Date, within date range |
| **Filter 1** | pipeline in (Renewal Sales Pipeline, Renewal Pipeline) |
| **Filter 2** | dealstage in (Renewal Closed Won \- PIF, Renewal Closed Won \- Payment Plan, Closed Won) |
| **Filter 3** | hubspot\_owner\_id in (82672208 Sufijan Cunningham, 756332149 Abe Underwood, 82734543 Elisabeth Rogers, 756339074 Melissa Davis, 76930546 Henna Shakoor) |
| **Group By** | hubspot\_owner\_id |
| **Goal** | 30 deals team total (placeholder, confirm actual target) |
| **MoM** | Current MTD deals minus same elapsed days in prior month |
| **Settings** | Decimals: 0  |  Rank descending  |  Show progress bar |

| \#3  Live Call Close % (Team Avg) |  |
| :---- | :---- |
| *Closed won deals divided by completed (live) meetings. Measures what percentage of live calls result in a close.* |  |
| **Numerator Object** | DEAL |
| **Numerator** | Count of deals: pipeline in (Renewal Sales Pipeline, Renewal Pipeline) \+ dealstage in won stages \+ Renewal \- Close Date in range |
| **Denominator Object** | MEETING |
| **Denominator** | Count of meetings: hs\_activity\_type in RC types \+ PWC type ('Renewal Strategy', 'Renewal Accelerator', 'Renewal Accelerator Evergreen', 'Renewal Post Webinar Call') \+ hs\_meeting\_outcome \= 'COMPLETED' \+ hs\_meeting\_start\_time in range |
| **Denominator Owner** | hubspot\_owner\_id (on meeting) in (82672208 Sufijan Cunningham, 756332149 Abe Underwood, 82734543 Elisabeth Rogers, 756339074 Melissa Davis, 76930546 Henna Shakoor) |
| **Formula** | Numerator / Denominator x 100 |
| **Group By** | closer (hubspot\_owner\_id) |
| **Target** | 30% |
| **MoM** | Current MTD % minus same elapsed days in prior month (show as pp change) |
| **Settings** | Suffix: %  |  Decimals: 0  |  Rank descending |

| \#4  Most Valuable Asset (Avg DPL) |  |
| :---- | :---- |
| *Average dollars per live call. Total cash divided by completed meetings. Measures how much cash each live call generates.* |  |
| **Numerator** | Total Cash: 11-component cash formula (same as \#1) |
| **Denominator** | Count of completed meetings (same denominator as \#3, includes RC \+ PWC types) |
| **Formula** | Numerator / Denominator |
| **Group By** | closer (hubspot\_owner\_id) |
| **Target** | $3,500 |
| **MoM** | Current MTD DPL minus same elapsed days in prior month |
| **Settings** | Prefix: $  |  Decimals: 0  |  Rank descending |

**TODAY SNAPSHOT**

Five cards showing real-time activity for the current day. v2: Live Calls split into Closing Calls and Midway Calls per Bryan's direction.

| \#5  Closing Calls Today |  |
| :---- | :---- |
| *Count of completed Renewal Call and Post Webinar meetings today. These are the closing/strategy calls.* |  |
| **Object** | MEETING |
| **Metric** | Count of meetings |
| **Date Field** | hs\_meeting\_start\_time \= today |
| **Filter 1** | hs\_activity\_type in ('Renewal Strategy', 'Renewal Accelerator', 'Renewal Accelerator Evergreen', 'Renewal Post Webinar Call') |
| **Filter 2** | hs\_meeting\_outcome \= 'COMPLETED' |
| **Filter 3** | hubspot\_owner\_id in (82672208 Sufijan Cunningham, 756332149 Abe Underwood, 82734543 Elisabeth Rogers, 756339074 Melissa Davis, 76930546 Henna Shakoor) |
| **Settings** | Decimals: 0 |
| **NOTE** | v2: Was 'Live Calls Today' counting all types. Now split per Bryan: closing calls separate from midway calls. Includes vs yesterday comparison. |

| \#6  Midway Calls Today |  |
| :---- | :---- |
| *Count of completed Progress Call (Midway) meetings today.* |  |
| **Object** | MEETING |
| **Metric** | Count of meetings |
| **Date Field** | hs\_meeting\_start\_time \= today |
| **Filter 1** | hs\_activity\_type in ('Renewal 3 Month', 'Renewal Accelerator 3 month') |
| **Filter 2** | hs\_meeting\_outcome \= 'COMPLETED' |
| **Filter 3** | hubspot\_owner\_id in (82672208 Sufijan Cunningham, 756332149 Abe Underwood, 82734543 Elisabeth Rogers, 756339074 Melissa Davis, 76930546 Henna Shakoor) |
| **Settings** | Decimals: 0 |
| **NOTE** | v2: NEW card. Split from original 'Live Calls Today' per Bryan. Includes vs yesterday comparison. |

| \#7  Deals Closed Today |  |
| :---- | :---- |
| *Count of deals that closed won today.* |  |
| **Object** | DEAL |
| **Metric** | Count of deals |
| **Date Field** | Renewal \- Close Date \= today |
| **Filter 1** | pipeline in (Renewal Sales Pipeline, Renewal Pipeline) |
| **Filter 2** | dealstage in (Renewal Closed Won \- PIF, Renewal Closed Won \- Payment Plan, Closed Won) |
| **Filter 3** | hubspot\_owner\_id in (82672208 Sufijan Cunningham, 756332149 Abe Underwood, 82734543 Elisabeth Rogers, 756339074 Melissa Davis, 76930546 Henna Shakoor) |
| **Settings** | Decimals: 0 |

| \#8  Cash Closed Today |  |
| :---- | :---- |
| *Cash collected from deals that closed today. Uses 11-component cash formula.* |  |
| **Object** | DEAL |
| **Cash Formula** | 11-component: cash\_collected \+ AP1 through AP10 (see Cash Calculation Reference) |
| **Each Component** | Sum of amount field where its corresponding date field \= today |
| **Filter 1** | pipeline in (Renewal Sales Pipeline, Renewal Pipeline) |
| **Filter 2** | dealstage in (Renewal Closed Won \- PIF, Renewal Closed Won \- Payment Plan, Closed Won) |
| **Filter 3** | hubspot\_owner\_id in (82672208 Sufijan Cunningham, 756332149 Abe Underwood, 82734543 Elisabeth Rogers, 756339074 Melissa Davis, 76930546 Henna Shakoor) |
| **Formula** | Sum of all 11 components |
| **Settings** | Prefix: $  |  Decimals: 0 |
| **NOTE** | Includes vs yesterday comparison (show delta). |

| \#9  On Fire Today |  |
| :---- | :---- |
| *Top performing closer today by cash closed.* |  |
| **Object** | DEAL |
| **Logic** | From Cash Closed Today (\#8), rank by hubspot\_owner\_id, pick the closer with highest cash today |
| **Output** | Closer name \+ deals closed count \+ cash amount |
| **Settings** | Show fire badge on the top performer |

**CALL OUTCOMES**

**Funnel metrics for Progress Calls (PC) and Renewal Calls (RC). Uses MEETING object with hs\_activity\_type to categorize. Attribution via hubspot\_owner\_id on the meeting.**

| \#10  PC Invited |  |
| :---- | :---- |
| *Total progress call meetings scheduled in the period. Counts all meetings of PC types regardless of outcome.* |  |
| **Object** | MEETING |
| **Metric** | Count of meetings |
| **Date Field** | hs\_meeting\_start\_time within date range |
| **Filter 1** | hs\_activity\_type in ('Renewal 3 Month', 'Renewal Accelerator 3 month') |
| **Filter 2** | hubspot\_owner\_id in (82672208 Sufijan Cunningham, 756332149 Abe Underwood, 82734543 Elisabeth Rogers, 756339074 Melissa Davis, 76930546 Henna Shakoor) |
| **Group By** | hubspot\_owner\_id |
| **Settings** | Decimals: 0 |
| **NOTE** | v2: Fixed wording. This counts meetings scheduled, not unique members. If a member has 2 meetings, they count as 2\. This is the top of the PC funnel. |

| \#11  PC Booked |  |
| :---- | :---- |
| *Progress call meetings that were actually booked/confirmed (not canceled).* |  |
| **Object** | MEETING |
| **Metric** | Count of meetings |
| **Date Field** | hs\_meeting\_start\_time within date range |
| **Filter 1** | hs\_activity\_type in ('Renewal 3 Month', 'Renewal Accelerator 3 month') |
| **Filter 2** | hs\_meeting\_outcome NOT IN ('CANCELED') |
| **Filter 3** | hubspot\_owner\_id in (82672208 Sufijan Cunningham, 756332149 Abe Underwood, 82734543 Elisabeth Rogers, 756339074 Melissa Davis, 76930546 Henna Shakoor) |
| **Group By** | hubspot\_owner\_id |
| **Settings** | Decimals: 0 |

| \#12  PC Completed |  |
| :---- | :---- |
| *Progress call meetings where the member showed up (completed).* |  |
| **Object** | MEETING |
| **Metric** | Count of meetings |
| **Date Field** | hs\_meeting\_start\_time within date range |
| **Filter 1** | hs\_activity\_type in ('Renewal 3 Month', 'Renewal Accelerator 3 month') |
| **Filter 2** | hs\_meeting\_outcome \= 'COMPLETED' |
| **Filter 3** | hubspot\_owner\_id in (82672208 Sufijan Cunningham, 756332149 Abe Underwood, 82734543 Elisabeth Rogers, 756339074 Melissa Davis, 76930546 Henna Shakoor) |
| **Group By** | hubspot\_owner\_id |
| **Settings** | Decimals: 0 |

| \#13  PC Book% |  |
| :---- | :---- |
| *Booking rate for progress calls. What % of scheduled meetings were confirmed (not canceled).* |  |
| **Numerator** | PC Booked (\#11) |
| **Denominator** | PC Invited (\#10) |
| **Formula** | Numerator / Denominator x 100 |
| **Group By** | closer |
| **Settings** | Suffix: %  |  Decimals: 0 |

| \#14  PC Show% |  |
| :---- | :---- |
| *Show rate for booked progress calls. What % of booked meetings actually showed up.* |  |
| **Numerator** | PC Completed (\#12) |
| **Denominator** | PC Booked (\#11) |
| **Formula** | Numerator / Denominator x 100 |
| **Group By** | closer |
| **Settings** | Suffix: %  |  Decimals: 0 |

| \#15  PC Close% |  |
| :---- | :---- |
| *Close rate from completed progress calls. What % of completed calls resulted in a deal close.* |  |
| **Numerator** | Count of closed won deals (pipeline \+ won stages \+ close date in range \+ hubspot\_owner\_id in closers) |
| **Denominator** | PC Completed (\#12) |
| **Formula** | Numerator / Denominator x 100 |
| **Group By** | closer |
| **Settings** | Suffix: %  |  Decimals: 0 |
| **NOTE** | The numerator counts ALL closed deals for the closer, not just those from PC. This gives an overall close efficiency relative to PC volume. |

| \#16  RC Invited |  |
| :---- | :---- |
| *Total renewal call meetings scheduled in the period. Counts all meetings of RC types regardless of outcome.* |  |
| **Object** | MEETING |
| **Metric** | Count of meetings |
| **Date Field** | hs\_meeting\_start\_time within date range |
| **Filter 1** | hs\_activity\_type in ('Renewal Strategy', 'Renewal Accelerator', 'Renewal Accelerator Evergreen') |
| **Filter 2** | hubspot\_owner\_id in (82672208 Sufijan Cunningham, 756332149 Abe Underwood, 82734543 Elisabeth Rogers, 756339074 Melissa Davis, 76930546 Henna Shakoor) |
| **Group By** | hubspot\_owner\_id |
| **Settings** | Decimals: 0 |
| **NOTE** | Counts meetings scheduled, not unique members. This is the top of the RC funnel. |

| \#17  RC Booked |  |
| :---- | :---- |
| *Renewal call meetings that were actually booked/confirmed (not canceled).* |  |
| **Object** | MEETING |
| **Metric** | Count of meetings |
| **Date Field** | hs\_meeting\_start\_time within date range |
| **Filter 1** | hs\_activity\_type in ('Renewal Strategy', 'Renewal Accelerator', 'Renewal Accelerator Evergreen') |
| **Filter 2** | hs\_meeting\_outcome NOT IN ('CANCELED') |
| **Filter 3** | hubspot\_owner\_id in (82672208 Sufijan Cunningham, 756332149 Abe Underwood, 82734543 Elisabeth Rogers, 756339074 Melissa Davis, 76930546 Henna Shakoor) |
| **Group By** | hubspot\_owner\_id |
| **Settings** | Decimals: 0 |

| \#18  RC Completed |  |
| :---- | :---- |
| *Renewal call meetings where the member showed up (completed).* |  |
| **Object** | MEETING |
| **Metric** | Count of meetings |
| **Date Field** | hs\_meeting\_start\_time within date range |
| **Filter 1** | hs\_activity\_type in ('Renewal Strategy', 'Renewal Accelerator', 'Renewal Accelerator Evergreen') |
| **Filter 2** | hs\_meeting\_outcome \= 'COMPLETED' |
| **Filter 3** | hubspot\_owner\_id in (82672208 Sufijan Cunningham, 756332149 Abe Underwood, 82734543 Elisabeth Rogers, 756339074 Melissa Davis, 76930546 Henna Shakoor) |
| **Group By** | hubspot\_owner\_id |
| **Settings** | Decimals: 0 |

| \#19  RC Book% |  |
| :---- | :---- |
| *Booking rate for renewal calls. What % of scheduled meetings were confirmed (not canceled).* |  |
| **Numerator** | RC Booked (\#17) |
| **Denominator** | RC Invited (\#16) |
| **Formula** | Numerator / Denominator x 100 |
| **Group By** | closer |
| **Settings** | Suffix: %  |  Decimals: 0 |

| \#20  RC Show% |  |
| :---- | :---- |
| *Show rate for booked renewal calls. What % of booked meetings actually showed up.* |  |
| **Numerator** | RC Completed (\#18) |
| **Denominator** | RC Booked (\#17) |
| **Formula** | Numerator / Denominator x 100 |
| **Group By** | closer |
| **Settings** | Suffix: %  |  Decimals: 0 |

| \#21  RC Close% |  |
| :---- | :---- |
| *Close rate from completed renewal calls. What % of completed calls resulted in a deal close.* |  |
| **Numerator** | Count of closed won deals (pipeline \+ won stages \+ close date in range \+ hubspot\_owner\_id in closers) |
| **Denominator** | RC Completed (\#18) |
| **Formula** | Numerator / Denominator x 100 |
| **Group By** | closer |
| **Settings** | Suffix: %  |  Decimals: 0 |

**CASH BY PIPELINE TYPE**

**Cash collected per closer by renewal term and product. Same 10-column structure as the Setter Dashboard, but attributed to hubspot\_owner\_id (deal owner) instead of renewal\_setter\_owner. See Product and Year Count Mappings reference table for filter logic.**

| \#22  MM T1 Renewal Cash |  |
| :---- | :---- |
| *Cash from first-year (Term 1\) Mastermind deals (Gold, Platinum, or Bronze). Uses 11-component cash formula.* |  |
| **Object** | DEAL |
| **Cash Formula** | 11-component: cash\_collected \+ AP1 through AP10 (see Cash Calculation Reference) |
| **Each Component** | Sum of amount field where its corresponding date field is within the date range |
| **Filter 1** | pipeline in (Renewal Sales Pipeline, Renewal Pipeline) |
| **Filter 2** | dealstage in (Renewal Closed Won \- PIF, Renewal Closed Won \- Payment Plan, Closed Won) |
| **Filter 3** | hubspot\_owner\_id in (82672208 Sufijan Cunningham, 756332149 Abe Underwood, 82734543 Elisabeth Rogers, 756339074 Melissa Davis, 76930546 Henna Shakoor) |
| **Filter 4** | renewal\_product in ('MM Gold', 'MM Platinum', 'MM Bronze') |
| **Filter 5** | renewal\_year\_count \= '1st Year' |
| **Formula** | Sum of all 11 components |
| **Group By** | hubspot\_owner\_id |
| **Settings** | Prefix: $  |  Decimals: 0 |
| **NOTE** | Group: Mastermind Renewals (purple). |

| \#23  MM T2 Renewal Cash |  |
| :---- | :---- |
| *Cash from second-year (Term 2\) Mastermind deals. Uses 11-component cash formula.* |  |
| **Object** | DEAL |
| **Cash Formula** | 11-component: cash\_collected \+ AP1 through AP10 (see Cash Calculation Reference) |
| **Each Component** | Sum of amount field where its corresponding date field is within the date range |
| **Filter 1** | pipeline in (Renewal Sales Pipeline, Renewal Pipeline) |
| **Filter 2** | dealstage in (Renewal Closed Won \- PIF, Renewal Closed Won \- Payment Plan, Closed Won) |
| **Filter 3** | hubspot\_owner\_id in (82672208 Sufijan Cunningham, 756332149 Abe Underwood, 82734543 Elisabeth Rogers, 756339074 Melissa Davis, 76930546 Henna Shakoor) |
| **Filter 4** | renewal\_product in ('MM Gold', 'MM Platinum', 'MM Bronze') |
| **Filter 5** | renewal\_year\_count \= '2nd Year' |
| **Formula** | Sum of all 11 components |
| **Group By** | hubspot\_owner\_id |
| **Settings** | Prefix: $  |  Decimals: 0 |

| \#24  MM T3 Renewal Cash |  |
| :---- | :---- |
| *Cash from third-year+ (Term 3\) Mastermind deals. Uses 11-component cash formula.* |  |
| **Object** | DEAL |
| **Cash Formula** | 11-component: cash\_collected \+ AP1 through AP10 (see Cash Calculation Reference) |
| **Each Component** | Sum of amount field where its corresponding date field is within the date range |
| **Filter 1** | pipeline in (Renewal Sales Pipeline, Renewal Pipeline) |
| **Filter 2** | dealstage in (Renewal Closed Won \- PIF, Renewal Closed Won \- Payment Plan, Closed Won) |
| **Filter 3** | hubspot\_owner\_id in (82672208 Sufijan Cunningham, 756332149 Abe Underwood, 82734543 Elisabeth Rogers, 756339074 Melissa Davis, 76930546 Henna Shakoor) |
| **Filter 4** | renewal\_product in ('MM Gold', 'MM Platinum', 'MM Bronze') |
| **Filter 5** | renewal\_year\_count \= '3rd Year+' |
| **Formula** | Sum of all 11 components |
| **Group By** | hubspot\_owner\_id |
| **Settings** | Prefix: $  |  Decimals: 0 |

| \#25  MM Restart Cash |  |
| :---- | :---- |
| *Cash from Mastermind restart deals. Uses renewal\_product \+ product\_category\_originally\_purchased to isolate MM restarts.* |  |
| **Object** | DEAL |
| **Cash Formula** | 11-component: cash\_collected \+ AP1 through AP10 (see Cash Calculation Reference) |
| **Each Component** | Sum of amount field where its corresponding date field is within the date range |
| **Filter 1** | pipeline in (Renewal Sales Pipeline, Renewal Pipeline) |
| **Filter 2** | dealstage in (Renewal Closed Won \- PIF, Renewal Closed Won \- Payment Plan, Closed Won) |
| **Filter 3** | hubspot\_owner\_id in (82672208 Sufijan Cunningham, 756332149 Abe Underwood, 82734543 Elisabeth Rogers, 756339074 Melissa Davis, 76930546 Henna Shakoor) |
| **Filter 4** | renewal\_product \= 'Restart' |
| **Filter 5** | renewal\_\_\_product\_category\_originally\_purchased \= 'Mastermind' |
| **Formula** | Sum of all 11 components |
| **Group By** | hubspot\_owner\_id |
| **Settings** | Prefix: $  |  Decimals: 0 |

| \#26  ACC T1 Renewal Cash |  |
| :---- | :---- |
| *Cash from first-year (Term 1\) Accelerator renewal deals.* |  |
| **Object** | DEAL |
| **Cash Formula** | 11-component: cash\_collected \+ AP1 through AP10 (see Cash Calculation Reference) |
| **Each Component** | Sum of amount field where its corresponding date field is within the date range |
| **Filter 1** | pipeline in (Renewal Sales Pipeline, Renewal Pipeline) |
| **Filter 2** | dealstage in (Renewal Closed Won \- PIF, Renewal Closed Won \- Payment Plan, Closed Won) |
| **Filter 3** | hubspot\_owner\_id in (82672208 Sufijan Cunningham, 756332149 Abe Underwood, 82734543 Elisabeth Rogers, 756339074 Melissa Davis, 76930546 Henna Shakoor) |
| **Filter 4** | renewal\_product \= 'Accelerator' |
| **Filter 5** | renewal\_year\_count \= '1st Year' |
| **Formula** | Sum of all 11 components |
| **Group By** | hubspot\_owner\_id |
| **Settings** | Prefix: $  |  Decimals: 0 |

| \#27  ACC T2 Renewal Cash |  |
| :---- | :---- |
| *Cash from second-year and third-year+ Accelerator renewal deals. No separate ACC T3 column; T2 absorbs 3rd Year+.* |  |
| **Object** | DEAL |
| **Cash Formula** | 11-component: cash\_collected \+ AP1 through AP10 (see Cash Calculation Reference) |
| **Each Component** | Sum of amount field where its corresponding date field is within the date range |
| **Filter 1** | pipeline in (Renewal Sales Pipeline, Renewal Pipeline) |
| **Filter 2** | dealstage in (Renewal Closed Won \- PIF, Renewal Closed Won \- Payment Plan, Closed Won) |
| **Filter 3** | hubspot\_owner\_id in (82672208 Sufijan Cunningham, 756332149 Abe Underwood, 82734543 Elisabeth Rogers, 756339074 Melissa Davis, 76930546 Henna Shakoor) |
| **Filter 4** | renewal\_product \= 'Accelerator' |
| **Filter 5** | renewal\_year\_count in ('2nd Year', '3rd Year+') |
| **Formula** | Sum of all 11 components |
| **Group By** | hubspot\_owner\_id |
| **Settings** | Prefix: $  |  Decimals: 0 |

| \#28  ACC Upgrade Cash |  |
| :---- | :---- |
| *Cash from Accelerator upgrade deals.* |  |
| **Object** | DEAL |
| **Cash Formula** | 11-component: cash\_collected \+ AP1 through AP10 (see Cash Calculation Reference) |
| **Each Component** | Sum of amount field where its corresponding date field is within the date range |
| **Filter 1** | pipeline in (Renewal Sales Pipeline, Renewal Pipeline) |
| **Filter 2** | dealstage in (Renewal Closed Won \- PIF, Renewal Closed Won \- Payment Plan, Closed Won) |
| **Filter 3** | hubspot\_owner\_id in (82672208 Sufijan Cunningham, 756332149 Abe Underwood, 82734543 Elisabeth Rogers, 756339074 Melissa Davis, 76930546 Henna Shakoor) |
| **Filter 4** | renewal\_product \= 'Accelerator Upgrade' |
| **Formula** | Sum of all 11 components |
| **Group By** | hubspot\_owner\_id |
| **Settings** | Prefix: $  |  Decimals: 0 |

| \#29  ACC Restart Cash |  |
| :---- | :---- |
| *Cash from Accelerator restart deals. Uses renewal\_product \+ product\_category\_originally\_purchased to isolate ACC restarts.* |  |
| **Object** | DEAL |
| **Cash Formula** | 11-component: cash\_collected \+ AP1 through AP10 (see Cash Calculation Reference) |
| **Each Component** | Sum of amount field where its corresponding date field is within the date range |
| **Filter 1** | pipeline in (Renewal Sales Pipeline, Renewal Pipeline) |
| **Filter 2** | dealstage in (Renewal Closed Won \- PIF, Renewal Closed Won \- Payment Plan, Closed Won) |
| **Filter 3** | hubspot\_owner\_id in (82672208 Sufijan Cunningham, 756332149 Abe Underwood, 82734543 Elisabeth Rogers, 756339074 Melissa Davis, 76930546 Henna Shakoor) |
| **Filter 4** | renewal\_product \= 'Restart' |
| **Filter 5** | renewal\_\_\_product\_category\_originally\_purchased \= 'Accelerator' |
| **Formula** | Sum of all 11 components |
| **Group By** | hubspot\_owner\_id |
| **Settings** | Prefix: $  |  Decimals: 0 |

| \#30  MM Upgrade Cash |  |
| :---- | :---- |
| *Cash from Mastermind upgrade deals (Bronze to Gold, Gold to Platinum).* |  |
| **Object** | DEAL |
| **Cash Formula** | 11-component: cash\_collected \+ AP1 through AP10 (see Cash Calculation Reference) |
| **Each Component** | Sum of amount field where its corresponding date field is within the date range |
| **Filter 1** | pipeline in (Renewal Sales Pipeline, Renewal Pipeline) |
| **Filter 2** | dealstage in (Renewal Closed Won \- PIF, Renewal Closed Won \- Payment Plan, Closed Won) |
| **Filter 3** | hubspot\_owner\_id in (82672208 Sufijan Cunningham, 756332149 Abe Underwood, 82734543 Elisabeth Rogers, 756339074 Melissa Davis, 76930546 Henna Shakoor) |
| **Filter 4** | renewal\_product in ('MM Upgrade — Bronze to Gold', 'MM Upgrade — Gold to Platinum') |
| **Formula** | Sum of all 11 components |
| **Group By** | hubspot\_owner\_id |
| **Settings** | Prefix: $  |  Decimals: 0 |

| \#31  Referral Cash |  |
| :---- | :---- |
| *Cash from referral deals. Uses renewal\_pipeline\_type instead of renewal\_product.* |  |
| **Object** | DEAL |
| **Cash Formula** | 11-component: cash\_collected \+ AP1 through AP10 (see Cash Calculation Reference) |
| **Each Component** | Sum of amount field where its corresponding date field is within the date range |
| **Filter 1** | pipeline in (Renewal Sales Pipeline, Renewal Pipeline) |
| **Filter 2** | dealstage in (Renewal Closed Won \- PIF, Renewal Closed Won \- Payment Plan, Closed Won) |
| **Filter 3** | hubspot\_owner\_id in (82672208 Sufijan Cunningham, 756332149 Abe Underwood, 82734543 Elisabeth Rogers, 756339074 Melissa Davis, 76930546 Henna Shakoor) |
| **Filter 4** | renewal\_pipeline\_type \= 'Referral' |
| **Formula** | Sum of all 11 components |
| **Group By** | hubspot\_owner\_id |
| **Settings** | Prefix: $  |  Decimals: 0 |
| **NOTE** | Only column using renewal\_pipeline\_type instead of renewal\_product. |

| \#32  Total Cash (Row Total) |  |
| :---- | :---- |
| *Sum of all 10 pipeline type columns per closer.* |  |
| **Formula** | MM T1 (\#22) \+ MM T2 (\#23) \+ MM T3 (\#24) \+ MM Restart (\#25) \+ ACC T1 (\#26) \+ ACC T2 (\#27) \+ ACC Upgrade (\#28) \+ ACC Restart (\#29) \+ MM Upgrade (\#30) \+ Referral (\#31) |
| **Group By** | closer |
| **Settings** | Prefix: $  |  Decimals: 0 |

| \#33  \# Closed |  |
| :---- | :---- |
| *Count of closed won deals per closer in the date range.* |  |
| **Object** | DEAL |
| **Metric** | Count of deals |
| **Date Field** | Renewal \- Close Date, within date range |
| **Filter 1** | pipeline in (Renewal Sales Pipeline, Renewal Pipeline) |
| **Filter 2** | dealstage in (Renewal Closed Won \- PIF, Renewal Closed Won \- Payment Plan, Closed Won) |
| **Filter 3** | hubspot\_owner\_id in (82672208 Sufijan Cunningham, 756332149 Abe Underwood, 82734543 Elisabeth Rogers, 756339074 Melissa Davis, 76930546 Henna Shakoor) |
| **Group By** | hubspot\_owner\_id |
| **Settings** | Decimals: 0 |

| \#34  Close% |  |
| :---- | :---- |
| *Percentage of deals assigned to the closer that resulted in a close.* |  |
| **Numerator** | \# Closed (\#33) |
| **Denominator** | Total deals in pipeline assigned to this closer (pipeline in renewal pipelines \+ hubspot\_owner\_id \= closer) |
| **Formula** | Numerator / Denominator x 100 |
| **Group By** | closer |
| **Settings** | Suffix: %  |  Decimals: 0 |

| \#35  vs Prior Month MTD |  |
| :---- | :---- |
| *Month-over-month cash comparison. Current MTD total cash minus same elapsed days in the prior month.* |  |
| **Current** | Total Cash (\#32) for current month through today |
| **Prior** | Total Cash using same formula but for prior month, same number of elapsed days |
| **Formula** | Current \- Prior |
| **Group By** | closer |
| **Settings** | Prefix: $ with \+/- sign  |  Decimals: 0  |  Green if positive, red if negative |

**HUBSPOT PIPELINE SNAPSHOT**

**Live deal stage snapshot showing where each closer's deals currently sit. This is NOT date-filtered; it counts deals in each stage right now. Attribution: hubspot\_owner\_id.**

*v2: Added Renewal Pipeline stages (New Member, Progress Call 1 Completed) per Celeste feedback.*

**RENEWAL SALES PIPELINE (95211801)**

| \#36  PC Due (Midway Check In Due) |  |
| :---- | :---- |
| *Deals currently in the Midway Check In Due stage.* |  |
| **Object** | DEAL |
| **Metric** | Count of deals |
| **Filter 1** | pipeline \= Renewal Sales Pipeline (95211801) |
| **Filter 2** | dealstage \= 'Midway Check In Due' (175326088) |
| **Filter 3** | hubspot\_owner\_id in (82672208 Sufijan Cunningham, 756332149 Abe Underwood, 82734543 Elisabeth Rogers, 756339074 Melissa Davis, 76930546 Henna Shakoor) |
| **Group By** | hubspot\_owner\_id |
| **Settings** | Decimals: 0 |
| **NOTE** | Group: Progress Call (purple in wireframe). |

| \#37  PC Invited (Midway Check In Invited) |  |
| :---- | :---- |
| *Deals currently in the Midway Check In Invited stage.* |  |
| **Object** | DEAL |
| **Metric** | Count of deals |
| **Filter 1** | pipeline \= Renewal Sales Pipeline (95211801) |
| **Filter 2** | dealstage \= 'Midway Check In Invited' (240516941) |
| **Filter 3** | hubspot\_owner\_id in (82672208 Sufijan Cunningham, 756332149 Abe Underwood, 82734543 Elisabeth Rogers, 756339074 Melissa Davis, 76930546 Henna Shakoor) |
| **Group By** | hubspot\_owner\_id |
| **Settings** | Decimals: 0 |

| \#38  PC Scheduled (Midway Check In Scheduled) |  |
| :---- | :---- |
| *Deals currently in the Midway Check In Scheduled stage.* |  |
| **Object** | DEAL |
| **Metric** | Count of deals |
| **Filter 1** | pipeline \= Renewal Sales Pipeline (95211801) |
| **Filter 2** | dealstage \= 'Midway Check In Scheduled' (175346325) |
| **Filter 3** | hubspot\_owner\_id in (82672208 Sufijan Cunningham, 756332149 Abe Underwood, 82734543 Elisabeth Rogers, 756339074 Melissa Davis, 76930546 Henna Shakoor) |
| **Group By** | hubspot\_owner\_id |
| **Settings** | Decimals: 0 |

| \#39  PC Not Cmplt (Midway Not Complete) |  |
| :---- | :---- |
| *Deals currently in the Midway Check in Not Complete stage.* |  |
| **Object** | DEAL |
| **Metric** | Count of deals |
| **Filter 1** | pipeline \= Renewal Sales Pipeline (95211801) |
| **Filter 2** | dealstage \= 'Midway Check in Not Complete' (200475939) |
| **Filter 3** | hubspot\_owner\_id in (82672208 Sufijan Cunningham, 756332149 Abe Underwood, 82734543 Elisabeth Rogers, 756339074 Melissa Davis, 76930546 Henna Shakoor) |
| **Group By** | hubspot\_owner\_id |
| **Settings** | Decimals: 0 |

| \#40  PC Completed (Midway Complete) |  |
| :---- | :---- |
| *Deals currently in the Midway Check in Complete \- Nurture stage.* |  |
| **Object** | DEAL |
| **Metric** | Count of deals |
| **Filter 1** | pipeline \= Renewal Sales Pipeline (95211801) |
| **Filter 2** | dealstage \= 'Midway Check in Complete \- Nurture' (186330445) |
| **Filter 3** | hubspot\_owner\_id in (82672208 Sufijan Cunningham, 756332149 Abe Underwood, 82734543 Elisabeth Rogers, 756339074 Melissa Davis, 76930546 Henna Shakoor) |
| **Group By** | hubspot\_owner\_id |
| **Settings** | Decimals: 0 |

| \#41  RC Due (Renewal Call Due) |  |
| :---- | :---- |
| *Deals currently in the Renewal Call Due stage.* |  |
| **Object** | DEAL |
| **Metric** | Count of deals |
| **Filter 1** | pipeline \= Renewal Sales Pipeline (95211801) |
| **Filter 2** | dealstage \= 'Renewal Call Due' (203001161) |
| **Filter 3** | hubspot\_owner\_id in (82672208 Sufijan Cunningham, 756332149 Abe Underwood, 82734543 Elisabeth Rogers, 756339074 Melissa Davis, 76930546 Henna Shakoor) |
| **Group By** | hubspot\_owner\_id |
| **Settings** | Decimals: 0 |
| **NOTE** | Group: Renewal Call (green in wireframe). |

| \#42  RC Invited (Renewal Call Invited) |  |
| :---- | :---- |
| *Deals currently in the Renewal Call Invited stage.* |  |
| **Object** | DEAL |
| **Metric** | Count of deals |
| **Filter 1** | pipeline \= Renewal Sales Pipeline (95211801) |
| **Filter 2** | dealstage \= 'Renewal Call Invited' (240516942) |
| **Filter 3** | hubspot\_owner\_id in (82672208 Sufijan Cunningham, 756332149 Abe Underwood, 82734543 Elisabeth Rogers, 756339074 Melissa Davis, 76930546 Henna Shakoor) |
| **Group By** | hubspot\_owner\_id |
| **Settings** | Decimals: 0 |

| \#43  RC Scheduled (Renewal Call Scheduled) |  |
| :---- | :---- |
| *Deals currently in the Renewal Call Scheduled stage.* |  |
| **Object** | DEAL |
| **Metric** | Count of deals |
| **Filter 1** | pipeline \= Renewal Sales Pipeline (95211801) |
| **Filter 2** | dealstage \= 'Renewal Call Scheduled' (186350393) |
| **Filter 3** | hubspot\_owner\_id in (82672208 Sufijan Cunningham, 756332149 Abe Underwood, 82734543 Elisabeth Rogers, 756339074 Melissa Davis, 76930546 Henna Shakoor) |
| **Group By** | hubspot\_owner\_id |
| **Settings** | Decimals: 0 |

| \#44  RC Not Cmplt (Renewal Call Not Complete) |  |
| :---- | :---- |
| *Deals currently in the Renewal Call Not Complete stage.* |  |
| **Object** | DEAL |
| **Metric** | Count of deals |
| **Filter 1** | pipeline \= Renewal Sales Pipeline (95211801) |
| **Filter 2** | dealstage \= 'Renewal Call Not Complete' (175346326) |
| **Filter 3** | hubspot\_owner\_id in (82672208 Sufijan Cunningham, 756332149 Abe Underwood, 82734543 Elisabeth Rogers, 756339074 Melissa Davis, 76930546 Henna Shakoor) |
| **Group By** | hubspot\_owner\_id |
| **Settings** | Decimals: 0 |

| \#45  Nurture |  |
| :---- | :---- |
| *Deals currently in nurture stages (post follow-up or post renewal call). Excludes Midway Complete which is counted in PC Completed.* |  |
| **Object** | DEAL |
| **Metric** | Count of deals |
| **Filter 1** | pipeline \= Renewal Sales Pipeline (95211801) |
| **Filter 2** | dealstage in ('Renewal Call Complete \- Nurture' (200616252), 'Follow Up Call Complete \- Nurture' (1021424915)) |
| **Filter 3** | hubspot\_owner\_id in (82672208 Sufijan Cunningham, 756332149 Abe Underwood, 82734543 Elisabeth Rogers, 756339074 Melissa Davis, 76930546 Henna Shakoor) |
| **Group By** | hubspot\_owner\_id |
| **Settings** | Decimals: 0 |
| **NOTE** | Group: Other. Does NOT include Midway Complete \- Nurture (that is PC Completed \#40). |

| \#46  Redzone |  |
| :---- | :---- |
| *Deals currently in the Renewal Red Zone stage.* |  |
| **Object** | DEAL |
| **Metric** | Count of deals |
| **Filter 1** | pipeline \= Renewal Sales Pipeline (95211801) |
| **Filter 2** | dealstage \= 'Renewal Red Zone' (175346329) |
| **Filter 3** | hubspot\_owner\_id in (82672208 Sufijan Cunningham, 756332149 Abe Underwood, 82734543 Elisabeth Rogers, 756339074 Melissa Davis, 76930546 Henna Shakoor) |
| **Group By** | hubspot\_owner\_id |
| **Settings** | Decimals: 0 |

| \#47  Closed Won (Both Pipelines) |  |
| :---- | :---- |
| *Deals currently in a closed won stage across both pipelines.* |  |
| **Object** | DEAL |
| **Metric** | Count of deals |
| **Filter 1** | pipeline in (Renewal Sales Pipeline, Renewal Pipeline) |
| **Filter 2** | dealstage in ('Renewal Closed Won \- PIF' (175346331), 'Renewal Closed Won \- Payment Plan' (229787714), 'Closed Won' (1359841456)) |
| **Filter 3** | hubspot\_owner\_id in (82672208 Sufijan Cunningham, 756332149 Abe Underwood, 82734543 Elisabeth Rogers, 756339074 Melissa Davis, 76930546 Henna Shakoor) |
| **Group By** | hubspot\_owner\_id |
| **Settings** | Decimals: 0  |  Color: green |

| \#48  Closed Lost |  |
| :---- | :---- |
| *Deals currently in a lost stage.* |  |
| **Object** | DEAL |
| **Metric** | Count of deals |
| **Filter 1** | pipeline \= Renewal Sales Pipeline (95211801) |
| **Filter 2** | dealstage in ('Renewal Deal Lost' (175346332), 'Renewal Deal DNC' (209616300)) |
| **Filter 3** | hubspot\_owner\_id in (82672208 Sufijan Cunningham, 756332149 Abe Underwood, 82734543 Elisabeth Rogers, 756339074 Melissa Davis, 76930546 Henna Shakoor) |
| **Group By** | hubspot\_owner\_id |
| **Settings** | Decimals: 0  |  Color: red |

**RENEWAL PIPELINE (898243912)**

*v2: Added per Celeste feedback.*

| \#49  New Member (Renewal Pipeline) |  |
| :---- | :---- |
| *Deals currently in the New Member stage of the Renewal Pipeline.* |  |
| **Object** | DEAL |
| **Metric** | Count of deals |
| **Filter 1** | pipeline \= Renewal Pipeline (898243912) |
| **Filter 2** | dealstage \= 'New Member' (1359829634) |
| **Filter 3** | hubspot\_owner\_id in (82672208 Sufijan Cunningham, 756332149 Abe Underwood, 82734543 Elisabeth Rogers, 756339074 Melissa Davis, 76930546 Henna Shakoor) |
| **Group By** | hubspot\_owner\_id |
| **Settings** | Decimals: 0 |
| **NOTE** | v2: NEW formula. Renewal Pipeline stage. |

| \#50  Progress Call 1 Completed (Renewal Pipeline) |  |
| :---- | :---- |
| *Deals currently in the Progress Call 1 Completed stage of the Renewal Pipeline.* |  |
| **Object** | DEAL |
| **Metric** | Count of deals |
| **Filter 1** | pipeline \= Renewal Pipeline (898243912) |
| **Filter 2** | dealstage \= 'Progress Call 1 Completed' (1359841795) |
| **Filter 3** | hubspot\_owner\_id in (82672208 Sufijan Cunningham, 756332149 Abe Underwood, 82734543 Elisabeth Rogers, 756339074 Melissa Davis, 76930546 Henna Shakoor) |
| **Group By** | hubspot\_owner\_id |
| **Settings** | Decimals: 0 |
| **NOTE** | v2: NEW formula. Renewal Pipeline stage. |

| \#51  Total (Pipeline Snapshot) |  |
| :---- | :---- |
| *Total deals across all displayed pipeline stages per closer.* |  |
| **Formula** | PC Due (\#36) \+ PC Invited (\#37) \+ PC Scheduled (\#38) \+ PC Not Cmplt (\#39) \+ PC Completed (\#40) \+ RC Due (\#41) \+ RC Invited (\#42) \+ RC Scheduled (\#43) \+ RC Not Cmplt (\#44) \+ Nurture (\#45) \+ Redzone (\#46) \+ Closed Won (\#47) \+ Closed Lost (\#48) \+ New Member (\#49) \+ PC 1 Completed (\#50) |
| **Group By** | closer |
| **Settings** | Decimals: 0 |
| **NOTE** | v2: Updated to include Renewal Pipeline stages. Follow Up stages (Due, Invited, Scheduled, Not Complete) from Renewal Sales Pipeline are excluded. |

**BOOKING & SHOW RATES**

Simplified view of booking and show rate metrics per closer. These are the same calculations as the Call Outcomes percentages, presented in a compact table.

| \#52  PC Book% |  |
| :---- | :---- |
| *Same as Call Outcomes \#13. Booking rate for progress calls.* |  |
| **Numerator** | PC Booked (\#11): meetings of PC types where outcome \!= CANCELED |
| **Denominator** | PC Invited (\#10): all meetings of PC types |
| **Formula** | Numerator / Denominator x 100 |
| **Group By** | closer (hubspot\_owner\_id) |
| **Settings** | Suffix: %  |  Decimals: 0 |

| \#53  PC Show% |  |
| :---- | :---- |
| *Same as Call Outcomes \#14. Show rate for booked progress calls.* |  |
| **Numerator** | PC Completed (\#12): meetings of PC types where outcome \= COMPLETED |
| **Denominator** | PC Booked (\#11) |
| **Formula** | Numerator / Denominator x 100 |
| **Group By** | closer (hubspot\_owner\_id) |
| **Settings** | Suffix: %  |  Decimals: 0 |

| \#54  RC Book% |  |
| :---- | :---- |
| *Same as Call Outcomes \#19. Booking rate for renewal calls.* |  |
| **Numerator** | RC Booked (\#17): meetings of RC types where outcome \!= CANCELED |
| **Denominator** | RC Invited (\#16): all meetings of RC types |
| **Formula** | Numerator / Denominator x 100 |
| **Group By** | closer (hubspot\_owner\_id) |
| **Settings** | Suffix: %  |  Decimals: 0 |

| \#55  RC Show% |  |
| :---- | :---- |
| *Same as Call Outcomes \#20. Show rate for booked renewal calls.* |  |
| **Numerator** | RC Completed (\#18): meetings of RC types where outcome \= COMPLETED |
| **Denominator** | RC Booked (\#17) |
| **Formula** | Numerator / Denominator x 100 |
| **Group By** | closer (hubspot\_owner\_id) |
| **Settings** | Suffix: %  |  Decimals: 0 |

| \#56  PWC Completed |  |
| :---- | :---- |
| *Count of completed Post Webinar Call meetings in the period.* |  |
| **Object** | MEETING |
| **Metric** | Count of meetings |
| **Date Field** | hs\_meeting\_start\_time within date range |
| **Filter 1** | hs\_activity\_type \= 'Renewal Post Webinar Call' |
| **Filter 2** | hs\_meeting\_outcome \= 'COMPLETED' |
| **Filter 3** | hubspot\_owner\_id in (82672208 Sufijan Cunningham, 756332149 Abe Underwood, 82734543 Elisabeth Rogers, 756339074 Melissa Davis, 76930546 Henna Shakoor) |
| **Group By** | hubspot\_owner\_id |
| **Settings** | Decimals: 0 |
| **NOTE** | v2: NEW formula for Post Webinar Call tracking. |

| \#57  PWC Close% |  |
| :---- | :---- |
| *Close rate from completed Post Webinar calls.* |  |
| **Numerator** | Count of closed won deals (pipeline \+ won stages \+ close date in range \+ hubspot\_owner\_id in closers) |
| **Denominator** | PWC Completed (\#56) |
| **Formula** | Numerator / Denominator x 100 |
| **Group By** | closer |
| **Settings** | Suffix: %  |  Decimals: 0 |
| **NOTE** | v2: NEW formula. Shows how effective Post Webinar calls are at closing. |

