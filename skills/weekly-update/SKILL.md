# /weekly-update — OKR-Disciplined Weekly Self-Review

Synthesize a person's weekly inputs (email scan, calendar summary, supporting docs) with live OKR data into a structured self-review that surfaces what moved, what stalled, and what to commit to next.

## Trigger

User invokes `/weekly-update` or `/weekly-update [date-range]`.

**Arguments:**

| Argument | Description | Default |
|----------|-------------|---------|
| `[date-range]` | Folder name like `20260315-21` or `20260329-0404` | None — must specify or be prompted |
| `--narrative` | Skip .md generation, go straight to interactive RTF narrative using existing .md as source | Off |

## Phase 1: Resolve Identity

Determine who is running this:

1. Call `mcp__weeklyops__whoami` — use the returned name
2. If that fails, run `git config user.name` and map to a team member name
3. If neither resolves, ask: "Who are you? (Chris, Mary-Margaret, Fathima, Isaac, Avery, MD, Tyler, David)"

The resolved name determines the folder path. Use lowercase for the folder: `docs/team/chris/`, `docs/team/mary-margaret/`, etc.

**GitHub username resolution:** The skill also needs the person's GitHub username for git log queries. Resolution order:
1. Check `config.yaml` for a `github_username` field on the team member (preferred)
2. Fall back to `git config user.name` (works for the local user)
3. Ask if neither resolves

If `config.yaml` doesn't have `github_username` fields yet, note this and use the git config fallback. Suggest adding the field to config.yaml for future runs.

## Phase 1.5: Automated Data Collection (outlook-tool)

**When to run:** Always attempt before Phase 2. If `outlook-tool` is not available, fall back to manual flow.

**Detection:**
```bash
which outlook-tool 2>/dev/null || python3 -c "from outlook_tool import OutlookClient" 2>/dev/null
```

If neither works, skip to Phase 2 with a note: "outlook-tool not available. Please provide data files manually."

**Step 1: Parse date range into ISO dates**
```python
# "20260315-21" → date_from="2026-03-15", date_to="2026-03-21"
# "20260329-0404" → date_from="2026-03-29", date_to="2026-04-04"
arg = "{date-range}"
year, month, day_from = arg[:4], arg[4:6], arg[6:8]
end_part = arg.split("-")[1]
if len(end_part) == 2:  # same month
    date_from, date_to = f"{year}-{month}-{day_from}", f"{year}-{month}-{end_part}"
elif len(end_part) == 4:  # cross-month
    date_from, date_to = f"{year}-{month}-{day_from}", f"{year}-{end_part[:2]}-{end_part[2:]}"
```

**Step 2: Pull email + calendar timeline (JSON)**
```bash
outlook-tool summary --from {date_from} --to-date {date_to} \
    --folders Inbox Archive Snoozed --format json
```

**Step 3: Pull calendar events with full body/notes**
```bash
outlook-tool events --from {date_from} --to-date {date_to} --json
```

**Step 4: Save raw data + markdown ledger**
```
workspace/{date-range}/data/outlook-summary.json
workspace/{date-range}/data/outlook-events.json
```

Also generate the chronological ledger:
```bash
outlook-tool summary --from {date_from} --to-date {date_to} \
    --folders Inbox Archive Snoozed --format markdown \
    --output {path}/data/{date-range}-chronological-ledger.md
```

**Step 5: Proceed to Phase 2** with JSON files in place.

See `docs/guides/outlook-tool-integration.md` for full JSON schemas and installation instructions.

## Phase 2: Locate and Validate Inputs

**Base path:** `workspace/{date-range}/` (local working directory — final output goes through MCP)

Check that the folder exists. If not, **create the full structure** and give instructions:

1. Create `workspace/{date-range}/data/`
2. Report:

