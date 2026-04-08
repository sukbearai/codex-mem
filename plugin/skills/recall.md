---
name: recall
description: "Search vault memory for a topic — finds relevant notes across brain, work, reference, and sources. Triggers: 'recall', 'what do I know about', 'search memory', 'find notes about', 'look up'."
license: MIT
metadata:
  author: sukbearai
  version: "1.1.0"
  homepage: "https://github.com/sukbearai/codex-vault"
---

Search the vault for information about the given topic.

### Step 0: Context Check
Confirm session-start context is loaded (North Star, recent changes). If first vault skill use this session, read `work/Index.md` and `SCHEMA.md`.

### 1. Parse the Query

Extract the key topic or question from the user's input.

### 2. Search the Vault

Two-pass search — semantic first, keyword fallback:

**Pass 1 — Frontmatter scan (semantic):**
Read the first 5 lines (YAML frontmatter) of every `.md` file in the vault. Use the `description` and `tags` fields to judge relevance semantically — match by meaning, not just keywords. For example, a query about "caching" should match a note with description "Redis selection for session storage".

Scan in priority order:
1. `brain/` — persistent memory
2. `work/active/` — current projects
3. `reference/` — saved analyses
4. `work/archive/` — completed work
5. `sources/` — raw source documents

**Pass 2 — Keyword grep (fallback):**
If Pass 1 finds fewer than 2 relevant files, supplement with a keyword grep across file contents.

### 3. Read Matches

Read the top 3-5 relevant files in full. Prioritize files where the topic appears in:
- The description or tags (strongest signal)
- Headings
- Multiple times in the body

### 4. Synthesize

Present what the vault knows about this topic:
- **Found in**: list the files (as [[wikilinks]])
- **Summary**: synthesize the relevant information across all matches
- **Connections**: note any links between the matched notes
- **Gaps**: flag if the vault has limited or no information on this topic

### 5. Writeback Decision

After synthesizing, evaluate whether the answer is worth saving as a reference note.

**Save** (create `reference/` note) when any one condition is met:
- Comparison: the answer compares 3+ entities or concepts side-by-side
- Deep synthesis: the answer draws from 5+ vault pages
- Novel connection: the answer reveals a cross-domain link not obvious in any single page
- High reconstruction cost: re-deriving the answer would require reading 5+ pages

**Do not save** when:
- Simple lookup: the answer comes directly from 1-2 pages with no synthesis
- Redundant: the answer largely duplicates an existing page
- Ephemeral: the question is one-off and the answer will not be reused

**When saving:**
1. Create a reference note in `reference/` using the Reference Note template
2. Fill `synthesized_from` in frontmatter with the list of vault pages used
3. In related work notes, add a [[wikilink]] to the new reference note under `## Related`
4. Update `work/Index.md` under the `## Reference` section
5. Append to `log.md`: `## [YYYY-MM-DD] query | <question summary> → saved to reference/<note>`

**When not saving:**
- Append to `log.md`: `## [YYYY-MM-DD] query | <question summary> → answered inline`

Topic to recall:
$ARGUMENTS
