#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$HOME/Library/Application Support/Claude"
CONFIG_FILE="$CONFIG_DIR/claude_desktop_config.json"

echo "=== WeeklyOps — Claude Desktop Install ==="
echo ""

# --- Step 1: Check prerequisites ---

# Check Node.js
if ! command -v node &>/dev/null; then
    echo "[FAIL] Node.js not found. Install it first:"
    echo "  brew install node@22"
    exit 1
fi
echo "[OK] Node.js $(node --version)"

# Check/install mcp-remote
PROXY_PATH="$(npm root -g 2>/dev/null)/mcp-remote/dist/proxy.js"
if [ ! -f "$PROXY_PATH" ]; then
    echo "Installing mcp-remote..."
    npm install -g mcp-remote
    PROXY_PATH="$(npm root -g)/mcp-remote/dist/proxy.js"
fi
echo "[OK] mcp-remote at $PROXY_PATH"

# Get node path
NODE_PATH="$(which node)"
echo "[OK] Node at $NODE_PATH"
echo ""

# --- Step 2: Get API key ---

if [ -f "$PROJECT_DIR/.env" ] && grep -q "WEEKLYOPS_API_KEY=." "$PROJECT_DIR/.env" 2>/dev/null; then
    source "$PROJECT_DIR/.env"
    echo "Using API key from .env"
else
    read -rp "Paste your WeeklyOps API key: " WEEKLYOPS_API_KEY
    if [ -z "$WEEKLYOPS_API_KEY" ]; then
        echo "No key provided. Run make setup first, or paste your key."
        exit 1
    fi
fi
echo ""

# --- Step 3: Write Claude Desktop config ---

mkdir -p "$CONFIG_DIR"

# Build the weeklyops server entry
WEEKLYOPS_ENTRY=$(cat <<ENTRY
{
      "command": "$NODE_PATH",
      "args": [
        "$PROXY_PATH",
        "https://weeklyops.membies.com/mcp",
        "--header",
        "Authorization: Bearer $WEEKLYOPS_API_KEY",
        "--transport",
        "http-only"
      ]
    }
ENTRY
)

if [ -f "$CONFIG_FILE" ]; then
    # Check if weeklyops entry already exists
    if python3 -c "
import json, sys
with open('$CONFIG_FILE') as f:
    c = json.load(f)
if 'weeklyops' in c.get('mcpServers', {}):
    sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
        echo "weeklyops entry already exists in Claude Desktop config."
        read -rp "Replace it? (y/N): " replace
        if [[ "$replace" != "y" && "$replace" != "Y" ]]; then
            echo "  → Keeping existing config"
            echo ""
            echo "Restart Claude Desktop (Cmd+Q then reopen) to apply changes."
            exit 0
        fi
    fi

    # Update existing config — add or replace weeklyops entry
    python3 -c "
import json
with open('$CONFIG_FILE') as f:
    config = json.load(f)
if 'mcpServers' not in config:
    config['mcpServers'] = {}
config['mcpServers']['weeklyops'] = json.loads('''$WEEKLYOPS_ENTRY''')
with open('$CONFIG_FILE', 'w') as f:
    json.dump(config, f, indent=2)
print('  → Updated weeklyops entry in existing config')
"
else
    # Create new config
    python3 -c "
import json
config = {
    'mcpServers': {
        'weeklyops': json.loads('''$WEEKLYOPS_ENTRY''')
    }
}
with open('$CONFIG_FILE', 'w') as f:
    json.dump(config, f, indent=2)
print('  → Created Claude Desktop config with weeklyops')
"
fi

echo ""
echo "=== Install Complete ==="
echo ""
echo "Next steps:"
echo "  1. Quit Claude Desktop completely (Cmd+Q)"
echo "  2. Reopen Claude Desktop"
echo "  3. Look for the tools icon (hammer) in the chat input"
echo "  4. Type: Use the whoami tool"
echo ""
echo "You should see your name and role."