> Created: `workspace/{date-range}/data/`
>
> **Next steps:**
>
> **Option A (automatic — recommended):**
> If `outlook-tool` is installed and Outlook is running, just run `/weekly-update {date-range}` again. Data will be pulled automatically.
>
> **Option B (manual):**
> 1. Add `email-results.md` to the `data/` folder (categorized email scan — see format below)
> 2. Add `calendar-results.md` to the `data/` folder (meeting summaries)
> 3. Optionally add any supporting docs to `data/`
> 4. Run `/weekly-update {date-range}` again
>
> **email-results.md format:**
> ```
> ## 1. {Category Name}
> ### 1a. {Thread Title}
> - **People:** {names with roles}
> - **Dates active:** {range}
> - **Summary:** {what happened}
> - **Status:** {Resolved / Unresolved / Waiting}
> ```
>
> **calendar-results.md format:**
> ```
> ## {Day, e.g., Monday March 15}
> ### {Meeting Title}
> - **Time:** {start – end}
> - **Attendees:** {names}
> - **Summary:** {what was discussed}
> - **Action items:** {if any}
> ```

3. Stop here — do not proceed to Phase 3+.

**Required structure:**
```
docs/team/{name}/weekly-update/{date-range}/
└── data/
    ├── email-results.md       (required)
    ├── calendar-results.md    (required)
    └── ...                    (optional supporting files)
```

**Validation — accept either JSON (auto) or markdown (manual):**

| Check | JSON path | Markdown path |
|-------|-----------|---------------|
| Email data | `data/outlook-summary.json` | `data/email-results.md` (or any `*email*.md`) |
| Calendar data | `data/outlook-events.json` | `data/calendar-results.md` (or any `*calendar*.md`) |

- If `data/` doesn't exist → stop with clear error
- If JSON files exist → use Phase 2b-auto (preferred, more structured)
- If only markdown files exist → use existing Phase 2b/2c parsing
- If both exist → prefer JSON
- If neither → warn but continue (note gap in output)
- Read ALL other files in `data/` as supporting docs — no manifest needed. Context window is the natural throttle.

## Phase 2b: Parse Email Structure

The `email-results.md` file follows a structured format. Expect and parse these elements:

**Expected format:**
```markdown
## {N}. {Category Name}

{Optional category description}

### {Na}. {Thread Title}
- **People:** {comma-separated names with roles}
- **Dates active:** {date range, e.g., 3/6 – 3/16}
- **Summary:** {what happened in this thread}
- **Status:** {Resolved / Unresolved / Waiting / In progress}
```

**How to analyze each field:**

| Field | Analysis |
|-------|----------|
| **Category** | Map to KR sections. Client Escalations → AM/sales KRs. Internal Operations → infra KRs. AI Strategy → infra-1.6, web KRs. Partner Development → efit/sales KRs. Use judgment for ambiguous categories. |
| **People** | Cross-reference with team roster (Chris, Mary-Margaret, Fathima, Isaac, Avery, MD, Tyler, David). If a team member is named, check if the thread relates to their KRs. External people (clients, vendors) indicate AM or partner activity. |
| **Dates active** | Determines if thread is within the review week or carried over from prior weeks. Threads spanning multiple weeks indicate ongoing work. |
| **Summary** | Primary content for KR matching. Look for: KR-relevant keywords (training, billing, data, leads, pipeline, migration, cancellation), client names that map to AM KRs, project names that map to web/infra KRs. |
| **Status** | Drives Section 3 (Blockers & Escalations). **Unresolved** → candidate for blocker or risk. **Resolved** → evidence for KR movement. **Waiting** → dependency to track. |

**KR mapping heuristics:**
- "client escalation" / "cancellation" / "retention" → AM KRs (am-*, amrev-*)
- "training" / "onboarding" / "one-on-one" → infra-1.1
- "feedback" / "check-in" → infra-1.2
- "billing volume" / "active clients" / "datalake" → infra-1.3
- "AI" / "Claude" / "bot" / "Memby" → infra-1.6
- "website" / "astro" / "blog" / "page mapping" → web-1.* KRs
- "lead gen" / "mass email" / "campaign" / "prospect" → web-2.* KRs
- "powerdial" / "call list" → web-3.* KRs
- "Cubiic" / "eFit" / "deal" → efit-* KRs
- "process improvement" / "HubSpot" / "tooling" → cxops-* KRs

Threads that don't match any KR go into the **Unconnected Activity** section of the output. This is not a failure — it's visibility into where time went.

## Phase 2b-auto: Parse outlook-tool JSON

If `outlook-summary.json` exists, use this instead of Phase 2b.

