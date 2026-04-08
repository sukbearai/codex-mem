---
name: wrap-up
description: "End-of-session wrap-up — commits changes, updates indexes, captures decisions made. Triggers: 'wrap up', 'end session', 'save progress', 'commit and close', 'done for today'."
license: MIT
metadata:
  author: sukbearai
  version: "1.0.0"
  homepage: "https://github.com/sukbearai/codex-vault"
---

Session wrap-up. Review what was done and leave the vault clean.

### Step 0: Context Check
Confirm session-start context is loaded (North Star, recent changes). If first vault skill use this session, read `work/Index.md` and `SCHEMA.md`.

### 1. Review
Scan the conversation for notes created or modified. List them all.

### 2. Verify Quality
For each note: frontmatter complete? At least one [[wikilink]]? Correct folder?

### 3. Check Indexes
- `work/Index.md` — new notes linked? Completed projects moved?
- `brain/Memories.md` — Recent Context updated?
- `brain/Key Decisions.md` — new decisions captured?
- `brain/Patterns.md` — new patterns observed?

### 4. Check for Orphans
Any new notes not linked from at least one other note?

### 5. Archive Check
Notes in `work/active/` that should move to `work/archive/`? When archiving:

1. Move the completed note from `work/active/` to `work/archive/`
2. Search the vault for all `[[wikilinks]]` referencing the archived note
3. Update link paths if needed (filename-only links usually need no change)
4. In `work/Index.md`, move the entry from the Active section to the Archive section
5. If a page is fully abandoned (not just completed), replace its inbound wikilinks with plain text + "(archived)"

### 6. Report
- **Done**: what was captured
- **Fixed**: issues resolved
- **Flagged**: needs user input
- **Suggested**: improvements for next time

### 7. Suggest Lint
If this session created or modified 3 or more notes, suggest running `/lint` for a full vault health check.
