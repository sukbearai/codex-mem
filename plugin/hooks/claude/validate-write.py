#!/usr/bin/env python3
"""Post-write validation for vault notes — Claude Code version.

Checks frontmatter and wikilinks on any .md file written to the vault.
Outputs hookSpecificOutput with systemMessage for Claude Code terminal display.
"""
import json
import re
import sys
import os
from pathlib import Path


def _check_log_format(content):
    """Validate log.md entry format: ## [YYYY-MM-DD] <type> | <title>"""
    warnings = []
    for i, line in enumerate(content.splitlines(), 1):
        if line.startswith("## ") and not line.startswith("## ["):
            # Heading that looks like a log entry but missing date brackets
            if any(t in line.lower() for t in ["ingest", "session", "query", "maintenance", "decision", "archive"]):
                warnings.append(f"Line {i}: log entry missing date format — expected `## [YYYY-MM-DD] <type> | <title>`")
        elif line.startswith("## ["):
            if not re.match(r"^## \[\d{4}-\d{2}-\d{2}\] \w+", line):
                warnings.append(f"Line {i}: malformed log entry — expected `## [YYYY-MM-DD] <type> | <title>`")
    return warnings




def _find_vault_root():
    """Find vault root from CLAUDE_PROJECT_DIR or CWD."""
    cwd = os.environ.get("CLAUDE_PROJECT_DIR", os.getcwd())
    if os.path.isfile(os.path.join(cwd, "Home.md")) or os.path.isdir(os.path.join(cwd, "brain")):
        return cwd
    vault_sub = os.path.join(cwd, "vault")
    if os.path.isdir(vault_sub) and (
        os.path.isfile(os.path.join(vault_sub, "Home.md")) or
        os.path.isdir(os.path.join(vault_sub, "brain"))
    ):
        return vault_sub
    return None


def _load_tag_whitelist(vault_root):
    """Parse tag names from SCHEMA.md Tag Taxonomy section.

    Returns a set of tag names, or None if SCHEMA.md is missing.
    """
    if not vault_root:
        return None
    schema_path = os.path.join(vault_root, "SCHEMA.md")
    if not os.path.isfile(schema_path):
        return None
    try:
        text = Path(schema_path).read_text(encoding="utf-8")
    except Exception:
        return None

    tags = set()
    in_tags = False
    for line in text.splitlines():
        if re.match(r"^## Tag Taxonomy", line):
            in_tags = True
            continue
        if in_tags and line.startswith("## "):
            break
        if in_tags and re.match(r"^- .+", line):
            # "- tagname — description" or "- tagname"
            tag_part = line[2:].split("—")[0].split("--")[0].strip()
            if tag_part:
                tags.add(tag_part)
    return tags if tags else None


def _parse_frontmatter_tags(fm_text):
    """Extract tags from frontmatter text (supports both list and inline syntax).

    Handles:
      tags: [a, b, c]
      tags:\n  - a\n  - b
    """
    tags = []
    # Inline: tags: [a, b, c]
    m = re.search(r"^tags:\s*\[([^\]]*)]", fm_text, re.MULTILINE)
    if m:
        raw = m.group(1)
        tags = [t.strip().strip('"').strip("'") for t in raw.split(",") if t.strip()]
        return tags

    # Block list: tags:\n  - a\n  - b
    in_tags = False
    for line in fm_text.splitlines():
        if re.match(r"^tags:", line):
            # Check if there's content on same line (tags: foo)
            rest = line.split(":", 1)[1].strip()
            if rest and not rest.startswith("["):
                tags = [rest.strip('"').strip("'")]
                return tags
            in_tags = True
            continue
        if in_tags:
            stripped = line.strip()
            if stripped.startswith("- "):
                tags.append(stripped[2:].strip().strip('"').strip("'"))
            elif stripped and not stripped.startswith("#"):
                break  # End of tags block
    return tags


