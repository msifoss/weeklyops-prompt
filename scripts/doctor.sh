#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# ─── Colors & symbols ───────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

PASS=0
FAIL=0
WARN=0

# ─── Check helpers ───────────────────────────────────────────────────

pass() {
    local name="$1"
    local detail="${2:-}"
    if [ -n "$detail" ]; then
        echo -e "  ${GREEN}[PASS]${RESET} $name ${DIM}($detail)${RESET}"
    else
        echo -e "  ${GREEN}[PASS]${RESET} $name"
    fi
    PASS=$((PASS + 1))
}

fail() {
    local name="$1"
    local fix="$2"
    echo -e "  ${RED}[FAIL]${RESET} $name"
    echo -e "         ${DIM}Fix: $fix${RESET}"
    FAIL=$((FAIL + 1))
}

warn() {
    local name="$1"
    local note="$2"
    echo -e "  ${YELLOW}[WARN]${RESET} $name"
    echo -e "         ${DIM}$note${RESET}"
    WARN=$((WARN + 1))
}

# ─── Main ────────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}=== WeeklyOps Doctor ===${RESET}"

# ─── Section: Dependencies ───────────────────────────────────────────

echo ""
echo -e "${BOLD}Dependencies${RESET}"

# Homebrew
if command -v brew &>/dev/null; then
    pass "Homebrew" "$(brew --version 2>/dev/null | head -1)"
else
    fail "Homebrew" "Install from https://brew.sh"
fi

# Node.js 18+
if command -v node &>/dev/null; then
    NODE_VER=$(node --version 2>/dev/null | sed 's/^v//')
    NODE_MAJOR=$(echo "$NODE_VER" | cut -d. -f1)
    if [ "${NODE_MAJOR:-0}" -ge 18 ]; then
        pass "Node.js 18+" "v${NODE_VER}"
    else
        fail "Node.js 18+" "Found v${NODE_VER} — need 18+. Run: brew install node@22"
    fi
else
    fail "Node.js 18+" "Run: brew install node@22"
fi

# npx
if command -v npx &>/dev/null; then
    pass "npx" "$(npx --version 2>/dev/null)"
else
    fail "npx" "Comes with Node.js — reinstall Node"
fi

# mcp-remote
if npm list -g mcp-remote &>/dev/null 2>&1; then
    MCP_VER=$(npm list -g mcp-remote 2>/dev/null | grep mcp-remote | head -1 | sed 's/.*@/v/')
    pass "mcp-remote" "${MCP_VER}"
else
    fail "mcp-remote" "Run: npm install -g mcp-remote"
fi

# git
if command -v git &>/dev/null; then
    pass "git" "$(git --version 2>/dev/null | sed 's/git version //')"
else
    fail "git" "Run: xcode-select --install"
fi

# curl
if command -v curl &>/dev/null; then
    pass "curl" "$(curl --version 2>/dev/null | head -1 | cut -d' ' -f1-2)"
else
    warn "curl" "Usually ships with macOS — check your PATH"
fi

# python3
if command -v python3 &>/dev/null; then
    pass "python3" "$(python3 --version 2>/dev/null | sed 's/Python //')"
else
    warn "python3" "Needed by install-app.sh — usually ships with macOS"
fi

# age
if command -v age &>/dev/null; then
    pass "age" "$(age --version 2>/dev/null)"
else
    fail "age" "Run: brew install age"
fi

# ─── Section: Configuration ──────────────────────────────────────────

echo ""
echo -e "${BOLD}Configuration${RESET}"

# .env has API key
if [ -f "$PROJECT_DIR/.env" ] && grep -q "WEEKLYOPS_API_KEY=." "$PROJECT_DIR/.env" 2>/dev/null; then
    pass ".env has API key"
else
    fail ".env has API key" "Run: make setup"
fi

# config.yaml has user name
if [ -f "$PROJECT_DIR/config.yaml" ] && grep -q 'name: ".\+' "$PROJECT_DIR/config.yaml" 2>/dev/null; then
    USER_NAME=$(grep 'name:' "$PROJECT_DIR/config.yaml" | head -1 | sed 's/.*name: *"\(.*\)"/\1/')
    pass "config.yaml has user" "$USER_NAME"
else
    fail "config.yaml has user" "Run: make setup"
fi

# .env.age exists
if [ -f "$PROJECT_DIR/.env.age" ]; then
    pass ".env.age exists" "encrypted team keys"
else
    fail ".env.age exists" "This file should be in the repo — try git pull"
fi

# .mcp.json exists
if [ -f "$PROJECT_DIR/.mcp.json" ]; then
    pass ".mcp.json exists"
else
    fail ".mcp.json exists" "Run: make setup"
fi

# ─── Section: Connectivity ───────────────────────────────────────────

echo ""
echo -e "${BOLD}Connectivity${RESET}"

# MCP server reachable
if command -v curl &>/dev/null; then
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "https://weeklyops.membies.com/health" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ]; then
        pass "MCP server reachable" "weeklyops.membies.com"
    elif [ "$HTTP_CODE" = "000" ]; then
        fail "MCP server reachable" "Network error — check your internet connection"
    else
        fail "MCP server reachable" "HTTP $HTTP_CODE — server may be down"
    fi
else
    warn "MCP server reachable" "Cannot check — curl not found"
fi

# ─── Section: Skills ─────────────────────────────────────────────────

echo ""
echo -e "${BOLD}Skills${RESET}"

SKILL_COUNT=$(find "$PROJECT_DIR/skills" -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
if [ "$SKILL_COUNT" -gt 0 ]; then
    SKILL_NAMES=$(find "$PROJECT_DIR/skills" -name "SKILL.md" -exec dirname {} \; 2>/dev/null | xargs -I{} basename {} | sort | tr '\n' ', ' | sed 's/,$//')
    pass "Skills installed ($SKILL_COUNT)" "$SKILL_NAMES"
else
    fail "Skills installed" "No SKILL.md files found in skills/"
fi

# ─── Summary ─────────────────────────────────────────────────────────

echo ""
TOTAL=$((PASS + FAIL + WARN))
echo -e "${BOLD}Results:${RESET} ${GREEN}$PASS passed${RESET}, ${RED}$FAIL failed${RESET}, ${YELLOW}$WARN warnings${RESET}"

if [ "$FAIL" -gt 0 ]; then
    echo -e "${YELLOW}Fix the failures above, then run: ${CYAN}make doctor${RESET}"
    exit 1
elif [ "$WARN" -gt 0 ]; then
    echo -e "${DIM}Warnings are non-blocking but may affect some features.${RESET}"
fi
