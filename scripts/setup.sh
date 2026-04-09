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

SYM_OK="${GREEN}✓${RESET}"
SYM_FAIL="${RED}✗${RESET}"
SYM_WARN="${YELLOW}!${RESET}"
SYM_ARROW="${CYAN}→${RESET}"
SYM_DOT="${DIM}·${RESET}"

TOTAL_STEPS=8
MISSING_DEPS=()

# ─── Helper functions ────────────────────────────────────────────────

step() {
    local num="$1"
    local label="$2"
    printf "\n${BOLD}[%d/%d]${RESET} %s " "$num" "$TOTAL_STEPS" "$label"
}

dots() {
    local label_len=${#1}
    local total=45
    local dot_count=$((total - label_len))
    if [ "$dot_count" -lt 3 ]; then dot_count=3; fi
    for ((i=0; i<dot_count; i++)); do printf "${DIM}.${RESET}"; done
    printf " "
}

ok() {
    local msg="${1:-installed}"
    printf "${SYM_OK} ${GREEN}%s${RESET}\n" "$msg"
}

fail() {
    local msg="${1:-missing}"
    printf "${SYM_FAIL} ${RED}%s${RESET}\n" "$msg"
}

warn() {
    local msg="${1:-warning}"
    printf "${SYM_WARN} ${YELLOW}%s${RESET}\n" "$msg"
}

installing() {
    local msg="${1:-installing...}"
    printf "\n      ${SYM_ARROW} %s " "$msg"
}

abort() {
    echo ""
    echo -e "${RED}${BOLD}Setup aborted:${RESET} $1"
    echo -e "Fix the issue above and run ${CYAN}make setup${RESET} again."
    exit 1
}

# ─── Dependency checks (silent scan) ────────────────────────────────

check_homebrew() {
    command -v brew &>/dev/null
}

check_node() {
    if ! command -v node &>/dev/null; then
        return 1
    fi
    local major
    major=$(node --version 2>/dev/null | sed 's/^v//' | cut -d. -f1)
    [ "${major:-0}" -ge 18 ]
}

get_node_version() {
    node --version 2>/dev/null || echo "unknown"
}

check_npx() {
    command -v npx &>/dev/null
}

check_mcp_remote() {
    npm list -g mcp-remote &>/dev/null 2>&1
}

get_mcp_remote_version() {
    npm list -g mcp-remote 2>/dev/null | grep mcp-remote | head -1 | sed 's/.*@/v/'
}

check_git() {
    command -v git &>/dev/null
}

check_curl() {
    command -v curl &>/dev/null
}

check_python3() {
    command -v python3 &>/dev/null
}

check_age() {
    command -v age &>/dev/null
}

get_age_version() {
    age --version 2>/dev/null || echo "unknown"
}

# Convert display name to USER_KEY_ env var name
# e.g., "Mary-Margaret" → "USER_KEY_MARY_MARGARET"
name_to_key_var() {
    local name="$1"
    echo "USER_KEY_$(echo "$name" | tr '[:lower:]' '[:upper:]' | tr '-' '_')"
}

# ─── Main ────────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}=== WeeklyOps Prompt Setup ===${RESET}"
echo ""
echo -e "${DIM}This will configure your identity, install dependencies,${RESET}"
echo -e "${DIM}and connect Claude Code to the WeeklyOps MCP server.${RESET}"

# ─── Step 1: Check Homebrew ──────────────────────────────────────────

step 1 "Checking Homebrew"
dots "Checking Homebrew"

if check_homebrew; then
    ok "$(brew --version 2>/dev/null | head -1)"
else
    fail "missing"
    MISSING_DEPS+=("homebrew")
fi

# ─── Step 2: Check Node.js 18+ ──────────────────────────────────────

step 2 "Checking Node.js 18+"
dots "Checking Node.js 18+"

if check_node; then
    ok "$(get_node_version)"
else
    if command -v node &>/dev/null; then
        fail "$(get_node_version) — need 18+"
    else
        fail "missing"
    fi
    MISSING_DEPS+=("node")
fi

# ─── Step 3: Check mcp-remote ───────────────────────────────────────

step 3 "Checking mcp-remote"
dots "Checking mcp-remote"

if check_mcp_remote; then
    ok "$(get_mcp_remote_version)"
else
    fail "missing"
    MISSING_DEPS+=("mcp-remote")
fi

# ─── Step 4: Check system tools ─────────────────────────────────────

step 4 "Checking system tools"
dots "Checking system tools"

SYSTEM_WARNINGS=()

if ! check_git; then
    SYSTEM_WARNINGS+=("git")
fi
if ! check_curl; then
    SYSTEM_WARNINGS+=("curl")
fi
if ! check_python3; then
    SYSTEM_WARNINGS+=("python3")
fi

if ! check_age; then
    SYSTEM_WARNINGS+=("age")
fi

if [ ${#SYSTEM_WARNINGS[@]} -eq 0 ]; then
    ok "git, curl, python3, age"
else
    warn "missing: ${SYSTEM_WARNINGS[*]}"
    for tool in "${SYSTEM_WARNINGS[@]}"; do
        if [ "$tool" = "git" ]; then
            MISSING_DEPS+=("git")
        elif [ "$tool" = "age" ]; then
            MISSING_DEPS+=("age")
        else
            echo -e "      ${SYM_WARN} ${YELLOW}${tool} is usually included with macOS — you may need to install Xcode Command Line Tools${RESET}"
        fi
    done
fi

# ─── Install missing dependencies ───────────────────────────────────

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    echo ""
    echo -e "${BOLD}The following dependencies need to be installed:${RESET}"
    for dep in "${MISSING_DEPS[@]}"; do
        case "$dep" in
            homebrew)  echo -e "  ${SYM_ARROW} Homebrew ${DIM}(macOS package manager)${RESET}" ;;
            node)      echo -e "  ${SYM_ARROW} Node.js 22 ${DIM}(via Homebrew)${RESET}" ;;
            mcp-remote) echo -e "  ${SYM_ARROW} mcp-remote ${DIM}(npm package for MCP proxy)${RESET}" ;;
            age)       echo -e "  ${SYM_ARROW} age ${DIM}(encryption tool for shared secrets)${RESET}" ;;
            git)       echo -e "  ${SYM_ARROW} Git ${DIM}(via Xcode Command Line Tools)${RESET}" ;;
        esac
    done
    echo ""
    read -rp "$(echo -e "${BOLD}Proceed with installation? (Y/n):${RESET} ")" confirm
    if [[ "$confirm" =~ ^[nN] ]]; then
        echo ""
        echo -e "${YELLOW}Setup paused.${RESET} Install the dependencies above manually, then run ${CYAN}make setup${RESET} again."
        exit 0
    fi

    echo ""
    echo -e "${BOLD}Installing dependencies...${RESET}"

    for dep in "${MISSING_DEPS[@]}"; do
        case "$dep" in
            homebrew)
                installing "Installing Homebrew..."
                if /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/null; then
                    # Add brew to PATH for this session (Apple Silicon vs Intel)
                    if [ -f /opt/homebrew/bin/brew ]; then
                        eval "$(/opt/homebrew/bin/brew shellenv)"
                    elif [ -f /usr/local/bin/brew ]; then
                        eval "$(/usr/local/bin/brew shellenv)"
                    fi
                    ok "$(brew --version 2>/dev/null | head -1)"
                else
                    abort "Homebrew installation failed. Install manually from https://brew.sh"
                fi
                ;;

            node)
                if ! check_homebrew; then
                    abort "Node.js requires Homebrew. Homebrew installation must have failed."
                fi
                installing "Installing Node.js 22 via Homebrew (this may take a minute)..."
                if brew install node@22 2>/dev/null; then
                    # Ensure node@22 is linked and on PATH
                    brew link --overwrite node@22 2>/dev/null || true
                    # Refresh PATH to pick up newly installed node
                    export PATH="$(brew --prefix)/opt/node@22/bin:$PATH"
                    if check_node; then
                        ok "$(get_node_version)"
                    else
                        # Fallback: try unversioned node package
                        installing "Trying alternate Node.js package..."
                        brew install node 2>/dev/null || true
                        if check_node; then
                            ok "$(get_node_version)"
                        else
                            abort "Node.js installed but not working. Try: brew install node"
                        fi
                    fi
                else
                    abort "Node.js installation failed. Try manually: brew install node@22"
                fi
                ;;

            mcp-remote)
                if ! command -v npm &>/dev/null; then
                    abort "npm not found. Node.js installation may have failed."
                fi
                installing "Installing mcp-remote globally..."
                if npm install -g mcp-remote 2>/dev/null; then
                    ok "$(get_mcp_remote_version)"
                else
                    echo ""
                    echo -e "      ${SYM_WARN} ${YELLOW}Retrying with sudo...${RESET}"
                    installing "Installing mcp-remote with sudo..."
                    if sudo npm install -g mcp-remote 2>/dev/null; then
                        ok "$(get_mcp_remote_version)"
                    else
                        abort "mcp-remote installation failed. Try: sudo npm install -g mcp-remote"
                    fi
                fi
                ;;

            age)
                if ! check_homebrew; then
                    abort "age requires Homebrew. Homebrew installation must have failed."
                fi
                installing "Installing age via Homebrew..."
                if brew install age 2>/dev/null; then
                    ok "$(get_age_version)"
                else
                    abort "age installation failed. Try manually: brew install age"
                fi
                ;;

            git)
                installing "Triggering Xcode Command Line Tools install..."
                echo ""
                echo -e "      ${SYM_WARN} ${YELLOW}A macOS dialog may appear — click 'Install' to continue.${RESET}"
                xcode-select --install 2>/dev/null || true
                echo -e "      ${DIM}Waiting for Xcode CLT installation to complete...${RESET}"
                # Wait for the install to finish (checks every 5 seconds, up to 10 minutes)
                waited=0
                while ! check_git && [ $waited -lt 600 ]; do
                    sleep 5
                    waited=$((waited + 5))
                done
                if check_git; then
                    ok "$(git --version)"
                else
                    warn "Xcode CLT install may still be running. Re-run make setup after it finishes."
                fi
                ;;
        esac
    done

    echo ""
    echo -e "${GREEN}${BOLD}Dependencies installed.${RESET}"
