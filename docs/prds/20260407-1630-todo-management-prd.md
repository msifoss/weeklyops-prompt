# PRD: TODO Management MCP Tools

**Version:** 1.0
**Status:** Draft
**Date:** 2026-04-07
**System:** WeeklyOps MCP Server
**Effort Estimate:** Small-Medium (1-2 days)
**Author:** CXSM Admin

---

## 1. Overview

### Problem Statement
The WeeklyOps MCP server has no task/todo tracking. Team members produce action items constantly — from meetings, email reviews, weekly updates, and conversations — but there's no way to capture, track, or review them through MCP. Action items get buried in check-ins, meeting notes, and chat history. There's no single view of "what do I need to do?"

Today's example: Chris needs to "Update the Lakey tables to be current" — this came up in conversation but has nowhere to land except a check-in message where it'll be lost by next week.

### Business Value
- Captures action items at the moment they're identified, in the flow of conversation
- Gives each team member a single "what's on my plate" view
- Feeds into weekly updates and retros — `/weekly-update` can pull open/completed todos
- Connects to KRs — some todos directly advance specific Key Results
- Reduces dropped balls across the team

### Context
The WeeklyOps system already tracks structured weekly cadence data (check-ins, retros, shoutouts, agenda items) and OKR progress (KR values). TODOs fill the gap between "big picture KRs" and "daily work." They're the granular action items that roll up into KR progress.

This is a natural companion to `save_document` (capturing knowledge) and the weekly cadence tools (capturing rhythm). TODOs capture commitments.

---

## 2. Goals and Success Metrics

### Goals
- Any team member can add a todo for themselves or others via MCP
- Any team member can view their own open todos
- Admins can view any team member's todos
- TODOs can optionally link to a KR for traceability
- TODOs have a simple lifecycle: open → done (or → cancelled)

### Success Metrics (KPIs)
| Metric | Target | Measurement Method |
|--------|--------|--------------------|
| Tools exist and respond | Pass/fail | `weeklyops_help` lists todo tools |
| Team members use todos weekly | >50% of team | Count of todo authors per week |
| `/weekly-update` incorporates todos | Pass/fail | Skill references todo data |

---

## 3. Scope

### In Scope
- `add_todo` — create a todo for self or another team member
- `list_todos` — view todos with filters (owner, status, week)
- `complete_todo` — mark a todo as done
- Optional KR linkage on todos
- Due date support (optional)

### Out of Scope
- Priority levels — keep it simple; if everything is priority, nothing is
- Subtasks / nested todos — use separate todos
- Assignments requiring approval — if Chris adds a todo for Isaac, it just appears
- Recurring todos — create them manually each week
- Due date reminders / notifications — the server doesn't push notifications
- Kanban / board views — this is a list, not a project management tool

---

## 4. Target Users and Personas

| Role | Description | Primary Actions |
|------|-------------|-----------------|
| Team member | Any of the 8 CXSM team members | Add todos for self, view own todos, mark complete |
| Admin | Chris (admin role) | Add todos for anyone, view anyone's todos |
| Claude (AI assistant) | Conversational front-end | Extract action items from conversation and add as todos |

---

## 5. User Problems and Opportunities

- Action items from meetings (e.g., "Review CXSM JD, flag changes to Todd") have no structured home
- `/weekly-update` can't show "what I committed to vs. what I completed" without todo data
- Team members can't quickly check "what did I say I'd do this week?"
- Cross-team assignments (Chris assigns something to Isaac) rely on memory or Slack messages

---

## 6. User Stories

- [ ] US-001: As a team member, I want to add a todo for myself so I can track action items from conversations and meetings
- [ ] US-002: As an admin, I want to add a todo for another team member so I can delegate action items from leadership meetings
- [ ] US-003: As a team member, I want to list my open todos so I know what I need to do
- [ ] US-004: As a team member, I want to mark a todo as complete so I can track my progress
- [ ] US-005: As a team member, I want to link a todo to a KR so I can see which tasks advance which objectives
- [ ] US-006: As Claude running `/weekly-update`, I want to pull a user's todos for the week so the report shows commitments vs. completions

