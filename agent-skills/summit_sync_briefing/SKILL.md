---
name: summit_sync_briefing
description: |
  Frostbyte ELT Monday "Summit Sync" briefing. Personalized greeting plus a
  single-page brief covering campaign performance (Cornice / Glacier across
  NA / EMEA / JP), pipeline coverage by channel (DTC / Wholesale / Frostbyte Pro),
  and headcount vs plan. Triggers include "good morning", "summit sync",
  "monday brief", and "catch me up".
created_date: 2026-06-05
last_updated: 2026-06-23
owner_name: Frostbyte Data & AI
version: 1.0.0
---

# Summit Sync Briefing — Personalized ELT Daily Brief

You are producing the executive's personalized Monday Summit Sync brief. Follow
the steps below exactly.

## When to activate

User says any of:
- "Good morning"
- "Summit sync"
- "Monday brief" / "Monday briefing"
- "Catch me up"

## Step 1 — Resolve the user (run FIRST)

Run the SQL in [queries/user_context.sql](queries/user_context.sql). This returns:
- `first_name`
- `title`
- `region`  (NA / EMEA / JP, or NULL for global executives)
- `org_filter` (a predicate to scope the brief to the exec's org)

If 0 rows are returned, omit the user's first name in the greeting.

## Step 2 — Greeting

`## Good Morning, <first_name>` (or `## Good Morning` if name unknown).

Single sentence intro referencing the current week (`week of <Monday date>`) and
the exec's role / region.

## Step 3 — Fan out in parallel to the three sub-agents

Use the router's delegation tools. Pass the exec's `region` as a constraint
when populated; otherwise ask for the global view.

- `delegate_to_marketing` -> *"Cornice and Glacier campaign ROI, lead counts,
  and conversion rates for {region}. Break down by product line."*
- `delegate_to_sales` -> *"Pipeline coverage by channel (DTC, Wholesale,
  Frostbyte Pro) for {region} this week; pre-orders by product line."*
- `delegate_to_hr` -> *"Current headcount by org unit for {region}; attrition
  last 30 days."*

If any sub-agent reports "this metric is not currently certified", **do not
fabricate**. State the gap and recommend contacting the data owner.

## Step 4 — Synthesize

Render exactly per [references/output_template.md](references/output_template.md).

## Step 5 — Watch list

One line at the bottom flagging:
- any cross-domain inconsistency (e.g., marketing claims X EMEA leads but sales
  reports Y closed opps, ratio out of band)
- any uncertified metric encountered
- any sub-agent timeout or refusal

## Refusal policy

- Out-of-scope topics (forecasting, financial close, legal): decline politely.
- Individual employee compensation: decline.
- Customer PII (lead emails, contact phones): decline; the platform masks
  these anyway, but never request them in the prompt.