fi

# ─── Step 5: Select identity ────────────────────────────────────────

step 5 "Selecting identity"
echo ""

NAMES=("Chris" "Mary-Margaret" "Fathima" "Isaac" "Avery" "MD" "Tyler" "David")

# Show current user if config exists
if [ -f "$PROJECT_DIR/config.yaml" ]; then
    CURRENT_USER=$(grep 'name:' "$PROJECT_DIR/config.yaml" 2>/dev/null | head -1 | sed 's/.*name: *"\(.*\)"/\1/')
    if [ -n "${CURRENT_USER:-}" ]; then
        echo -e "      ${DIM}Current user: ${CURRENT_USER}${RESET}"
    fi
fi

echo ""
echo "      Who are you?"
echo ""
for i in "${!NAMES[@]}"; do
    printf "        %d) %s\n" "$((i+1))" "${NAMES[$i]}"
done
echo ""
read -rp "      Enter number (1-${#NAMES[@]}): " choice

if [[ -z "$choice" || "$choice" -lt 1 || "$choice" -gt "${#NAMES[@]}" ]] 2>/dev/null; then
    abort "Invalid choice. Enter a number between 1 and ${#NAMES[@]}."
fi

USER_NAME="${NAMES[$((choice-1))]}"
echo -e "      ${SYM_OK} ${GREEN}${USER_NAME}${RESET}"

