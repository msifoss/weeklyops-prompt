# weeklyops-prompt

Conversational front-end for the [WeeklyOps](https://github.com/msifoss/weeklyops) team operations system. Clone this repo, run setup, and use Claude Code for OKR conversations, email analysis, and weekly reviews.

## Quick Start

```bash
git clone https://github.com/msifoss/weeklyops-prompt.git
cd weeklyops-prompt
make setup
```

Setup will ask for your name and API key, then verify your MCP connection.

## What This Does

This repo is your Claude Code workspace for interacting with the WeeklyOps system. It provides guided skills for common workflows:

| Skill | What it does |
|-------|-------------|
| `/email-scan` | Generate a prompt for your email tool to extract structured data |
| `/email-ingest [file]` | Process email scan output, cross-reference with OKRs, save summary |
| `/weekly-update [range]` | Produce an OKR-disciplined weekly self-review |

All persistent output is routed through the WeeklyOps MCP server to the shared data repo — nothing gets lost in local files.

## Prerequisites

- [Claude Code](https://claude.ai/code) CLI installed
- A WeeklyOps API key (ask your team admin)
- Node.js (for `mcp-remote` proxy)

## Troubleshooting

Run `make doctor` to check your MCP connection and identity.

## Architecture

```
weeklyops-prompt (this repo — conversations + skills)
    │
    │ calls MCP tools
    ▼
weeklyops (MCP server)
    │
    │ reads/writes via GitHub API
    ▼
weeklyops-data (structured markdown)
```
