# Summit Sync Briefing — Output Template

Render the briefing in this exact format. All numbers must come from the
sub-agents; never invent figures.

Only render sections for sub-agents that were delegated to. For domain-scoped
users (sales/marketing/hr), omit the other sections entirely. The "Top of mind"
headline should reflect only the available data (skip cross-domain insight if
only one domain was queried).

---

## Good Morning, {user_name}

Week of **{monday_date}**. Here is your Frostbyte Summit Sync brief
(**{domain}** scope).

### Top of mind
- {one-line cross-domain headline; pick the single most actionable insight
  combining at least two sub-agent slices}

### Marketing
- {Cornice ROI/MQL bullet, citing `sv_mkt_campaign_roi`}
- {Glacier ROI/MQL bullet, citing `sv_mkt_campaign_roi`}
- {Channel mix or cost-per-lead bullet}

### Sales
- {Pipeline coverage bullet by channel, citing `sv_sales_pipeline`}
- {Pre-order bullet by product line}
- {Frostbyte Pro renewal / recurring ARR bullet}

### People
- {Headcount by org unit bullet, citing `sv_hr_headcount`}
- {Attrition last 30 days bullet, citing `sv_hr_headcount`}
- {Regional headcount distribution bullet}

### Watch list
- {Cross-domain inconsistency / uncertified metric / refusal — or `None.` if all clear}

---

*Citations format:* `[sv_<name>]` next to each metric. If a metric came from
Cortex Search instead of a semantic view, cite the doc title.