# ─── Step 6: Extract API key from .env.age ─────────────────────────

step 6 "Extracting API key"
echo ""

KEY_VAR=$(name_to_key_var "$USER_NAME")

if [ ! -f "$PROJECT_DIR/.env.age" ]; then
    abort ".env.age not found. This file should be in the repo — try git pull."
fi

echo -e "      ${DIM}Decrypting .env.age to extract your key...${RESET}"
echo -e "      ${DIM}Enter the team passphrase when prompted.${RESET}"
echo ""

DECRYPTED=$(age -d "$PROJECT_DIR/.env.age" 2>/dev/null) || abort "Decryption failed — wrong passphrase?"

# Extract the user's key from the decrypted content
api_key=$(echo "$DECRYPTED" | grep "^${KEY_VAR}=" | head -1 | cut -d'=' -f2-)

if [ -z "$api_key" ]; then
    abort "No key found for ${KEY_VAR} in .env.age. Contact your team admin."
fi

echo "WEEKLYOPS_API_KEY=$api_key" > "$PROJECT_DIR/.env"
echo -e "      ${SYM_OK} ${GREEN}Key extracted for ${USER_NAME}${RESET}"

# ─── Step 7: Generate config files ──────────────────────────────────

step 7 "Generating config files"
dots "Generating config files"

# Write config.yaml
cat > "$PROJECT_DIR/config.yaml" <<YAML
# WeeklyOps Prompt — User Configuration
# Generated by make setup on $(date +%Y-%m-%d)

user:
  name: "$USER_NAME"
YAML

# Read the API key
source "$PROJECT_DIR/.env"

if [ -z "${WEEKLYOPS_API_KEY:-}" ]; then
    fail "API key is empty"
    abort "WEEKLYOPS_API_KEY is empty in .env. Run setup again with a valid key."
fi

# Write .mcp.json
cat > "$PROJECT_DIR/.mcp.json" <<JSON
{
  "mcpServers": {
    "weeklyops": {
      "command": "npx",
      "args": [
        "mcp-remote",
        "https://weeklyops.membies.com/mcp",
        "--header",
        "Authorization: Bearer $WEEKLYOPS_API_KEY",
        "--transport",
        "http-only"
      ]
    }
  }
}
JSON

ok "config.yaml, .mcp.json"

# ─── Step 8: Health checks ──────────────────────────────────────────

step 8 "Running health checks"
echo ""
echo ""

bash "$SCRIPT_DIR/doctor.sh"

# ─── Done ────────────────────────────────────────────────────────────

echo ""
echo -e "${GREEN}${BOLD}=== Setup Complete ===${RESET}"
echo ""
echo -e "Open Claude Code in this directory and start talking."
echo ""
echo -e "  ${CYAN}Try:${RESET}"
echo -e "    ${DIM}\"show me my OKR status\"${RESET}"
echo -e "    ${DIM}\"scan my email\"${RESET}"
echo -e "    ${DIM}\"do my weekly update\"${RESET}"
echo ""
