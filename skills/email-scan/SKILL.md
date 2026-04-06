# /email-scan — Generate Email Analysis Prompt

Generate a structured prompt for your email MCP (Gmail, Outlook, etc.) to extract categorized email data for a given date range.

## Trigger

User invokes `/email-scan` or `/email-scan [date-range]`.

## Arguments

| Argument | Description | Default |
|----------|-------------|---------|
| `[date-range]` | Date range like `Mar 1-7` or `2026-03-01 to 2026-03-07` | Prompt for it |

## Instructions

### Step 1: Resolve Identity and Date Range

1. Read `config.yaml` for user name
2. If no date range provided, ask: "What date range should I scan? (e.g., Mar 1-7, last week)"
3. Convert to ISO dates: `date_from` and `date_to`

### Step 2: Generate the Email Prompt

Produce a prompt the user can give to their email MCP tool. Display it clearly with instructions.

Output this to the user:

---

**Copy this prompt to your email tool (Gmail MCP, Outlook MCP, etc.):**

> Search my email from {date_from} to {date_to} (Inbox, Sent, Archive).
>
> For each email thread, extract:
> - **Subject** — the email subject line
> - **People** — all participants with their roles/companies if apparent
> - **Dates active** — first and last message dates in the thread
> - **Summary** — 2-3 sentence summary of what happened
> - **Status** — Resolved, Unresolved, Waiting on [person], or FYI
> - **Action items** — any commitments or follow-ups needed, with owner
>
> Group the threads into these categories:
> 1. **Client Escalations** — issues raised by clients or about client accounts
> 2. **Internal Operations** — team processes, tooling, systems
> 3. **Strategic / Planning** — roadmap, goals, resource allocation
> 4. **People / HR** — hiring, reviews, team management
> 5. **External / Vendor** — partner communications, contracts, vendors
> 6. **FYI / Low Priority** — newsletters, notifications, no action needed
>
> Format the output as markdown with this structure:
>
> ```
> ## {N}. {Category Name}
>
> ### {Na}. {Thread Subject}
> - **People:** {names with roles}
> - **Dates active:** {range}
> - **Summary:** {what happened}
> - **Status:** {Resolved / Unresolved / Waiting on X}
> - **Action items:** {if any, with owner}
> ```
>
> Skip threads that are purely automated notifications (calendar invites, system alerts) unless they contain human replies.

---

### Step 3: Guide Next Steps

After displaying the prompt, tell the user:

> Run this prompt in your email tool. Save the output to a file, then run:
>
> `/email-ingest path/to/output.md`
>
> That will cross-reference your emails with active OKRs and save a structured summary to the team data repo.

### Notes

- The output format matches what `/email-ingest` expects
- The categories can be customized per user — these are defaults for the CXSM team
- If the user's email MCP returns JSON instead of markdown, `/email-ingest` handles both