**Thread clustering from flat JSON:**
1. Group emails by normalized subject (strip "Re:", "RE:", "FW:", "Fwd:" prefixes, lowercase, trim)
2. Sort each group by datetime
3. For each thread cluster:
   - `Thread Title` = original subject of first email
   - `People` = unique from_name + from_email across all emails in thread
   - `Dates active` = first → last datetime
   - `Email count` = number of emails in thread
   - `Summary` = body_preview of most recent email
   - `Display IDs` = list of E-numbers (E001, E007, etc.) — preserve these for cross-referencing

**Category clustering:** Apply the KR mapping heuristics from Phase 2b to thread subjects and body previews. Group threads into categories automatically.

**Calendar from JSON:** Map `outlook-events.json` entries directly:
- `Day` = entry["day"]
- `Meeting Title` = entry["subject"]
- `Time` = entry["time"] – entry["end_time"]
- `Attendees` = entry["attendees"][*]["name"]
- `Summary` = entry["body_preview"]
- `Action items` = extract from body if patterns match ("action item", "TODO", "next step")
- `Display ID` = C-number (C001, C003, etc.) — preserve for cross-referencing

After parsing, the data flows into the same Phase 4 synthesis pipeline as the manual markdown path.

## Phase 2c: Parse Calendar Structure

The `calendar-results.md` file should summarize meetings for the week. Expected format:

```markdown
## {Day, e.g., Monday March 15}

### {Meeting Title}
- **Time:** {start – end}
- **Attendees:** {names}
- **Summary:** {what was discussed / decided}
- **Action items:** {if any}
```

**How to analyze:**
- Match meeting topics to KRs using the same heuristics as email
- Flag meetings with no clear KR connection → Unconnected Activity
- Look for action items that imply KR movement next week → feeds Section 4 (Commitments)
- Count total meeting hours as context for the review (high meeting load = less execution time)

If `calendar-results.md` doesn't follow this exact format, adapt — the key fields are: what meeting, who was there, what happened. Extract those however they're structured.

## Phase 3: Pull OKR Context

Call these MCP tools to get live KR data:

1. `mcp__weeklyops__get_person_status` with the resolved name → KR status, pace, trends
2. `mcp__weeklyops__compile_shoutouts` for the relevant week → what was recognized
3. `mcp__weeklyops__get_checkins` for the relevant week → mid-week check-in data

**Map date range to ISO week:** The date range folder (e.g., `20260315-21`) maps to an ISO week for MCP calls. Use the Monday of the range to determine the week (e.g., March 15 2026 = W12). Pass as `2026-W12`.

## Phase 3b: Pull Git Activity

Query git history for the date range across all repos the person works in.

**For the current repo:**
```bash
git log --author="{github_username}" --after="{start_date}" --before="{end_date + 1 day}" --oneline --stat
```

**For other repos** (if the person works across repos — e.g., Chris works in both `weeklyops` and the website repo):
- Check if other repo paths are known (from config or prior runs)
- If accessible, run the same git log there
- If not, note "git activity limited to current repo"

**What to extract:**
- Number of commits
- Files changed, lines added/removed
- PR titles and merge commits
- Bolt/sprint work (look for bolt references in commit messages)
- Group commits by theme (e.g., "hardening", "feature", "docs", "fix")

This feeds into both the `.md` analysis (KR Movement evidence) and the narrative RTF (Progress & Wins).

## Phase 4: Synthesize

Cross-reference all sources to build the output. This is where the value is — not reading files, but finding patterns.

### Step 1: Cluster by Entity

Before mapping to KRs, group all email threads, calendar events, and git commits by **entity** (company, project, or person):

- Group all threads mentioning the same company (e.g., "97 Display" across webinars, ads, billing, swag, HubSpot = one cluster)
- Group all threads mentioning the same project (e.g., "MiGym branded app")
- Group all threads involving the same external person (e.g., "Dimitri / RealtyMark")
- Git commits group by bolt/feature branch or by theme

### Step 2: Size the Clusters

For each cluster, count:
- Number of email threads
- Number of emails across those threads
- Number of calendar events
- Number of git commits

**Significant theme threshold:** Any cluster with 5+ emails OR 3+ threads OR 5+ commits is a "significant theme" — it gets prominent placement in the output regardless of KR connection.

### Step 3: Map Clusters to KRs