---

## 7. Feature Requirements

### F-001: add_todo Tool Registration
**Purpose:** Expose add_todo as an MCP tool
**Actors:** MCP client (Claude Code, Claude Desktop)
**Behavior:**
- Tool is registered and appears in `weeklyops_help`
- Tool description: "Add a todo item for yourself or a team member. Optionally link to a KR."

### F-002: add_todo Parameters and Validation
**Purpose:** Create a well-formed todo
**Actors:** MCP server
**Behavior:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| description | string | Yes | — | What needs to be done (max 500 chars) |
| owner | string | No | authenticated user | Team member who owns this todo (case-insensitive) |
| kr_id | string | No | — | Optional KR link like "infra-1.3" |
| due_date | string | No | — | Optional due date, ISO format YYYY-MM-DD |
| week | string | No | current week | ISO week like "2026-W15" for organizing |

**Validation Rules:**
- `description` must be non-empty, max 500 characters
- `owner` must be a valid team member name (same validation as `get_person_status`)
- If `owner` differs from authenticated user AND user is not admin, create a suggestion instead of direct todo (follows existing permission pattern from `update_kr`)
- `kr_id` if provided must be a valid KR ID format (but server doesn't need to validate it exists — soft link)
- `due_date` if provided must be valid ISO date

### F-003: Todo Storage
**Purpose:** Persist todos as structured data in weeklyops-data
**Actors:** MCP server (internal)
**Behavior:**
- Each todo gets a unique ID: `TODO-{NNN}` (sequential, zero-padded to 3 digits)
- Stored in `todos/{owner}/todos.yaml` (append to existing file or create new)
- YAML structure per todo:

```yaml
- id: TODO-001
  description: "Update the Lakey tables to be current"
  owner: Chris
  created_by: Chris
  created_date: "2026-04-07T16:30:00Z"
  due_date: null
  kr_id: null
  week: "2026-W15"
  status: open
  completed_date: null
```

- Git committed with message: `todo(add): {description} [{owner}]`

**Alternative approach — single file per week:**
Store at `todos/{week}/{owner}.yaml`. This naturally groups todos by week and makes weekly queries fast. Recommended over per-owner files since the primary access pattern is "what are my todos this week?"

### F-004: add_todo Response
**Purpose:** Confirm creation with reference ID
**Actors:** MCP server → MCP client
**Behavior:**
- Return: `"Todo added: TODO-{NNN} — {description} [owner: {owner}]"`
- If KR linked: `"Todo added: TODO-{NNN} — {description} [owner: {owner}, KR: {kr_id}]"`

### F-005: list_todos Tool Registration and Parameters
**Purpose:** Browse todos with filters
**Actors:** MCP client

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| owner | string | No | authenticated user | Filter by owner (case-insensitive) |
| status | string | No | "open" | Filter: "open", "done", "cancelled", "all" |
| week | string | No | current week | Filter by week |
| kr_id | string | No | — | Filter by linked KR |

**Behavior:**
- Returns a markdown table: ID, Description, Owner, Status, Due Date, KR, Created
- Sorted by created date descending
- Default: show own open todos for current week
- Admins can list any owner's todos; members can only list their own

**Response format:**
```
## Todos for {owner} — {week} ({N} open, {M} done)

| ID | Description | Status | Due | KR | Created |
|----|-------------|--------|-----|-----|---------|
| TODO-003 | Update Lakey tables to be current | open | — | infra-1.3 | 2026-04-07 |
| TODO-001 | Review CXSM JD, flag changes to Todd | open | 2026-04-07 | — | 2026-04-06 |
```

### F-006: complete_todo Tool
**Purpose:** Mark a todo as done
**Actors:** MCP client

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| todo_id | string | Yes | — | Todo ID like "TODO-001" |
| note | string | No | — | Optional completion note |

**Behavior:**
- Set `status: done` and `completed_date` to now
- Only the todo owner or an admin can complete a todo
- Git committed with message: `todo(done): {todo_id} — {description} [{owner}]`
- Return: `"Todo completed: TODO-{NNN} — {description}"`
- If `note` provided, append to the todo entry

**Validation:**
- Todo must exist and be in `open` status
- If already done: `"Todo TODO-{NNN} is already completed"`
- If not found: `"Todo TODO-{NNN} not found"`

### F-007: cancel_todo Tool (optional — implement if low effort)
**Purpose:** Cancel a todo that's no longer relevant
**Actors:** MCP client

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| todo_id | string | Yes | — | Todo ID |
| reason | string | No | — | Why it was cancelled |

**Behavior:**
- Set `status: cancelled` and record reason
- Same permission model as complete_todo
- Git committed with message: `todo(cancel): {todo_id} — {description} [{owner}]`

---

## 8. Data Model and Business Objects

### Entities

#### Todo
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | string | Y | Unique ID: TODO-NNN |
| description | string | Y | What needs to be done |
| owner | string | Y | Team member who owns this |
| created_by | string | Y | Who created it (from auth) |
| created_date | ISO 8601 | Y | When created |
| due_date | ISO date | N | Optional deadline |
| kr_id | string | N | Optional KR link |
| week | ISO week | Y | Which week this belongs to |
| status | enum | Y | open, done, cancelled |
| completed_date | ISO 8601 | N | When completed/cancelled |
| note | string | N | Completion or cancellation note |

### File System Layout (recommended: per-week)
```
weeklyops-data/
└── todos/
    ├── 2026-W15/
    │   ├── Chris.yaml
    │   ├── Isaac.yaml
    │   └── Mary-Margaret.yaml
    └── 2026-W16/
        └── Chris.yaml
```

### ID Generation
- IDs are globally sequential across all owners and weeks
- Store a counter file at `todos/.counter` (simple integer)
- Increment on each `add_todo`, read on startup
- If counter file missing, scan all existing todos to find max ID

---

## 9. API / Integration Requirements

### MCP Tool Interfaces

#### add_todo
- **Auth:** Any authenticated member (cross-owner assignment creates suggestion for non-admins)
- **Response (success):** `{"result": "Todo added: TODO-001 — Update Lakey tables [owner: Chris]"}`
- **Response (error):** `{"error": "Unknown team member 'Bob'. Valid: Chris, Mary-Margaret, Fathima, Isaac, Avery, MD, Tyler, David"}`

#### list_todos
- **Auth:** Members see own todos; admins see any owner
- **Response (success):** `{"result": "## Todos for Chris — 2026-W15 ...\n\n| ID | Description | ..."}`
- **Response (empty):** `{"result": "No open todos for Chris in 2026-W15."}`

#### complete_todo
- **Auth:** Owner or admin
- **Response (success):** `{"result": "Todo completed: TODO-001 — Update Lakey tables"}`
- **Response (error):** `{"error": "Todo TODO-999 not found"}`

### Integration with Other Tools
- `/weekly-update` skill should call `list_todos(status="all")` to show commitments vs. completions
- `submit_checkin` could reference todo IDs in the message body
- Future: `compile_shoutouts` could auto-detect completed todos as potential shoutout material

---

## 10. UI / UX Requirements

N/A — Server-side MCP tools. Response formatting (markdown tables) renders well in Claude Code and Claude Desktop.

---

## 11. Non-Functional Requirements

### Performance
- add_todo: < 3 seconds including git commit
- list_todos: < 3 seconds for scanning a week's todos
- complete_todo: < 3 seconds including git commit

### Security
- Owner field on add_todo: members can only add for self; cross-owner creates suggestion (unless admin)
- list_todos: members restricted to own todos; admins unrestricted
- complete_todo: only owner or admin

### Reliability
- Counter file corruption: fall back to scanning existing IDs
- Concurrent adds: sequential counter increment; timestamp in created_date prevents ordering ambiguity

### Scalability
- YAML per owner per week keeps files small
- At 8 team members x 10 todos/week = 80 todos/week, ~4000/year — trivial for filesystem

---

## 12. Dependencies

- WeeklyOps MCP server codebase
- weeklyops-data git repo
- Existing auth/identity system
- Team member roster (for owner validation)

---

## 13. Risks and Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| Counter file race condition on concurrent adds | LOW | Team of 8, unlikely to add simultaneously; use file locking if needed |
| Todos accumulate without completion | MED | `/weekly-update` surfaces open todos, creating natural review pressure |
| Cross-week todos (created W15, still open W17) | MED | list_todos with `status=open` across weeks; or carry forward mechanism |
| Team members forget todo IDs for complete_todo | LOW | list_todos shows IDs; Claude can look up by description |

---

## 14. Acceptance Criteria

- [ ] AC-001: `add_todo(description="Test task")` creates a todo owned by the authenticated user with status "open"
- [ ] AC-002: `add_todo(description="Task for Isaac", owner="Isaac")` by admin creates a todo owned by Isaac
- [ ] AC-003: `add_todo(description="Task for Isaac", owner="Isaac")` by non-admin creates a suggestion, not a direct todo
- [ ] AC-004: `add_todo(description="Update tables", kr_id="infra-1.3")` creates a todo with KR link shown in response
- [ ] AC-005: `list_todos()` returns authenticated user's open todos for current week
- [ ] AC-006: `list_todos(owner="Isaac")` by admin returns Isaac's todos
- [ ] AC-007: `list_todos(owner="Isaac")` by non-admin Isaac returns Isaac's todos
- [ ] AC-008: `list_todos(status="all")` returns open, done, and cancelled todos
- [ ] AC-009: `complete_todo(todo_id="TODO-001")` sets status to done with completed_date
- [ ] AC-010: `complete_todo(todo_id="TODO-001")` on already-done todo returns appropriate error
- [ ] AC-011: Todo ID is globally unique and sequential
- [ ] AC-012: All mutations (add, complete, cancel) are git-committed
- [ ] AC-013: All three tools appear in `weeklyops_help` output
- [ ] AC-014: `list_todos(kr_id="infra-1.3")` returns only todos linked to that KR

---

## 15. Release Plan and Rollout Notes

- **Target:** Ship after save_document/list_documents (or in parallel if different developer)
- **Rollout:** All users at once
- **Rollback:** Remove tool registrations; existing todo files remain in git
- **Post-ship:** Update weeklyops-prompt CLAUDE.md to document todo tools; update `/weekly-update` skill to incorporate todo data

---

## 16. Future Enhancements

- Carry-forward: automatically copy uncompleted todos to next week
- Recurring todos: "every Monday, add TODO: submit check-in"
- Todo-to-shoutout: completing a todo linked to a KR auto-generates shoutout material
- Bulk operations: complete/cancel multiple todos at once
- `/mytodo` skill in weeklyops-prompt for a richer todo review experience

---

## Appendix

### A. Design Rationale

**Why YAML not markdown?**
Todos are structured data with fields (status, dates, IDs) that need to be queried and updated. YAML is easier to parse and modify programmatically than markdown with frontmatter. Documents use markdown because the content IS the value. Todos use YAML because the metadata IS the value.

**Why per-week files?**
The primary access pattern is "what are my todos this week?" Per-week organization makes this a single file read. Cross-week queries (all open todos regardless of week) require scanning multiple weeks but this is acceptable at scale.

**Why global sequential IDs?**
Users need to reference todos by ID for complete/cancel. Sequential IDs are predictable and easy to type. "Complete TODO-003" is better UX than "complete TODO-2026W15-Chris-003".

### B. Related PRDs
- `20260407-1600-save-document-prd.md` — document storage (ships first or in parallel)
- `20260407-1600-list-documents-prd.md` — document browsing (companion to save_document)

### C. Open Questions
- Should todos carry forward automatically to the next week if still open? Or require manual re-creation? Recommendation: start manual, add carry-forward as future enhancement based on team feedback.
- Should there be a "my day" view that shows todos across all weeks that are still open? Useful but could be a parameter on list_todos: `week="all"` with `status="open"`.
- Maximum todos per person per week? Probably not — trust the team. But worth monitoring.