def main():
    try:
        input_data = json.load(sys.stdin)
    except (ValueError, EOFError, OSError):
        sys.exit(0)

    tool_input = input_data.get("tool_input")
    if not isinstance(tool_input, dict):
        sys.exit(0)

    file_path = tool_input.get("file_path", "")
    if not isinstance(file_path, str) or not file_path:
        sys.exit(0)

    if not file_path.endswith(".md"):
        sys.exit(0)

    normalized = file_path.replace("\\", "/")
    basename = os.path.basename(normalized)

    # Skip non-vault files
    skip_names = {"README.md", "CHANGELOG.md", "CONTRIBUTING.md", "CLAUDE.md", "AGENTS.md", "LICENSE", "SCHEMA.md"}
    if basename in skip_names:
        sys.exit(0)
    if basename.startswith("README.") and basename.endswith(".md"):
        sys.exit(0)

    skip_paths = [".claude/", ".codex/", ".codex-vault/", ".mind/", "templates/", "thinking/", "node_modules/", "plugin/", "docs/"]
    if any(skip in normalized for skip in skip_paths):
        sys.exit(0)

    warnings = []

    try:
        content = Path(file_path).read_text(encoding="utf-8")

        if not content.startswith("---"):
            warnings.append("Missing YAML frontmatter")
        else:
            parts = content.split("---", 2)
            if len(parts) >= 3:
                fm = parts[1]
                if "date:" not in fm and basename != "log.md":
                    warnings.append("Missing `date` in frontmatter")
                if "tags:" not in fm:
                    warnings.append("Missing `tags` in frontmatter")
                if "description:" not in fm:
                    warnings.append("Missing `description` in frontmatter (~150 chars)")

                # Tag whitelist validation (requires SCHEMA.md)
                vault_root = _find_vault_root()
                whitelist = _load_tag_whitelist(vault_root)
                if whitelist is not None:
                    note_tags = _parse_frontmatter_tags(fm)
                    for tag in note_tags:
                        if tag not in whitelist:
                            warnings.append(f"Tag '{tag}' not declared in SCHEMA.md Tag Taxonomy")

                # Type field validation (optional — warn only when present)
                _VALID_TYPES = {'work', 'decision', 'source-summary', 'reference', 'thinking'}
                type_match = re.search(r'^type:\s*(.+)', fm, re.MULTILINE)
                if type_match:
                    type_val = type_match.group(1).strip().strip('"').strip("'")
                    if type_val and type_val not in _VALID_TYPES:
                        warnings.append(f"Type '{type_val}' not in allowed values: {', '.join(sorted(_VALID_TYPES))}")

        if len(content) > 300 and "[[" not in content:
            warnings.append("No [[wikilinks]] found — every note should link to at least one other note")

        # Check for unfilled template placeholders
        placeholders = re.findall(r"\{\{[^}]+\}\}", content)
        if placeholders:
            examples = ", ".join(placeholders[:3])
            warnings.append(f"Unfilled template placeholders found: {examples}")

        # Validate log.md format
        if basename == "log.md":
            log_warnings = _check_log_format(content)
            warnings.extend(log_warnings)

    except Exception:
        sys.exit(0)

    if warnings:
        hint_list = "\n".join(f"  - {w}" for w in warnings)
        count = len(warnings)
        first = warnings[0]
        if count == 1:
            feedback = f"\u26a0\ufe0f  vault: {basename} — {first}"
        else:
            feedback = f"\u26a0\ufe0f  vault: {basename} — {first} (+{count - 1} more)"

        # Hook trigger notification
        print(f"  {feedback}")

        output = {
            "hookSpecificOutput": {
                "hookEventName": "PostToolUse",
                "additionalContext": f"Vault warnings for `{basename}`:\n{hint_list}\nFix these before moving on."
            },
            "systemMessage": feedback
        }
        json.dump(output, sys.stdout)
        sys.stdout.flush()

    sys.exit(0)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        sys.exit(0)
