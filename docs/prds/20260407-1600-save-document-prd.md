# PRD: save_document MCP Tool

**Version:** 1.0
**Status:** Draft
**Date:** 2026-04-07
**System:** WeeklyOps MCP Server
**Effort Estimate:** Small (< 1 day)
**Author:** CXSM Admin

---

## 1. Overview

### Problem Statement
The WeeklyOps MCP server has no general-purpose document storage tool. Four skills in weeklyops-prompt (`/email-ingest`, `/weekly-update`, `/prompt-feature-assess`, and freeform conversations) reference `save_document` but the tool doesn't exist on the server. Users are forced to shoehorn documents into `submit_checkin` or lose them entirely. This is a live defect — not a feature request.

### Business Value
- Unlocks the full "conversational OKR" workflow: talk → extract → save
- Enables persistent team knowledge (RFCs, meeting notes, email summaries) in a searchable, categorized store
- Eliminates data loss when conversations produce valuable artifacts

### Context
The CLAUDE.md in weeklyops-prompt defines a "Saving Convention" that routes all persistent output through `save_document`. The convention specifies 7 categories and a preview-before-save UX. The server already has analogous write tools (`submit_checkin`, `submit_retro`, `update_kr`) that store markdown files and auto-commit to git. This tool follows the same pattern.

Staff Engineer Panel (2026-04-07) unanimously approved shipping this tool with no `quarter` parameter, strict category enum validation, and a 100KB content limit.

---

## 2. Goals and Success Metrics

### Goals
- Any authenticated team member can save a categorized document via MCP
- Documents are stored as markdown with frontmatter in the weeklyops-data git repo
- Documents are auto-committed with consistent commit messages

### Success Metrics (KPIs)
| Metric | Target | Measurement Method |
|--------|--------|--------------------|
| Tool exists and responds | Pass/fail | `weeklyops_help` lists `save_document` |
| All 4 skills can save without error | 100% | Manual test of each skill's save path |
| Documents appear in git history | 100% | `git log --grep="docs("` on weeklyops-data |

---

## 3. Scope

### In Scope
- `save_document` tool with title, category, and content parameters
- Server-side slug generation from title
- Frontmatter injection (author, date, category, title)
- Auto-commit to weeklyops-data repo
- Category enum validation with helpful error messages

### Out of Scope
- `quarter` parameter — documents reference quarters in content, not metadata (panel decision)
- `tags` parameter — no existing tools use tags; deferred for consistency (panel decision)
- `update_document` / `delete_document` — documents are append-only artifacts (panel decision)
- `get_document` — deferred; spec'd separately (panel decision)
- Full-text search — not needed at current scale

---

## 4. Target Users and Personas

| Role | Description | Primary Actions |
|------|-------------|-----------------|
| Team member | Any of the 8 CXSM team members | Save meeting notes, email summaries, daily logs via Claude conversation |
| Admin | Chris (admin role) | Same as member — no elevated permissions needed for document saving |
| Claude (AI assistant) | Conversational front-end in weeklyops-prompt | Calls save_document when a conversation produces a saveable artifact |

---

## 5. User Problems and Opportunities

- Team members produce valuable artifacts in conversation (meeting notes, RFCs, email analysis) but have no way to persist them through MCP
- The `/weekly-update` skill generates reports but can't save them — the save step fails silently
- Daily notes (like the 2026-04-06 log) had to be saved as a check-in, losing category metadata

---

## 6. User Stories

- [ ] US-001: As a team member, I want to save a document with a title and category so that it's stored in the team knowledge base and committed to git
- [ ] US-002: As a team member, I want the server to validate my category so that I don't accidentally create documents in wrong categories
- [ ] US-003: As a team member using `/email-ingest`, I want the skill to save my email summary as an `email-summaries` document so that it's retrievable later
- [ ] US-004: As a team member using `/weekly-update`, I want my weekly report saved as a `reports` document automatically

---

## 7. Feature Requirements

### F-001: save_document Tool Registration
**Purpose:** Expose save_document as an MCP tool callable by any connected client
**Actors:** MCP client (Claude Code, Claude Desktop)
**Behavior:**
- Tool is registered with the MCP server and appears in `weeklyops_help` output
- Tool description: "Save a categorized document to the team knowledge base. Use for meeting notes, RFCs, email summaries, reports, and other artifacts worth keeping."

