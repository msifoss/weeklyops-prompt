# Getting Started with weeklyops-prompt

This guide walks you through setting up your conversational workspace for WeeklyOps. After setup, you'll be able to analyze emails, write weekly reviews, and interact with your team's OKR data — all from the terminal.

## What You Need

1. **Claude Code** — the CLI tool from Anthropic. Install it from [claude.ai/code](https://claude.ai/code).
2. **Your API key** — a personal Bearer token for the WeeklyOps MCP server. Ask Chris for yours.
3. **Node.js 18+** — used by the `mcp-remote` proxy to connect to the MCP server. Install via `brew install node` on Mac.

## Setup (2 minutes)

### Step 1: Clone the repo

```bash
git clone https://github.com/msifoss/weeklyops-prompt.git
cd weeklyops-prompt
```

### Step 2: Run setup

```bash
make setup
```

Setup is interactive. It will:

1. **Ask your name** — pick from the team roster (Chris, Mary-Margaret, Fathima, Isaac, Avery, MD, Tyler, David)
2. **Ask for your API key** — paste the token Chris gave you
3. **Generate your config files** — creates `.env` and `.mcp.json` (these are gitignored, your key stays local)
4. **Run health checks** — verifies your MCP connection works

If all 6 checks pass, you're ready.

### Step 3: Open Claude Code

```bash
claude
```

That's it. You're in. Claude knows who you are, has access to the WeeklyOps MCP server, and will route any documents you create to the shared data repo.

## What You Can Do

### Talk naturally

You don't need to use skills for everything. Just have a conversation:

- "Show me my OKR status" — Claude calls `get_person_status`
- "What shoutouts were posted this week?" — Claude calls `compile_shoutouts`
- "Help me draft an RFC about the new billing process" — Claude guides you through it and saves via `save_document`

Claude is instructed to route all persistent output through the MCP server. You'll always see a preview and confirmation before anything is saved.

### Use skills for guided workflows

Skills are structured workflows for common tasks. Type the slash command to start:

#### `/email-scan`

Generates a prompt you can give to your email tool (Gmail MCP, Outlook MCP, etc.) to extract structured email data for a date range.

```
/email-scan Mar 1-7
```

The output is a prompt you copy to your email tool. When your email tool produces results, feed them into `/email-ingest`.

#### `/email-ingest [file]`

Takes the output from your email scan, cross-references it with your active OKRs, and produces a categorized summary with action items.

```
/email-ingest workspace/email-output.md
```

The summary is saved to the shared data repo under `email-summaries`.

#### `/weekly-update [date-range]`

Produces an OKR-disciplined weekly self-review. It pulls your KR data, analyzes your email/calendar inputs, cross-references everything, and generates a structured summary.

```
/weekly-update 20260329-0404
```

**Data flow:**
1. Working files (email data, calendar data) go in `workspace/{date-range}/data/` — these stay local
2. The final summary is saved to weeklyops-data via `save_document(category="reports")`

#### `/prompt-feature-assess`

Run this after any session to surface ideas for improving the WeeklyOps platform. It reviews your conversation for friction points and drafts enhancement proposals — with your approval before anything is submitted.

```
/prompt-feature-assess
```

## How It Works

### Where does my data go?

| Type | Where | Visible to team? |
|------|-------|-------------------|
| Working files (drafts, raw data) | `workspace/` folder (local) | No |
| Final documents (reports, summaries, RFCs) | `weeklyops-data` repo (via MCP) | Yes |
| Your API key and config | `.env` and `.mcp.json` (local, gitignored) | No |

### The save pattern

When Claude produces something worth saving, you'll see:

> Save to weeklyops-data as **reports**: *Weekly Self-Review Chris Mar 29 - Apr 4*?

Say yes, and it's saved. Say no, and it stays in the conversation only.

### MCP tools available

Claude has access to all WeeklyOps MCP tools. The most useful ones:

| Tool | What it does |
|------|-------------|
| `get_person_status` | Your KR status with pace (on-track/watch/behind) |
| `get_team_status` | Full team KR overview |
| `save_document` | Save a document to the shared repo |
| `list_documents` | Browse saved documents |
| `compile_shoutouts` | See this week's shoutouts |
| `submit_checkin` | Submit a mid-week check-in |
| `submit_retro` | Submit a Friday retro entry |
| `update_kr` | Update a KR value |
| `weekly_summary` | Full weekly compiled summary |

You don't need to call these directly — just ask Claude naturally and it picks the right tool.

## Troubleshooting

### `make doctor`

Run this anytime something feels off:

```bash
make doctor
```

It checks 6 things:
1. `.env` has your API key
2. `config.yaml` has your name
3. `.mcp.json` exists
4. `npx` is available (Node.js)
5. MCP server is reachable
6. Skills are installed

### Common issues

**"MCP server unreachable"**
- Check your internet connection
- The server is at `weeklyops.membies.com` — try `curl https://weeklyops.membies.com/health`
- If the server is down, contact Chris

**"No MCP tools available" in Claude Code**
- Make sure `.mcp.json` exists (run `make setup` if not)
- Restart Claude Code after setup (it reads `.mcp.json` on startup)
- Check that your API key is correct in `.env`

**"Unknown author" errors**
- Your name in `config.yaml` must match the team roster exactly
- Run `make setup` to pick your name from the list

**Skills not showing up**
- Skills need to be in `skills/*/SKILL.md`
- Run `make doctor` to verify skill count
- Some Claude Code versions need a restart to pick up new skills

## Updating

Pull the latest:

```bash
git pull origin main
```

Your `.env`, `.mcp.json`, and `config.yaml` are gitignored — updates won't overwrite your personal config.
