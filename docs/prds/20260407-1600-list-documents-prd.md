# PRD: list_documents MCP Tool

**Version:** 1.0
**Status:** Draft
**Date:** 2026-04-07
**System:** WeeklyOps MCP Server
**Effort Estimate:** Small (< 1 day)
**Author:** CXSM Admin

---

## 1. Overview

### Problem Statement
The WeeklyOps MCP server has no way to browse saved documents. Once `save_document` ships, documents will accumulate in `documents/` but users will have no MCP tool to find them. The CLAUDE.md references `list_documents` but it doesn't exist. Without it, the only way to find a document is to manually browse the weeklyops-data git repo.

### Business Value
- Closes the save-then-find loop: save a document today, find it next week
- Enables Claude to surface relevant prior documents during conversations ("you wrote an RFC about this last month")
- Forward-compatible with a future `get_document` tool via the `filename` field

### Context
Companion tool to `save_document` (see `20260407-1600-save-document-prd.md`). Staff Engineer Panel (2026-04-07) approved shipping both tools together. Panel specifically required the response to include a `filename` field for forward-compatibility with `get_document`.

---

## 2. Goals and Success Metrics

### Goals
- Any authenticated team member can browse saved documents with optional filters
- Results include enough metadata to identify a document without reading its full content
- Response includes `filename` for programmatic reference to specific documents

### Success Metrics (KPIs)
| Metric | Target | Measurement Method |
|--------|--------|--------------------|
| Tool exists and responds | Pass/fail | `weeklyops_help` lists `list_documents` |
| Filters work correctly | 100% | Test each filter independently and combined |
| Response includes filename field | Pass/fail | Check response format |

---

## 3. Scope

### In Scope
- `list_documents` tool with category, author, and limit filters
- Filesystem scan of `documents/` directory
- Frontmatter parsing for metadata
- Table-formatted response sorted by date descending

### Out of Scope
- `get_document` — deferred; this tool provides the `filename` needed to call it later
- Full-text search within document content — not needed at current scale
- Pagination (offset/cursor) — `limit` parameter is sufficient for team of 8
- Quarter-based filtering — documents don't have quarter in frontmatter (panel decision)

---

## 4. Target Users and Personas

| Role | Description | Primary Actions |
|------|-------------|-----------------|
| Team member | Any of the 8 CXSM team members | Browse their own or team documents by category |
| Claude (AI assistant) | Conversational front-end | Find relevant prior documents to reference in conversation |

---

## 5. User Problems and Opportunities

- After saving documents, users need to find them again without leaving the conversation
- Claude needs to check if a relevant RFC or meeting note already exists before suggesting a new one
- Team members want to see "what did I save last week?" or "show me all email summaries"

---

## 6. User Stories

- [ ] US-001: As a team member, I want to list my recent documents so I can find something I saved earlier
- [ ] US-002: As a team member, I want to filter by category so I can find all RFCs or all email summaries
- [ ] US-003: As a team member, I want to filter by author so I can see what a specific colleague has written
- [ ] US-004: As Claude, I want to check for existing documents before saving a duplicate

---

## 7. Feature Requirements

### F-001: list_documents Tool Registration
**Purpose:** Expose list_documents as an MCP tool callable by any connected client
**Actors:** MCP client (Claude Code, Claude Desktop)
**Behavior:**
- Tool is registered with the MCP server and appears in `weeklyops_help` output
- Tool description: "Browse saved documents with optional filters. Returns metadata (not full content)."

### F-002: Parameter Handling
**Purpose:** Accept optional filters for narrowing results
**Actors:** MCP server
**Behavior:**
- `category` (optional, string): Filter to a single category. If provided, must be a valid category enum value
- `author` (optional, string): Filter by author name. Case-insensitive matching (e.g., "chris" matches "Chris")
- `limit` (optional, int): Maximum number of results to return. Default: 20. Max: 100.

**Validation Rules:**
- If `category` is provided and invalid, return error: `"Invalid category '{value}'. Must be one of: rfcs, solutions, email-summaries, context-updates, reports, notes, feature-requests"`
- If `limit` is < 1 or > 100, clamp to range [1, 100]
- All parameters are optional — no parameters returns the 20 most recent documents across all categories and authors

### F-003: Document Discovery
**Purpose:** Find all documents matching the filters
**Actors:** MCP server (internal)
**Behavior:**
- Scan `documents/` directory recursively
- For each `.md` file found, parse YAML frontmatter to extract: title, author, date, category
- Apply filters (category match, case-insensitive author match)
- Sort by date descending (newest first)
- Truncate to `limit`

