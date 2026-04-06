# /prompt-feature-assess — Surface Platform Enhancement Ideas

Review the current conversation for patterns that suggest WeeklyOps MCP platform gaps, draft enhancement proposals with user consent, and save them to weeklyops-data for developers.

## Trigger

User invokes `/prompt-feature-assess` at any point during or after a skill session.

## Instructions

### Step 1: Gather Signals

Two sources of signal, used together:

**A. Ask the user directly:**

> "Anything in this session feel like it should have been easier? Any tool you wished existed, or any step that felt like unnecessary manual work?"

Wait for their response. This is the highest-signal input.

**B. Scan the conversation for anti-patterns:**

Check the current conversation for these 5 codified patterns:

| Pattern | Signal | Example |
|---------|--------|---------|
| **Multi-step workaround** | 3+ MCP tool calls to achieve one logical result | Called get_person_status, then get_team_status, then compile_shoutouts to build a comparison |
| **Manual copy-paste between tools** | User pasted output from one tool as input to another | Copied KR data from get_person_status into a document manually |
| **Manual reformatting** | User asked Claude to reformat MCP output | "Can you turn that into a table?" after getting raw tool output |
| **Explicit friction language** | "I wish", "there should be a way to", "no way to", "can't we just" | User expressed frustration about a missing capability |
| **Repeated identical calls** | Same tool called 3+ times with slight parameter variations | Called get_person_status for each team member one by one |

If any patterns are detected, note them. If none found and user had no complaints, report: "No platform gaps identified this session." and stop.

### Step 2: Draft Proposals

For each signal (user-reported or detected), draft a feature request. Maximum 3 proposals per session.

**Use this format for each proposal:**

```markdown
# {Descriptive Title}

**Status:** pending
**Frequency:** {one-off | recurring | systemic}
**Source Skill:** {skill that was running, e.g., /weekly-update, or "freeform" if no skill}
**Affected Tools:** {comma-separated MCP tools involved}

---

## Problem

{2-3 sentences describing the PATTERN, not the specific conversation content.}

## Proposed Solution

{2-3 sentences describing what the tool or change would look like.}

## Effort Hint

{small | medium | large} — {one-line rationale}
```

### Step 3: Privacy Check

Before presenting to the user, verify each proposal follows these rules:

**NEVER include:**
- Conversation text or quotes
- File contents or data values
- Client names, company names, or deal specifics
- People's names (other than the submitter)
- Specific KR values or OKR details

**ALWAYS describe:**
- The pattern, not the instance
- The gap, not the workaround content
- The capability needed, not what was discussed

**Good example:**
> "When analyzing weekly email data, there is no tool to batch-query multiple team members' KR status in a single call. Each person requires a separate get_person_status invocation."

**Bad example:**
> "When reviewing the RealtyMark cancellation emails, I needed to check Chris's AM KRs but had to call get_person_status separately for Chris, Mary-Margaret, and Avery to compare their retention metrics."

### Step 4: User Approval

Present each proposal individually:

> **Feature Request #{N}: {Title}**
>
> {Show the full formatted proposal}
>
> Submit this to the platform team? (yes / no / edit)

- **yes** → save via MCP
- **no** → skip, move to next
- **edit** → user provides changes, re-present

No submission without explicit "yes" per proposal.

### Step 5: Save Approved Proposals

For each approved proposal, call:

```
mcp__weeklyops__save_document(
  category="feature-requests",
  title="{proposal title}",
  content="{full formatted proposal}"
)
```

Report the saved path and URL for each.

### Step 6: Summary

After all proposals are processed:

> **Feature assessment complete.**
> - Submitted: {N} proposals
> - Skipped: {N}
>
> Developers can review these with `/feature-get` in the weeklyops repo.

## Notes

- This skill can be invoked after any other skill or freeform conversation
- Frequency signal helps developers prioritize: "systemic" means it affects multiple skills/sessions
- The effort hint is the submitter's guess — developers will refine it
- Feature requests are visible to the whole team via list_documents
