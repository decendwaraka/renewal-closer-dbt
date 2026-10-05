# renewal-closer-dbt

dbt project powering the Renewal Closer dashboard (frontend repo: `Dashboards/renewal-closer`,
a separate git repo). Transforms Fivetran-synced HubSpot data in Snowflake into the marts the
dashboard reads from `PRODUCTION.RENEWAL_MARTS`.

## Read .claude/memory/ before starting work

`.claude/memory/` mirrors this project's accumulated session memory (business logic, prior
validation findings, resolved issues, feedback on how to work in this repo) — local-only, not
committed. Start with `MEMORY.md` there for the index, then read whichever linked files are
relevant to the task at hand. It's a snapshot as of when it was copied — if something it says
conflicts with the current state of the code or `ref_docs/OPEN_ISSUES.md`, trust what you observe
now over the memory file.

## Always update ref_docs/OPEN_ISSUES.md after fixing anything

`ref_docs/OPEN_ISSUES.md` is the living, authoritative tracker of every known defect/gap in this
project — gitignored, local-only, never committed. After fixing, building, deploying, or resolving
*anything* covered by an entry in that file (or that should become a new entry), update the file
in the same turn:

- **Fully resolved and deployed** (merged + `dbt build --target prod` run, or otherwise confirmed
  live) → remove the entry entirely. The file's own convention is "resolved issues are removed —
  this list is pending items only."
- **Built but not yet merged/deployed** → keep the entry, update status to reflect what's actually
  done vs. remaining (e.g. "built, awaiting PR merge" → "merged, awaiting prod deploy").
- **New defect found** (from a review, a stakeholder comment, or your own investigation) → add a
  new entry using the next available `#` number and the existing format (Observed / Investigated /
  Action / Affected files), correctly bucketed under the right status header (🔴/🟠/🟡/🟣/⚪, see the
  legend at the top of the file).
- Keep the "At a glance" table and "Formula coverage summary" in sync with whatever entries you
  add, remove, or change.

Also keep `ref_docs/slack.md` in sync when a fix resolves or creates a stakeholder-facing question —
move resolved threads out of the "needs clarification" list, add new questions there when a fix
surfaces one, and don't leave stale asks sitting in the clarification section once they're answered.

Do this as part of the same piece of work, not as a follow-up someone has to remember to ask for.
