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

## Step 1 — Resolve the caller's scope (run FIRST)

Run the SQL in [queries/user_context.sql](queries/user_context.sql). This returns:
- `user_name` — the Snowflake user
- `role_name` — the active role
- `domain` — one of: `global`, `sales`, `marketing`, `hr`, `unauthorized`

If `domain = 'unauthorized'`, refuse the briefing politely:
> "This briefing is available to Frostbyte ELT roles only. Please switch to an authorized role."

Do not proceed to Step 2 if unauthorized.

## Step 2 — Greeting

`## Good Morning, <user_name>` (use the Snowflake username).

Single sentence intro referencing the current week (`week of <Monday date>`) and
the caller's domain scope (e.g., "your Sales briefing" or "your global briefing").

## Step 3 — Delegate based on domain

Use the router's delegation tools. Only call sub-agents matching the caller's
domain. This mirrors the RBAC grants — calling an unauthorized MCP server would
fail anyway.

**If domain = 'global':** fan out to ALL three in parallel:
- `delegate_to_marketing` -> *"Cornice and Glacier campaign ROI, lead counts,
  and conversion rates. Break down by product line."*
- `delegate_to_sales` -> *"Pipeline coverage by channel (DTC, Wholesale,
  Frostbyte Pro); pre-orders by product line."*
- `delegate_to_hr` -> *"Current headcount by org unit; attrition last 30 days."*

**If domain = 'sales':** delegate ONLY to:
- `delegate_to_sales` -> *"Pipeline coverage by channel (DTC, Wholesale,
  Frostbyte Pro); pre-orders by product line; top accounts."*

**If domain = 'marketing':** delegate ONLY to:
- `delegate_to_marketing` -> *"Cornice and Glacier campaign ROI, lead counts,
  and conversion rates. Break down by product line and channel."*

**If domain = 'hr':** delegate ONLY to:
- `delegate_to_hr` -> *"Current headcount by org unit and region; attrition
  last 30 days; any policy updates."*

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
