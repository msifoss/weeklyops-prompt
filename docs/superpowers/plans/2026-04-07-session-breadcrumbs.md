# Session Breadcrumbs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add ambient session breadcrumb behavior to weeklyops-prompt so conversation context auto-persists to workspace/ and can be pushed to MCP.

**Architecture:** Pure CLAUDE.md instruction addition — no code, no new skills. Claude Code follows behavioral instructions to append breadcrumb entries to a session file during conversation, gate session start on resolving old files, and offer MCP push at session end.

**Tech Stack:** CLAUDE.md instructions, Write tool (append via Edit), MCP `save_document` tool

---

### Task 1: Add Breadcrumb Behavior Section to CLAUDE.md

**Files:**
- Modify: `CLAUDE.md:78` (after the Working Directory section)

- [ ] **Step 1: Read current CLAUDE.md to confirm insertion point**

Read `CLAUDE.md` and confirm the file ends after the Working Directory section (line ~79).

- [ ] **Step 2: Draft the breadcrumb instructions block**

Add the following section to the end of `CLAUDE.md`:

```markdown
## Session Breadcrumbs

Automatically capture key conversation moments to a local file so nothing is lost if the session ends abruptly.

### Session Start Gate

Before beginning any new work at session start, check for existing files matching `workspace/session-*.md`.

If files exist:
1. List them by filename (do NOT dump contents — just show filenames and dates)
2. For each file, ask: **Push to MCP** or **Discard**?
   - **Push:** Read the file, prepend a 2-line summary, save via `save_document(category="notes", title="Session breadcrumbs — {date from filename}")`, then delete the local file
   - **Discard:** Delete the file immediately
3. Do NOT proceed with new work until all old session files are resolved
4. Maximum 3 session files may exist. If at cap, you must resolve before creating a new one.

### Session File Creation

On the first substantive interaction of a session (after the start gate), create:

```
workspace/session-{username}-YYYYMMDD-HHMM.md
```

Where `{username}` comes from `config.yaml`. Write this header:

```markdown
# Session Breadcrumbs — {YYYY-MM-DD HH:MM}
**User:** {name}
```

### When to Write a Breadcrumb Entry

Append an entry ONLY when you observe one of these three trigger categories:

1. **State change** — a KR value was discussed or updated, a document was saved via MCP, a todo was completed or created
2. **Commitment** — a decision was stated, an action item was assigned, a deadline was set
3. **Escalation** — a blocker was raised, a risk was flagged, a concern was escalated

Do NOT log routine Q&A, greetings, file reads, or exploratory discussion. If in doubt, don't log it.

### Entry Format

Append to the session file using the Edit tool:

```markdown
## HH:MM — {Category}
{1-3 line description of what happened}
```

Where Category is one of: `State Change`, `Commitment`, `Escalation`.

One Write/Edit call per entry. Never rewrite the whole file.

### Privacy Gate

Before writing ANY breadcrumb entry, scan the entry text for:
- API keys or tokens (patterns: `sk-`, `ghp_`, `AKIA`, `Bearer`, `token=`, `key=`)
- Passwords near assignment operators (`password=`, `passwd:`, `secret=`)
- Content that appears to come from `.env` files

If a match is found:
1. Show the user the flagged content
2. Ask: "This looks like it may contain sensitive data. **Redact** and write, or **Skip** this entry?"
3. Do NOT write until the user responds

This scanner targets high-confidence secrets only. Team member names, emails, and phone numbers are normal business data and should NOT be flagged.

### User Controls

- **"pause breadcrumbs"** — stop capturing entries until resumed. Acknowledge with "Breadcrumbs paused."
- **"resume breadcrumbs"** — restart capturing. Acknowledge with "Breadcrumbs resumed."
- **"push breadcrumbs"** — immediately push the current session file to MCP:
  1. Read the session file
  2. Prepend a 2-line summary of the session
  3. Save via `save_document(category="notes", title="Session breadcrumbs — {date}")`
  4. Confirm MCP save succeeded. If it fails, retry once, then warn the user.
  5. Delete the local file
  6. Create a fresh session file to continue capturing

### End of Session

When the conversation appears to be wrapping up (user says goodbye, thanks, "that's all", etc.):
1. If the session file has entries, offer: "Push breadcrumbs to MCP before we wrap up?"
2. On yes → push (same flow as "push breadcrumbs" above)
3. On no → the file stays in workspace/ for next session's start gate
```

- [ ] **Step 3: Apply the edit to CLAUDE.md**

Use the Edit tool to append the full breadcrumb section after the Working Directory block.

- [ ] **Step 4: Verify the edit**

Read the updated CLAUDE.md and confirm:
- The breadcrumb section is present and complete
- No existing content was modified or lost
- The section appears after the Working Directory tree

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md
git commit -m "feat: add session breadcrumbs behavior to CLAUDE.md

Adds ambient breadcrumb capture that persists key conversation moments
(state changes, commitments, escalations) to workspace/ session files.
Includes privacy gate, session start resolution, and MCP push flow.

Based on Staff Engineer Panel recommendation — append-only log,
secrets-only privacy scanning, gate-don't-nag pattern."
```

---

### Task 2: Ensure workspace/ Directory Exists and Is Gitignored

**Files:**
- Verify: `.gitignore`
- Verify: `workspace/` directory

- [ ] **Step 1: Check .gitignore for workspace/**

```bash
grep -n "workspace" .gitignore
```

Confirm `workspace/` is gitignored. If not, add it.

- [ ] **Step 2: Ensure workspace/ directory exists**

```bash
ls -la workspace/
```

If missing, create it with a `.gitkeep`:

```bash
mkdir -p workspace && touch workspace/.gitkeep
```

- [ ] **Step 3: Commit if any changes were needed**

```bash
git add .gitignore workspace/.gitkeep
git commit -m "chore: ensure workspace/ exists and is gitignored"
```

---

### Task 3: Update PM Docs

**Files:**
- Modify: `docs/pm/CURRENT-SPRINT.md`

- [ ] **Step 1: Update sprint items to reflect completed work**

Mark items 1 (staff panel) and 2 (implementation plan) as done. Mark item 3 as "replaced — no skill needed, CLAUDE.md only". Mark item 4 as the active item. Update status.

- [ ] **Step 2: Commit PM update**

```bash
git add docs/pm/CURRENT-SPRINT.md
git commit -m "docs: update sprint status — breadcrumbs plan complete"
```

---

### Task 4: Save Staff Panel Analysis to MCP

- [ ] **Step 1: Push the staff panel document to weeklyops-data**

Call `save_document(category="notes", title="Session Breadcrumbs — Staff Engineer Panel Analysis", content=<full panel output>)`.

- [ ] **Step 2: Confirm save succeeded**

Verify the MCP response confirms the document was saved.
