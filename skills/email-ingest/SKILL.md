# /email-ingest — Process Email Scan Output

Accept the output file from `/email-scan` (or any structured email data), cross-reference with active OKRs, produce a categorized summary, and save it to weeklyops-data.

## Trigger

User invokes `/email-ingest [file-path]` or `/email-ingest` (will prompt for file).

## Arguments

| Argument | Description | Default |
|----------|-------------|---------|
| `[file-path]` | Path to the email scan output file | Prompt for it |

## Instructions

### Step 1: Resolve Identity and Input

1. Read `config.yaml` for user name
2. If no file path provided, ask: "Where is your email scan output? (paste a file path)"
3. Read the file — accept markdown or JSON format

### Step 2: Parse Email Data

Parse the input file into structured threads. Expected format (from `/email-scan`):

```markdown
## {N}. {Category Name}

### {Na}. {Thread Subject}
- **People:** {names}
- **Dates active:** {range}
- **Summary:** {what happened}
- **Status:** {status}
- **Action items:** {items}
```

If the file is JSON, adapt parsing accordingly. Extract:
- Thread subject and category
- People involved
- Status (Resolved, Unresolved, Waiting, FYI)
- Action items with owners

### Step 3: Cross-Reference with OKRs

Call `mcp__weeklyops__get_person_status` for the current user to get their active KRs.

For each email thread, check if it relates to any active KR:
- Look for topic overlap (e.g., "billing" thread → billing-related KRs)
- Look for mentioned people who own KRs
- Look for action items that advance a KR

Tag threads with relevant KR IDs where applicable. Don't force connections — only tag when there's a real relationship.

### Step 4: Produce Summary

Generate a structured email summary with these sections:

```markdown
# Email Summary — {user_name} — {date_range}

## Overview
- **Period:** {date_from} to {date_to}
- **Threads analyzed:** {count}
- **Action items found:** {count}
- **OKR-relevant threads:** {count}

## OKR-Relevant Activity

| Thread | KR | Impact |
|--------|-----|--------|
| {subject} | {kr_id} | {how it relates} |

## By Category

### 1. Client Escalations
{threads in this category with summaries}

### 2. Internal Operations
{threads}

### 3. Strategic / Planning
{threads}

... (remaining categories with content)

## Action Items

| # | Action | Owner | Source Thread | Due |
|---|--------|-------|-------------|-----|
| 1 | {action} | {person} | {thread subject} | {date if known} |

## Threads Requiring Follow-Up

{List of Unresolved and Waiting threads with next steps}
```

### Step 5: Preview and Save

1. Show the user the full summary
2. Ask: "Save to weeklyops-data as **email-summaries**: *Email Summary {date_range}*?"
3. On confirmation, call `mcp__weeklyops__save_document` with:
   - `category`: "email-summaries"
   - `title`: "Email Summary {date_range}"
   - `content`: the full summary markdown

### Notes

- The date range is extracted from the input file content (look for date patterns)
- If the input doesn't match the expected format, do best-effort parsing and warn about anything skipped
- Action items should be concrete and actionable, not vague ("follow up" needs a specific next step)
- OKR cross-referencing adds value but should not slow down the process — a quick scan is fine
