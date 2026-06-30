# Frostbyte Outfitters — Company Brief

A storyline for the ELT Snowflake Intelligence multi-agent build.

---

## The Company

**Frostbyte Outfitters** is a vertically integrated outdoor brand born in Whistler, BC. They design and sell premium snow gear — touring skis, splitboards, technical apparel, avalanche safety kit — through three channels:

- **DTC e-commerce** (frostbyte.com)
- **Wholesale** to ski-resort pro shops and specialty retailers across NA, EU, JP
- **Frostbyte Pro** — a B2B subscription that bundles fleet gear + analytics for ski schools, guide outfits, and resort rental shops

Their product catalog spans four lines: **Cornice** (touring), **Glacier** (alpine), **Powder** (freeride), and **Whiteout** (safety). Customers range from weekend riders in Colorado to UIAGM guides in Chamonix to a 400-instructor ski school in Hokkaido.

After a Series C, Frostbyte is now ~1,200 employees — sales reps in 14 regions, a 60-person marketing org running global campaigns around season launches, and an HR team scaling headcount 30% YoY to hit a five-year IPO plan.

## The ELT

Frostbyte's nine-person Executive Leadership Team meets every Monday at 7:30am PST for "Summit Sync" — a two-hour cross-functional review of the prior week. Standing agenda:

- CRO: pipeline coverage, top accounts, season pre-orders by region
- CMO: campaign performance, MQL trend, brand sentiment
- CHRO: headcount progress vs. plan, attrition hotspots, comp benchmarking
- CEO: synthesis + cross-domain calls (e.g. "are we hiring fast enough in EMEA to support the Cornice launch in Chamonix?")

## The Problem — Death by Stale Dashboards

Every Friday afternoon, the same ritual plays out across three different floors of Frostbyte HQ:

- A **Sales Ops analyst** spends ~6 hours stitching together Salesforce extracts, NetSuite ARR pulls, and a Looker dashboard whose refresh broke last quarter — to produce one slide of "pipeline by segment."
- A **Marketing analyst** rebuilds attribution numbers in a 14-tab spreadsheet because the campaign-influence dashboard hasn't been re-modeled since the new Glacier line launched.
- An **HRBP** exports headcount from Workday, dedupes contractors by hand, and reconciles it against finance's plan in a Google Sheet — every week.

The numbers arrive late Sunday night. By Monday, the CRO is questioning whether the pipeline number includes Frostbyte Pro renewals or only DTC. The CMO can't tell whether MQLs from the Powder launch turned into closed deals. The CHRO has a snapshot from Wednesday because the dashboard wouldn't refresh.

**The cost**:

- ~140 analyst-hours/week across the three orgs feeding ELT prep — approximately **$1.1M/year of fully-loaded analyst time**
- ELT decisions delayed 3–5 days waiting for "the right number"
- Three times last quarter, two execs cited *different* numbers for the same metric in the same meeting because their dashboards were anchored on different snapshot dates
- Sensitive data (customer PII in marketing exports, comp data in HR sheets) lives in Google Drive screenshots — a compliance audit failure waiting to happen
- New hires onboarding in EMEA waited 6 weeks for "is this in plan?" because the answer required three handoffs

The CDO put it bluntly at the last QBR: *"We're paying a million dollars a year to copy-paste numbers into slides, and we still don't trust them."*

## The Vision — A Personal Work Agent on Snowflake

Frostbyte's CDO and Head of AI Platform have a different bet. They've spent the last two quarters building **`SNOW_CERTIFIED`** — a single, governed, Dynamic-Tables-powered analytics layer in Snowflake — and certified semantic views for the metrics that matter (pipeline ARR, MQL-to-pipeline influence, headcount-as-of-date).

The next step: **give every ELT member a personal Snowflake Intelligence agent that already knows their org, their definitions, and their access rights.**

The vision in one sentence:
> *"Every Frostbyte exec walks into Summit Sync with a Snowflake agent that has already pulled the right numbers, knows what's missing, and refuses to guess — and every IC analyst gets those 6 Friday hours back."*

Concretely:

- **`ELT_ROUTER`** — a top-level agent in Snowsight. CEO asks: *"Are we hiring fast enough in EMEA to support the Cornice launch?"* Router decomposes into a marketing slice (Cornice campaign performance EMEA), a sales slice (Cornice pre-order pipeline EMEA), and an HR slice (EMEA hiring plan vs. actuals). Synthesizes one answer with citations.
- **`MARKETING_AGENT`** — owns campaign ROI, MQL funnel, pipeline influence. Backed by `sv_mkt_*` over certified DTs.
- **`SALES_AGENT`** — owns pipeline coverage, ARR by segment, top accounts. Backed by `sv_sales_*`. Knows the difference between DTC, Wholesale, and Frostbyte Pro ARR — because that lives *in the semantic view*, not in a prompt.
- **`HR_AGENT`** — owns headcount, attrition, comp distribution. Hard-wired to `ACTIVE_STATUS = 1`, latest snapshot, masked comp for anyone outside `HR_PII_RL`.

**Trust by construction, not trust by hope**:
- Metrics are defined once in `SNOW_CERTIFIED` semantic views — every agent answers from the same number.
- Customer PII (lead emails, contact phones) and employee PII (SSN, comp) are auto-classified and masked by a Snowflake-native pipeline before any agent ever sees them.
- The CEO and the CHRO see *different* views of the same employee table, governed by row access policies — by design, not by accident.
- Every agent answer is auditable: query tag, role, version, certified flag.

**The promise to the ELT**:
- Monday morning prep collapses from 140 hours to single-digit minutes of conversation.
- One number, one definition, one certified source.
- Sensitive data never leaves Snowflake — no spreadsheets, no screenshots.
- New questions don't require a new dashboard; they require a question.

**The promise to the analysts**:
- Reclaim 140 Friday hours/week. Spend them on the Cornice EMEA launch model nobody has had time to build.

## Why this is the right moment

Frostbyte's IPO timeline demands cleaner financials, defensible metrics, and an audit-ready PII story. The same data that power Frostbyte Pro's customer-facing analytics will power the ELT's personal agents. Same governance, same lineage, same trust boundary.

That's the storyline the multi-agent build is delivering against — and the plan we're about to refine is the technical blueprint to get Frostbyte from "Sunday-night spreadsheet panic" to "Monday-morning Summit Sync, powered by trustworthy agents."
