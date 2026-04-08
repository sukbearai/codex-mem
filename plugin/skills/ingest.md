---
name: ingest
description: "Import external content (URLs, files, text) into the vault as structured source notes. Triggers: 'ingest', 'import this', 'save this article', 'add source', 'read and save'."
license: MIT
metadata:
  author: sukbearai
  version: "1.1.0"
  homepage: "https://github.com/sukbearai/codex-vault"
---

Ingest a source into the vault. Follow these steps:

### Step 0: Context Check
Confirm session-start context is loaded (North Star, recent changes). If first vault skill use this session, read `work/Index.md` and `SCHEMA.md`.

### 1. Locate the Source

The user provides either:
- A filename in `sources/` (e.g., `sources/karpathy-llm-wiki.md`)
- A URL to fetch (use `defuddle parse <url> --md` or `curl` to save to `sources/` first)

If a URL, save the raw content to `sources/` before proceeding — sources are the immutable record.

### 2. Read the Source

Read the full source document. Do not skim — ingestion depends on thorough reading.

### 3. Discuss Key Takeaways

Present the top 3-5 takeaways to the user. Ask:
- Which points are most relevant to current work?
- Any connections to existing vault notes?
- Anything to skip or emphasize?

Wait for user input before proceeding.

### 4. Contradiction Detection

Before writing the new note, check for contradictions with existing vault content:

1. Search the vault for existing pages related to this source's topics (use `/recall` or search by keywords)
2. Compare key facts, claims, and opinions between the new source and existing notes
3. If contradictions are found:
   - In the new note's frontmatter, add `contradictions: ["Contradicting Page Name"]`
   - In each contradicting page's frontmatter, also add `contradictions: ["New Note Name"]` (bidirectional marking)
   - In the new note's body, note the contradiction explicitly — preserve both positions with their dates and sources
   - Do not silently overwrite old information
4. If no contradictions are found, proceed normally

### 5. Create a Source Summary

Create a note in `work/active/` using the **Source Summary** template:
- Fill in all YAML frontmatter (date, description, tags, type: source-summary)
- Set `source` to the file in `sources/` or the original URL
- If the note draws from vault documents, add `sources: [path/to/source.md]` listing the vault paths
- Include `contradictions` field if step 4 found any
- Write Key Takeaways, Summary, Connections (with [[wikilinks]]), Quotes/Data Points

### 6. Update Indexes

- Add the summary to `work/Index.md` under a "Sources" section (create the section if it doesn't exist)
- Update relevant `brain/` notes if the source contains decisions (`Key Decisions.md`), patterns (`Patterns.md`), or context worth remembering (`Memories.md`)

### 7. Cross-Link

Check existing vault notes for connections:
- Do any active projects relate to this source?
- Does the source reinforce or challenge any existing decisions?
- Add [[wikilinks]] in both directions where relevant

### 8. Report

Summarize what was done:
- Source file location
- Summary note created (path)
- Indexes updated
- Cross-links added
- Contradictions found (if any) — list the pages and the nature of the contradiction
- Brain notes updated (if any)

---

## Batch Ingest Mode

When the user provides multiple sources (multiple URLs, multiple files, or several unprocessed files in `sources/`), use this batch flow instead of repeating the single-source steps for each one.

### 1. Read All Sources

Read every source document in full before creating any notes.
- For each source, record: title, key entities/concepts, main claims.

### 2. Cross-Source Deduplication

Identify shared entities and concepts across all sources:
- List every entity/concept mentioned across the sources.
- Mark overlaps — an entity appearing in multiple sources gets higher page-creation priority.
- Mark contradictions — different sources making different claims about the same fact.

### 3. Single Search Pass

Check the vault once for all identified entities:
- Scan `work/Index.md` and the file system.
- For each entity, determine: create new page, or update existing page.
- Do not run N separate searches for N sources.

### 4. Batch Write

Create and update pages in one pass:
- Each source gets its own Source Summary in `work/active/`.
- Shared entities: merge information into a single page, citing multiple sources.
- Contradictions: apply the Contradiction Detection rules (step 4 of single-source flow) — mark bidirectionally.

### 5. Single Index Update

After all pages are written, update `work/Index.md` once.
- Do not update the index after each individual note.

### 6. Single Log Entry

Write one batch log entry:
- Format: `## [YYYY-MM-DD] ingest | Batch ingest N sources — X new, Y updated`

### 7. Report

Give the user a summary:
- Number of sources processed
- New notes created (list with paths)
- Existing notes updated (list with paths)
- Contradictions found (if any)
- Cross-source connections (concepts appearing in multiple sources)

Source to process:
$ARGUMENTS