Now map each cluster (not individual threads) to KRs using the heuristics from Phase 2b. A cluster may map to:
- **One or more KRs** → goes into Section 1 (KR Movement) as evidence
- **No KR but significant** → goes into a new Section: "Strategic Activity" — work that matters but isn't tracked by a KR
- **No KR and small** → goes into "Administrative" (low-signal, no further analysis needed)

### Step 4: Cross-Reference

**Cross-referencing instructions:**
- Match clustered themes to KRs (e.g., "RealtyMark cluster" → AM KRs)
- Match calendar meetings to clusters (e.g., "Vanessa priorities call" → belongs to the "Internal Ops" cluster)
- Match git activity to KRs (e.g., commits to website repo → web-1.* KRs)
- Identify KRs with movement but no email/calendar/git evidence (shoutout-only updates)
- Identify KRs with zero movement AND zero related activity — these are the neglected ones
- Flag significant themes with no KR connection — these are candidates for new KRs or indicate scope the OKR framework isn't capturing

## Phase 5: Produce Output

**Local draft:** Save a working copy to `workspace/{date-range}/{date-range}-weekly-summary.md` for reference.

**MCP save:** After the user confirms the summary, save the final version via MCP:
- Call `mcp__weeklyops__save_document` with `category="reports"`, `title="Weekly Self-Review {Name} {date-range}"`, and the full summary as content.

This routes the final output to the shared weeklyops-data repo where the team can access it.

### Output Template

```markdown
# Weekly Self-Review: {Name} — {date range human-readable}

**Generated:** {YYYY-MM-DD HH:MM}
**Sources:** email-results.md, calendar-results.md, {N} supporting files
**KR data as of:** {today}

---

## 1. KR Movement This Week

| KR | Description | Was | Now | Change | Evidence |
|----|-------------|-----|-----|--------|----------|
| {kr-id} | {short desc} | {prev} | {current} | {delta} | {email thread or meeting that drove this (E001, C003)} |

{For KRs that moved, 1-2 sentences connecting the activity to the result.}

{For done KRs, a one-line acknowledgment — no victory lap.}

---

## 2. Stalled KRs — Honest Status

| KR | Description | Current | Target | Weeks at 0% | Classification |
|----|-------------|---------|--------|-------------|----------------|
| {kr-id} | {short desc} | {val} | {target} | {N} | **Blocked** / **Deprioritized** / **Neglected** |

For each stalled KR, one of:
- **Blocked:** {What's in the way. Name the dependency.}
- **Deprioritized:** {Why this is a valid choice right now. Say it explicitly.}
- **Neglected:** {Should have worked on this. Didn't. What changed next week.}

> If a KR has been at 0% for 3+ consecutive weeks with no activity, flag it:
> "RECOMMENDATION: Reset target, reassign, or drop. Dead KRs poison the system."

---

## 3. Blockers & Escalations

### True Blockers (external dependency, name attached)
- {Blocker}: waiting on {person/team} since {date}. Impact: {what can't move}.

### Risks (trajectories trending wrong)
- {Risk}: {what's trending and why it matters}.

---

## 4. Next Week's Commitment

Pick 2-3 KRs. Specific actions, specific targets.

| KR | Commitment | Target by EOW |
|----|-----------|---------------|
| {kr-id} | {Specific action} | {Measurable target} |

---

## Strategic Activity

{Significant themes (5+ emails or 3+ threads or 5+ commits) that don't connect to a tracked KR. These are real work — partnerships, vendor evaluations, cross-company initiatives — that the OKR framework isn't capturing.}

| Theme | Emails | Threads | Summary |
|-------|--------|---------|---------|
| {entity/project} | {N} | {N} | {one-line summary} |

{For each significant theme, 2-3 sentences on what happened, who's involved, and whether this should become a KR or remain untracked.}

---

## Git Activity

{Commits, PRs, and code changes for the week.}

- **Commits:** {N} across {repos}
- **Lines:** +{added} / -{removed}
- **Key changes:** {grouped by theme}

---

## Administrative

{Low-signal items: vendor notifications, logistics, routine approvals. Listed for completeness, no analysis needed.}
```

## Phase 6: Narrative RTF

### Entry Points