**Edge cases:**
- If `documents/` directory doesn't exist, return empty result with message: `"No documents found. Use save_document to create one."`
- If a file has malformed frontmatter, skip it (don't error on the entire request)
- If no documents match filters, return: `"No documents found matching filters."`

### F-004: Response Format
**Purpose:** Return a scannable table of document metadata
**Actors:** MCP server → MCP client
**Behavior:**
- Return a markdown table with columns: Date, Title, Category, Author, Filename

**Response format:**
```
## Documents (showing {N} of {total})

| Date | Title | Category | Author | Filename |
|------|-------|----------|--------|----------|
| 2026-04-07 | Weekly Report W15 | reports | Chris | 20260407-1200-weekly-report-w15.md |
| 2026-04-06 | Daily Notes Apr 6 | notes | Chris | 20260406-1600-daily-notes-apr-6-2026.md |
```

- `Filename` is the basename only (not the full path), sufficient to pass to a future `get_document(filename)` tool
- `Date` is formatted as YYYY-MM-DD (extracted from frontmatter, not filename)
- If `total` > `limit`, the header indicates truncation: "showing 20 of 47"

---

## 8. Data Model and Business Objects

### Input: Document Frontmatter (read-only)
| Field | Type | Source | Used For |
|-------|------|--------|----------|
| title | string | Frontmatter | Display in table |
| author | string | Frontmatter | Author filter + display |
| date | ISO 8601 datetime | Frontmatter | Sort key + display |
| category | string | Frontmatter (or directory name) | Category filter + display |

### Output: Document List Entry
| Field | Type | Description |
|-------|------|-------------|
| date | YYYY-MM-DD | Document date |
| title | string | Document title |
| category | string | Document category |
| author | string | Document author |
| filename | string | Basename of the file (for future get_document) |

---

## 9. API / Integration Requirements

### MCP Tool Interface

#### list_documents
- **Purpose:** Browse saved documents with optional filters
- **Auth:** API key → identity (any authenticated member)
- **Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| category | string (enum) | No | all | Filter by category |
| author | string | No | all | Filter by author (case-insensitive) |
| limit | int | No | 20 | Max results (1-100) |

- **Response (success):** `{"result": "## Documents (showing N of M)\n\n| Date | Title | ... |"}`
- **Response (empty):** `{"result": "No documents found matching filters."}`
- **Response (error):** `{"error": "Invalid category 'foo'. Must be one of: ..."}`

---

## 10. UI / UX Requirements

N/A — Server-side MCP tool. Response formatting (markdown table) is designed to render well in both Claude Code terminal and Claude Desktop.

---

## 11. Non-Functional Requirements

### Performance
- List operation should complete in < 3 seconds for up to 1000 documents
- Frontmatter parsing should be lazy — read only the YAML header, not the full file content

### Security
- Any authenticated member can list all documents (no author-scoping restriction)
- No document content is returned — only metadata

### Reliability
- Malformed files are skipped with a warning, not treated as fatal errors
- Missing `documents/` directory returns empty result, not error

### Scalability
- Filesystem scan is acceptable for ~1000 documents (team of 8, ~1 year of use)
- If scale becomes a concern (unlikely), add an index file as a future enhancement

---

## 12. Dependencies

- `save_document` tool (creates the documents that this tool lists)
- weeklyops-data git repo (where documents are stored)
- Existing auth/identity system (for author matching)

---

## 13. Risks and Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| Slow scan if document count grows large | LOW | Limit parameter caps response size; filesystem scan is fast for <1000 files |
| Frontmatter format inconsistency | LOW | Skip malformed files; save_document enforces consistent frontmatter |
| Category enum drift between save and list | LOW | Both tools share the same enum constant; update in one place |

---

## 14. Acceptance Criteria

- [ ] AC-001: Calling `list_documents()` with no parameters returns up to 20 documents sorted by date descending
- [ ] AC-002: Calling `list_documents(category="notes")` returns only documents in the notes category
- [ ] AC-003: Calling `list_documents(author="chris")` returns documents by Chris (case-insensitive match)
- [ ] AC-004: Calling `list_documents(category="notes", author="Chris", limit=5)` applies all filters correctly
- [ ] AC-005: Response includes a `Filename` column with the file basename
- [ ] AC-006: Calling with `category="invalid"` returns an error listing valid categories
- [ ] AC-007: If no documents exist, returns a friendly "No documents found" message
- [ ] AC-008: Malformed files in the documents directory are skipped without causing an error
- [ ] AC-009: Tool appears in `weeklyops_help` output under "Status & Info Tools" (or appropriate section)
- [ ] AC-010: Response header shows "showing N of M" when results are truncated by limit

---

## 15. Release Plan and Rollout Notes

- **Target:** Ship alongside `save_document` — both tools together
- **Rollout:** All users at once (team of 8)
- **Rollback:** Remove tool registration; documents remain in git
- **Post-ship:** Test with real documents created by save_document

---

## 16. Future Enhancements

- `get_document(filename)` — retrieve full document content using the filename from list_documents response
- Full-text search across document content
- Pagination with offset/cursor (if document volume warrants it)
- Tag-based filtering (if `save_document` adds tags parameter in future)

---

## Appendix

### A. Staff Engineer Panel Reference
Panel convened 2026-04-07. Key decisions:
- **APPROVED (4-0, confidence 5.0):** Ship list_documents
- **APPROVED (3-1, confidence 3.5):** Include filename in response for forward-compatibility (Tim dissented: unnecessary)
- No quarter filter (documents don't have quarter in frontmatter)
- Filesystem scan is appropriate at current scale — no index needed

### B. Existing Tool Patterns
- `get_checkins(week)` — returns formatted checkin data for a week
- `get_retro(week)` — returns retro data for a week
- `list_documents` follows the same read pattern but with more flexible filtering

### C. Related PRDs
- `20260407-1600-save-document-prd.md` — save documents (companion tool, must ship together)

### D. Open Questions
- Should list_documents also show the file size or word count? (Likely no — keep it simple)
- Should the response include the category subdirectory in the filename, or just the basename? Recommendation: basename only, since category is already a separate column and `get_document` can search across categories by filename
