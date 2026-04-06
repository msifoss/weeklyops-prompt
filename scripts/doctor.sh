#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

PASS=0
FAIL=0

check() {
    local name="$1"
    local result="$2"
    if [ "$result" = "ok" ]; then
        echo "  [PASS] $name"
        PASS=$((PASS + 1))
    else
        echo "  [FAIL] $name — $result"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== WeeklyOps Prompt Doctor ==="
echo ""

# 1. Check .env exists and has API key
if [ -f "$PROJECT_DIR/.env" ] && grep -q "WEEKLYOPS_API_KEY=." "$PROJECT_DIR/.env" 2>/dev/null; then
    check ".env has API key" "ok"
else
    check ".env has API key" "Missing or empty. Run: make setup"
fi

# 2. Check config.yaml has user name
if [ -f "$PROJECT_DIR/config.yaml" ] && grep -q 'name: ".\+' "$PROJECT_DIR/config.yaml" 2>/dev/null; then
    USER_NAME=$(grep 'name:' "$PROJECT_DIR/config.yaml" | head -1 | sed 's/.*name: *"\(.*\)"/\1/')
    check "config.yaml has user ($USER_NAME)" "ok"
else
    check "config.yaml has user" "User name not set. Run: make setup"
fi

# 3. Check .mcp.json exists
if [ -f "$PROJECT_DIR/.mcp.json" ]; then
    check ".mcp.json exists" "ok"
else
    check ".mcp.json exists" "Missing. Run: make setup"
fi

# 4. Check npx/mcp-remote available
if command -v npx &>/dev/null; then
    check "npx available" "ok"
else
    check "npx available" "Install Node.js: brew install node"
fi

# 5. Check MCP server reachable
if command -v curl &>/dev/null; then
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "https://weeklyops.membies.com/health" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ]; then
        check "MCP server reachable" "ok"
    else
        check "MCP server reachable" "HTTP $HTTP_CODE — server may be down"
    fi
else
    check "MCP server reachable" "curl not found"
fi

# 6. Check skills directory
SKILL_COUNT=$(find "$PROJECT_DIR/skills" -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
if [ "$SKILL_COUNT" -gt 0 ]; then
    check "Skills installed ($SKILL_COUNT)" "ok"
else
    check "Skills installed" "No SKILL.md files found in skills/"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
    echo "Fix the failures above, then run: make doctor"
    exit 1
fi