- **After Phase 5 completes:** Ask "Ready to build the narrative RTF? (yes / skip)". If skip → done.
- **`--narrative` flag:** Skip Phases 1-5. Find the most recent `.md` summary in the week folder, use it as source material, and go straight to the interactive loop below.

### Tone Shift

The `.md` is honest self-review ("neglected", "dead KRs"). The `.rtf` is leadership-appropriate narrative:
- "Neglected" → "deprioritized in favor of [what actually happened]" or "pipeline sequencing required [X] before [Y]"
- "Dead KRs" → "recommend scope adjustment for Q2 planning"
- First person plural ("we") or third person ("the team") rather than "I"
- Confident, concise, no hedging — but honest about gaps

### Interactive Loop

Work through each section one at a time. For each section:

1. **Draft** the section based on the `.md` analysis
2. **Present** it to the user
3. **Wait** for feedback — the user may say:
   - "good" / "continue" → move to next section
   - Specific edits ("add X", "tone down Y", "remove the bit about Z")
   - "rewrite" → redraft the whole section
4. **Apply** edits and re-present if needed
5. **Move on** only when the user says continue

### Narrative Sections (in order)

**1. Executive Summary** (2-3 paragraphs)
- Lead with the headline: what moved, what's the overall trajectory
- Mention key wins without granular KR IDs (those go in later sections)
- Flag the 1-2 most important risks or decisions needed
- Set the tone for the rest of the document

**2. Progress & Wins**
- Narrative version of Section 1 (KR Movement)
- Group related KR movement into themes ("Website rebuild completed ahead of schedule...")
- Connect activity to outcomes, not just numbers
- Done KRs get a sentence of context, not a table row

**3. Areas Requiring Attention**
- Narrative version of Section 2 (Stalled KRs) — reframed for leadership
- Group by theme: "Lead generation pipeline", "Cubiic deal development"
- For each: what's the situation, why, what's the plan
- Recommendations framed as forward-looking proposals, not admissions

**4. Blockers & Escalations**
- Narrative version of Section 3
- Lead with impact, then the dependency
- Escalation requests should be clear and actionable: "Requesting [person] to [action] by [date]"

**5. Next Week's Focus**
- Narrative version of Section 4 (Commitments)
- 2-3 specific priorities with expected outcomes
- Tie back to the trajectory from the executive summary

**6. Other Notable Activity** (optional — only if user wants it)
- Curated version of Unconnected Activity
- Reframed as "cross-functional work" or "partnership development" — not "stuff that didn't move a KR"
- User decides what to include and what to leave out

### Produce RTF Output

After all sections are approved:

**Local file:** `workspace/{date-range}/{date-range}-weekly-update.rtf`

After generating, also save the narrative as markdown via MCP:
- Call `mcp__weeklyops__save_document` with `category="reports"`, `title="Weekly Update Narrative {Name} {date-range}"`, and the narrative text as content.

Generate the RTF with:
- **Font:** Helvetica or Arial, 11pt body, 14pt headings
- **Headings:** Bold, with spacing above
- **Bullet points:** Where appropriate
- **Bold** for emphasis on key terms
- **No colors** — clean black on white
- **Page header:** "{Name} — Weekly Update: {date range human-readable}"

Use Python to generate the RTF file:

```python
# Use basic RTF markup — no external dependencies needed
# Structure: {\rtf1\ansi ... }
# Bold: {\b text}
# Heading: {\b\fs28 text}\par
# Body: {\fs22 text}\par
# Bullet: {\pntext\bullet}\tab text\par
```

The RTF should open cleanly in TextEdit, Word, or any RTF reader.

## Edge Cases

- **No KR movement at all:** Section 1 says "No KR values changed this week." Don't fabricate movement.
- **MCP tools unavailable:** Note "KR data unavailable — review based on email/calendar only" and skip sections that need KR data.
- **Empty data/ folder:** "No files found in data/. Add email-results.md and calendar-results.md, then run again." Show the format templates from Phase 2.
- **Second run same week:** Produces a new timestamped file alongside the first. No overwrite.
- **`--narrative` with no existing .md:** Error: "No weekly summary .md found in this folder. Run `/weekly-update {date-range}` first to generate the analysis, then use `--narrative`."
- **`--narrative` with multiple .md files:** Use the most recent one (by timestamp in filename).
