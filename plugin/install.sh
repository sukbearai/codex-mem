#!/bin/bash
set -eo pipefail

# Codex-Mem installer
# Detects installed LLM agents and generates the appropriate configuration.
# Supports: Claude Code, Codex CLI.
#
# Two modes:
#   Standalone — run from within the codex-mem repo (vault/ is the working directory)
#   Integrated — run from a user's project root (vault/ becomes a subdirectory)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_DIR="$(pwd)"

echo "=== Codex-Mem Installer ==="
echo ""

# --- Detect mode ---
# If CWD is the codex-mem repo (or vault/), use standalone mode.
# Otherwise, use integrated mode (install into user's project).

MODE="integrated"
if [ "$PROJECT_DIR" = "$REPO_DIR" ] || [ "$PROJECT_DIR" = "$REPO_DIR/vault" ]; then
  MODE="standalone"
fi
# Also detect if inside repo subdirectories
case "$PROJECT_DIR" in
  "$REPO_DIR"/*) MODE="standalone" ;;
esac

if [ "$MODE" = "standalone" ]; then
  VAULT_DIR="$REPO_DIR/vault"
  CONFIG_DIR="$VAULT_DIR"            # configs go inside vault/
  HOOKS_REL=".codex-mem/hooks"       # relative to vault/
  echo "[*] Standalone mode — vault is the working directory"
else
  VAULT_DIR="$PROJECT_DIR/vault"
  CONFIG_DIR="$PROJECT_DIR"          # configs go at project root
  HOOKS_REL="vault/.codex-mem/hooks" # relative to project root
  echo "[*] Integrated mode — installing into $(basename "$PROJECT_DIR")/"
fi

echo ""

# --- Detect agents ---

AGENTS=()

if command -v claude &>/dev/null; then
  AGENTS+=("claude")
  echo "[+] Claude Code detected"
fi

if command -v codex &>/dev/null; then
  AGENTS+=("codex")
  echo "[+] Codex CLI detected"
fi

if [ ${#AGENTS[@]} -eq 0 ]; then
  echo "[!] No supported agents found."
  echo "    Install Claude Code: https://docs.anthropic.com/en/docs/claude-code"
  echo "    Install Codex CLI:   https://github.com/openai/codex"
  echo ""
  echo "    You can still use the vault manually — just open it in Obsidian."
  exit 0
fi

echo ""

# --- Copy vault template (integrated mode only) ---

if [ "$MODE" = "integrated" ]; then
  if [ -d "$VAULT_DIR" ] && [ -f "$VAULT_DIR/Home.md" ]; then
    echo "[*] Vault already exists at vault/ — skipping template copy"
  else
    echo "[+] Creating vault from template..."
    mkdir -p "$VAULT_DIR"
    # Copy vault contents, excluding agent-specific configs (we generate those)
    # Use cp -r (universally available) instead of rsync
    cp -r "$REPO_DIR/vault/"* "$VAULT_DIR/" 2>/dev/null || true
    cp -r "$REPO_DIR/vault/".* "$VAULT_DIR/" 2>/dev/null || true
    # Remove agent configs — we generate fresh ones for the target layout
    rm -rf "$VAULT_DIR/.claude" "$VAULT_DIR/.codex" "$VAULT_DIR/CLAUDE.md" "$VAULT_DIR/AGENTS.md" 2>/dev/null || true
    echo "    Copied template to vault/"
  fi
  echo ""
fi

# --- Copy hooks into vault (makes vault self-contained) ---

HOOKS_DIR="$VAULT_DIR/.codex-mem/hooks"
mkdir -p "$HOOKS_DIR"
cp "$REPO_DIR/plugin/hooks/"* "$HOOKS_DIR/"
chmod +x "$HOOKS_DIR/"*.sh "$HOOKS_DIR/"*.py 2>/dev/null || true
echo "[+] Hook scripts copied to vault/.codex-mem/hooks/"
echo ""

# --- Helper: merge hooks into existing settings.json ---
# Uses python3 for reliable JSON manipulation.

merge_hooks_json() {
  local target_file="$1"
  local hooks_rel="$2"

  # Pass data via env vars to python3 — no shell interpolation in python code.
  CMEM_TARGET_FILE="$target_file" CMEM_HOOKS_REL="$hooks_rel" python3 <<'PYEOF'
import json, os

target_file = os.environ["CMEM_TARGET_FILE"]
hooks_rel = os.environ["CMEM_HOOKS_REL"]

new_hooks = {
    "SessionStart": [{
        "matcher": "startup|resume|compact",
        "hooks": [{"type": "command", "command": f"bash {hooks_rel}/session-start.sh", "timeout": 30}]
    }],
    "UserPromptSubmit": [{
        "hooks": [{"type": "command", "command": f"python3 {hooks_rel}/classify-message.py", "timeout": 15}]
    }],
    "PostToolUse": [{
        "matcher": "Write|Edit",
        "hooks": [{"type": "command", "command": f"python3 {hooks_rel}/validate-write.py", "timeout": 15}]
    }],
}

if os.path.isfile(target_file):
    with open(target_file) as f:
        existing = json.load(f)
else:
    existing = {}

if "hooks" not in existing:
    existing["hooks"] = {}

# For each hook event, append entries (avoid duplicates by checking command)
for event, entries in new_hooks.items():
    if event not in existing["hooks"]:
        existing["hooks"][event] = entries
    else:
        existing_cmds = set()
        for rule in existing["hooks"][event]:
            for h in rule.get("hooks", []):
                existing_cmds.add(h.get("command", ""))
        for entry in entries:
            cmds = [h.get("command", "") for h in entry.get("hooks", [])]
            if not any(c in existing_cmds for c in cmds):
                existing["hooks"][event].append(entry)

with open(target_file, "w") as f:
    json.dump(existing, f, indent=2)
    f.write("\n")
PYEOF
}

# --- Helper: append codex-mem section to instruction file ---

append_instructions() {
  local target_file="$1"

  # Generate instructions: heading + blank line + body (skip first 2 lines of instructions.md)
  local section_content
  section_content="$(printf '# Codex-Mem\n\n'; tail -n +3 "$REPO_DIR/plugin/instructions.md")"

  if [ -f "$target_file" ]; then
    # Check if section already exists
    if grep -q "^# Codex-Mem" "$target_file"; then
      echo "    (codex-mem section already present — skipping)"
      return
    fi
    # Append with separator
    printf '\n---\n%s\n' "$section_content" >> "$target_file"
  else
    echo "$section_content" > "$target_file"
  fi
}

# --- Setup functions ---

setup_claude() {
  echo "--- Setting up Claude Code ---"

  if [ "$MODE" = "integrated" ]; then
    # Integrated: merge hooks into project root .claude/settings.json
    mkdir -p "$CONFIG_DIR/.claude"
    merge_hooks_json "$CONFIG_DIR/.claude/settings.json" "$HOOKS_REL"
    echo "  [+] .claude/settings.json (hooks merged at project root)"

    # Append instructions to project root CLAUDE.md
    append_instructions "$CONFIG_DIR/CLAUDE.md"
    echo "  [+] CLAUDE.md (codex-mem section appended at project root)"

    # Copy slash commands into project root .claude/commands/
    mkdir -p "$CONFIG_DIR/.claude/commands"
    if [ -d "$REPO_DIR/adapters/claude-code/commands" ]; then
      cp "$REPO_DIR/adapters/claude-code/commands/"*.md "$CONFIG_DIR/.claude/commands/" 2>/dev/null || true
      echo "  [+] .claude/commands/ ($(ls "$CONFIG_DIR/.claude/commands/"*.md 2>/dev/null | wc -l | tr -d ' ') commands)"
    fi
  else
    # Standalone: write directly into vault/ (original behavior)
    mkdir -p "$VAULT_DIR/.claude/commands"

    merge_hooks_json "$VAULT_DIR/.claude/settings.json" "$HOOKS_REL"
    echo "  [+] .claude/settings.json (3 hooks)"

    if [ -d "$REPO_DIR/adapters/claude-code/commands" ]; then
      cp "$REPO_DIR/adapters/claude-code/commands/"*.md "$VAULT_DIR/.claude/commands/" 2>/dev/null || true
    fi
    echo "  [+] .claude/commands/ ($(ls "$VAULT_DIR/.claude/commands/"*.md 2>/dev/null | wc -l | tr -d ' ') commands)"

    append_instructions "$VAULT_DIR/CLAUDE.md"
    echo "  [+] CLAUDE.md"
  fi
  echo ""
}

setup_codex() {
  echo "--- Setting up Codex CLI ---"

  # Check if Claude Code is also installed — if so, AGENTS.md just references CLAUDE.md
  local has_claude=false
  for a in "${AGENTS[@]}"; do
    [ "$a" = "claude" ] && has_claude=true
  done

  if [ "$MODE" = "integrated" ]; then
    # Integrated: merge hooks into project root .codex/hooks.json
    mkdir -p "$CONFIG_DIR/.codex"
    merge_hooks_json "$CONFIG_DIR/.codex/hooks.json" "$HOOKS_REL"
    echo "  [+] .codex/hooks.json (hooks merged at project root)"

    if [ "$has_claude" = true ]; then
      echo "@CLAUDE.md" > "$CONFIG_DIR/AGENTS.md"
      echo "  [+] AGENTS.md (references @CLAUDE.md)"
    else
      append_instructions "$CONFIG_DIR/AGENTS.md"
      echo "  [+] AGENTS.md (codex-mem section appended at project root)"
    fi
  else
    # Standalone: write directly into vault/ (original behavior)
    mkdir -p "$VAULT_DIR/.codex"

    merge_hooks_json "$VAULT_DIR/.codex/hooks.json" "$HOOKS_REL"
    echo "  [+] .codex/hooks.json (3 hooks)"

    if [ "$has_claude" = true ]; then
      echo "@CLAUDE.md" > "$VAULT_DIR/AGENTS.md"
      echo "  [+] AGENTS.md (references @CLAUDE.md)"
    else
      append_instructions "$VAULT_DIR/AGENTS.md"
      echo "  [+] AGENTS.md"
    fi
  fi
  echo ""
}

# --- Run setup for each detected agent ---

for agent in "${AGENTS[@]}"; do
  "setup_$agent"
done

# --- Done ---

echo "=== Done ==="
echo ""

if [ "$MODE" = "integrated" ]; then
  echo "Vault created at: $VAULT_DIR"
  echo "Hooks registered at: $CONFIG_DIR/"
  echo ""
  echo "Next steps:"
  echo "  cd $PROJECT_DIR"
  for agent in "${AGENTS[@]}"; do
    case $agent in
      claude) echo "  claude                  # hooks + vault work out of the box" ;;
      codex)  echo "  codex                   # hooks + vault work out of the box" ;;
    esac
  done
else
  echo "Your vault is ready at: $VAULT_DIR"
  echo ""
  echo "Next steps:"
  echo "  cd $VAULT_DIR"
  for agent in "${AGENTS[@]}"; do
    case $agent in
      claude) echo "  claude                  # start with Claude Code" ;;
      codex)  echo "  codex                   # start with Codex CLI" ;;
    esac
  done
fi

echo ""
echo "  Fill in brain/North Star.md with your goals, then start talking."