### F-002: Parameter Validation
**Purpose:** Ensure all documents are well-formed before saving
**Actors:** MCP server
**Behavior:**
- `title` (required, string): Must be non-empty, max 200 characters
- `category` (required, string): Must be one of: `rfcs`, `solutions`, `email-summaries`, `context-updates`, `reports`, `notes`, `feature-requests`
- `content` (required, string): Must be non-empty, max 100KB (102,400 bytes)

**Validation Rules:**
- If `category` is invalid, return error: `"Invalid category '{value}'. Must be one of: rfcs, solutions, email-summaries, context-updates, reports, notes, feature-requests"`
- If `title` is empty, return error: `"Title is required"`
- If `content` exceeds 100KB, return error: `"Content exceeds maximum size of 100KB"`

### F-003: Slug Generation
**Purpose:** Create filesystem-safe filenames from document titles
**Actors:** MCP server (internal)
**Behavior:**
- Convert title to lowercase
- Replace spaces and non-alphanumeric characters (except hyphens) with hyphens
- Collapse consecutive hyphens into one
- Strip leading/trailing hyphens
- Truncate to 60 characters at a word boundary (don't cut mid-word)
- If slug is empty after processing, use `"untitled"`

**Examples:**
| Title | Slug |
|-------|------|
| "Daily Notes — Apr 6, 2026" | `daily-notes-apr-6-2026` |
| "Jen's Q2/Q3 Migration Plan (Draft #2)" | `jen-s-q2-q3-migration-plan-draft-2` |
| "RFC: WeeklyOps Document Storage" | `rfc-weeklyops-document-storage` |
| "" (empty after stripping) | `untitled` |

### F-004: File Storage
**Purpose:** Persist document as markdown with frontmatter in weeklyops-data
**Actors:** MCP server
**Behavior:**
- Generate timestamp: `YYYYMMDD-HHMM` in server's timezone (UTC recommended)
- Create directory if needed: `documents/{category}/`
- Write file at: `documents/{category}/{YYYYMMDD-HHMM}-{slug}.md`
- File content format:

```markdown
---
title: "{title}"
author: "{author from auth}"
date: "YYYY-MM-DDTHH:MM:SSZ"
category: "{category}"
---

{content}
```

### F-005: Git Commit
**Purpose:** Auto-commit the document to the weeklyops-data repo
**Actors:** MCP server
**Behavior:**
- Stage the new file
- Commit with message: `docs({category}): {title} [{author}]`
- Follow same commit pattern as `submit_checkin` and `submit_retro`

### F-006: Response
**Purpose:** Confirm save and provide file reference
**Actors:** MCP server → MCP client
**Behavior:**
- Return: `"Document saved: documents/{category}/{filename}"`
- Include full filename so it can be passed to a future `get_document` tool

---

## 8. Data Model and Business Objects

### Entities

#### Document (stored as markdown file)
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| title | string | Y | Document title, stored in frontmatter |
| author | string | Y | Auto-populated from API key auth identity |
| date | ISO 8601 datetime | Y | Auto-populated at save time |
| category | enum string | Y | One of the 7 predefined categories |
| content | markdown string | Y | Document body, below frontmatter |

### File System Layout
```
weeklyops-data/
└── documents/
    ├── rfcs/
    │   └── 20260407-1600-weeklyops-document-storage.md
    ├── solutions/
    ├── email-summaries/
    ├── context-updates/
    ├── reports/
    │   └── 20260407-1200-weekly-report-w15.md
    ├── notes/
    │   └── 20260406-1600-daily-notes-apr-6-2026.md
    └── feature-requests/
```

---

## 9. API / Integration Requirements

### MCP Tool Interface

#### save_document
- **Purpose:** Save a categorized document
- **Auth:** API key → identity (any authenticated member)
- **Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| title | string | Yes | — | Document title (max 200 chars) |
| category | string (enum) | Yes | — | rfcs, solutions, email-summaries, context-updates, reports, notes, feature-requests |
| content | string | Yes | — | Markdown content (max 100KB) |

- **Response (success):** `{"result": "Document saved: documents/{category}/{filename}"}`
- **Response (error):** `{"error": "Invalid category 'foo'. Must be one of: rfcs, solutions, email-summaries, context-updates, reports, notes, feature-requests"}`

---

## 10. UI / UX Requirements

N/A — This is a server-side MCP tool. Client-side UX (preview before saving) is handled by the CLAUDE.md instructions in weeklyops-prompt, not by the server.

---

## 11. Non-Functional Requirements

### Performance
- Save operation should complete in < 5 seconds including git commit

### Security
- Author is derived from API key authentication, never from client input
- No admin restriction — any authenticated member can save

### Reliability
- If git commit fails, return error (don't silently succeed)
- Concurrent saves to different files should not conflict (different filenames due to timestamps)

### Scalability
- Filesystem scan is acceptable for team of 8 producing ~500-1000 documents/year
- No index file or database needed at this scale

---

## 12. Dependencies

- WeeklyOps MCP server codebase (wherever tools like `submit_checkin` are implemented)
- weeklyops-data git repo (where files are stored)
- Existing auth/identity system (API key → name + role mapping)

---

## 13. Risks and Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| Timestamp collision (two saves in same minute with same slug) | LOW | HHMM granularity + unique slugs make this extremely unlikely for team of 8 |
| Content too large bloats git repo | LOW | 100KB limit per document; warn in error message |
| Category list needs to change | LOW | Update server enum + CLAUDE.md together; fixed list is intentional |

---

## 14. Acceptance Criteria

- [ ] AC-001: Calling `save_document(title="Test Note", category="notes", content="Hello world")` creates a file at `documents/notes/{timestamp}-test-note.md` with correct frontmatter
- [ ] AC-002: The file is git-committed with message `docs(notes): Test Note [Chris]`
- [ ] AC-003: Tool returns confirmation string containing the file path
- [ ] AC-004: Calling with `category="invalid"` returns an error listing valid categories
- [ ] AC-005: Calling with empty title returns an error
- [ ] AC-006: Calling with content > 100KB returns a size error
- [ ] AC-007: Tool appears in `weeklyops_help` output under "Write Tools"
- [ ] AC-008: Author in frontmatter matches the authenticated user identity, not client-supplied data
- [ ] AC-009: Title with special characters (apostrophes, slashes, parens) produces a clean slug without filesystem errors
- [ ] AC-010: `/email-ingest` skill can call save_document with category="email-summaries" and succeed
- [ ] AC-011: `/weekly-update` skill can call save_document with category="reports" and succeed

---

## 15. Release Plan and Rollout Notes

- **Target:** Immediate — this unblocks existing skills
- **Rollout:** Ship to all users at once (team of 8, no phasing needed)
- **Rollback:** Remove tool registration; documents already saved remain in git
- **Post-ship:** Update weeklyops-prompt CLAUDE.md to remove the "planned" caveat if any

---

## 16. Future Enhancements

- `get_document(filename)` — retrieve full document content by filename (deferred per panel; list_documents designed for forward-compatibility)
- `tags` parameter for cross-referencing (deferred per panel; no existing tools use tags)
- `update_document` / `delete_document` — only if compliance requires; documents are currently append-only

---

## Appendix

### A. Staff Engineer Panel Reference
Panel convened 2026-04-07. Key decisions:
- **APPROVED (4-0, confidence 5.0):** Ship save_document
- **APPROVED (3-1, confidence 3.3):** Drop quarter parameter (Al dissented: useful for filtering)
- **APPROVED (4-0, confidence 4.5):** Fixed category enum with validation
- Slug spec explicitly defined per Rob's recommendation
- Content size limit of 100KB per Rob's recommendation

### B. Existing Tool Patterns
- `submit_checkin(message, week)` → stores at `weekly/{week}/checkins/{author}.md`, commits, returns confirmation
- `submit_retro(went_well, didnt_go_well, action_items, week)` → stores at `weekly/{week}/retros/{author}.md`
- `save_document` follows the same pattern: validate → write file → commit → confirm

### C. Related PRDs
- `20260407-1600-list-documents-prd.md` — browse documents (companion tool)

### D. Open Questions
- Server timezone for YYYYMMDD-HHMM: recommend UTC for consistency across team members in different timezones
- Should `documents/` directory be pre-created in weeklyops-data, or created on first save?
