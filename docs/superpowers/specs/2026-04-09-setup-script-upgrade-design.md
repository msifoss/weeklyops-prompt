# Setup Script Upgrade — Robust Dependency Management

**Date:** 2026-04-09
**Type:** Enhancement
**Files:** `scripts/setup.sh`, `scripts/doctor.sh`

## Problem

The current `setup.sh` assumes all dependencies (Node.js, npx, mcp-remote) are pre-installed. If they're missing, the user hits cryptic failures later when Claude Code tries to connect to the MCP server. `doctor.sh` only checks a subset of dependencies (npx, curl) and misses Node.js version, mcp-remote, git, and python3.

## Design Decisions (from brainstorming)

1. **Scope:** Only upgrade `make setup` (Claude Code path). `install-app.sh` stays as-is.
2. **Install strategy:** Scan all deps first, show what's missing, single upfront confirmation, then auto-install.
3. **Doctor upgrade:** Same thorough checks as setup, but diagnose-only (never installs).
4. **Progress style:** Numbered steps with status icons (`[1/8] Checking X ... done`).

## Setup Script Flow

```
[1/8] Checking Homebrew .............. ok / missing → install
[2/8] Checking Node.js 18+ ........... ok / missing → brew install
[3/8] Checking mcp-remote ............ ok / missing → npm install -g
[4/8] Checking system tools .......... ok (git, curl, python3)
[5/8] Selecting identity ............. name picker
[6/8] Configuring API key ............ prompt or keep existing
[7/8] Generating config files ........ .env, config.yaml, .mcp.json
[8/8] Running health checks .......... doctor.sh
```

### Phase 1: Dependency Scan (silent)

Check each dependency without output. Build a list of what's missing.

| Dependency | Check | Install method | Version requirement |
|---|---|---|---|
| Homebrew | `command -v brew` | Official install script | Any |
| Node.js | `command -v node` + major version >= 18 | `brew install node@22` + PATH symlink | 18+ |
| npx | `command -v npx` | Comes with Node.js | Any |
| mcp-remote | `npm list -g mcp-remote 2>/dev/null` | `npm install -g mcp-remote` | Any |
| git | `command -v git` | `xcode-select --install` (prompt) | Any |
| curl | `command -v curl` | Warn only (ships with macOS) | Any |
| python3 | `command -v python3` | Warn only (ships with macOS) | Any |

### Phase 2: Confirmation

If anything needs installing, display:

```
The following dependencies need to be installed:
  - Homebrew (macOS package manager)
  - Node.js 22 (via Homebrew)
  - mcp-remote (npm package for MCP proxy)

Proceed with installation? (Y/n):
```

If user declines, print what's needed and exit cleanly.

### Phase 3: Install (with progress)

Install each missing dependency in order with step indicators. Show version after install.

### Phase 4: Identity + Config (existing flow)

Same name picker, API key prompt, and config file generation as current script.

### Phase 5: Health check

Call upgraded `doctor.sh`.

## Doctor Script Upgrade

Add these checks to the existing 6:

| New Check | Method |
|---|---|
| Homebrew installed | `command -v brew` |
| Node.js version >= 18 | `node --version` + parse major |
| mcp-remote installed | `npm list -g mcp-remote` |
| git available | `command -v git` |
| python3 available | `command -v python3` |

Doctor never installs — just reports pass/fail with actionable fix messages.

## Error Handling

- Homebrew install fails → exit with clear message
- `brew install node@22` fails → suggest manual install URL, exit
- `npm install -g mcp-remote` fails → suggest `sudo npm install -g mcp-remote`, exit
- Network unreachable → detect early via curl check, warn that installs may fail
- User declines install → print requirements list, exit 0 (not an error)

## What Stays the Same

- Name picker (8-person hardcoded roster)
- API key prompt/keep logic
- Config file generation (.env, config.yaml, .mcp.json)
- `make doctor` and `make setup` Makefile targets
- `install-app.sh` untouched
