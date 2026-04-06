# weeklyops-prompt

**The one repo every team member needs.** Clone it, run setup, and interact with the WeeklyOps system — either from the terminal (Claude Code) or the Claude Desktop app.

## Quick Start

```bash
git clone https://github.com/msifoss/weeklyops-prompt.git
cd weeklyops-prompt
```

**Pick your interface:**

| Command | For who |
|---------|---------|
| `make setup` | Terminal users — configures Claude Code with MCP connection |
| `make install-app` | Desktop users — adds WeeklyOps to the Claude Desktop app |

Both ask for your name and API key. You can run both if you use both interfaces.

## What You Can Do

Talk naturally ("show me my OKR status") or use guided skills:

| Skill | What it does |
|-------|-------------|
| `/email-scan` | Generate a prompt for your email tool to extract structured data |
| `/email-ingest [file]` | Process email scan output, cross-reference with OKRs, save summary |
| `/weekly-update [range]` | Produce an OKR-disciplined weekly self-review |
| `/prompt-feature-assess` | Surface platform enhancement ideas from your session (with consent) |

All persistent output is routed through the WeeklyOps MCP server to the shared data repo — nothing gets lost in local files.

## Prerequisites

- [Claude Code](https://claude.ai/code) CLI and/or [Claude Desktop](https://claude.ai/download)
- A WeeklyOps API key (get yours from Chris)
- Node.js 18+ (for the `mcp-remote` proxy)

## Troubleshooting

```bash
make doctor
```

## Full Guide

See [docs/guides/getting-started.md](docs/guides/getting-started.md) for the detailed walkthrough.

## Architecture

```
weeklyops-prompt (this repo — your workspace)
    │
    │ MCP tools (save_document, get_team_status, etc.)
    ▼
weeklyops (MCP server — platform code, developers only)
    │
    │ GitHub API
    ▼
weeklyops-data (structured team data)
```

You don't need the other repos. This is your single entry point.
