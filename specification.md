# MarkBreak — Specification (0.3.0)

**Product:** [MarkBreak](https://markbreak.com) — print manuscript profile for Pandoc Markdown.  
**Writer:** [markbreak.app](https://markbreak.app) emits this profile; it is not a second dialect.

**Why:** Print authors need an enforceable Markdown contract for **roles** and **flow breaks**.

**Normative intent:** a MarkBreak manuscript MUST round-trip through Pandoc to Docx with hard flow breaks intact, SHOULD carry YAML `role` into the Pandoc AST, and SHOULD remain readable as ordinary Markdown where unknown lines are ignored.

This is a **profile** of Pandoc Markdown, not a rival language. See [Why](README.md#Why).

**RigWorks:** Portable meaning uses `rig.media.code` + `rig.story.flow.role` + `rig.story.paragraph.breakType`. See [rig.works](http://www.rig.works/) and example `markbreak-chapter.json`.

## 1. File shape

A book MAY be:

1. **One file** — single `.md` with YAML front matter, or  
2. **Many files** — the root manuscript lists them in `spine` (§2). The reference filter concatenates that list.

Chapter files SHOULD use a numeric prefix for stable sort (`01-title.md`, `02-genesis.md`).

## 2. Front matter (YAML-first)

YAML front matter MUST be valid YAML between `---` fences at the start of the root manuscript (or root concat output).

Recommended keys:

```yaml
---
title: "Commit Don't Push"
subtitle: "Gates over Gospel"
author: "Author Name"
rights: "All rights reserved"
lang: en-US
role: chapter
spine:
  - { file: "00-dedication.md", role: dedication }
  - { file: "01-genesis.md", role: chapter }
  - { file: "99-epilog.md", role: epilog }
---
```

- `role` — print role for **this file** (see §3). One file, one role.
- `spine` — optional ordered file list for multi-file books; each entry SHOULD include `role`. When `spine` is non-empty, the reference filter concatenates it in one Pandoc pass. Paths are relative to the root manuscript’s directory; absolute paths and `..` fail. A non-empty root body is wrapped with this file’s `role` and comes first. Each entry’s body follows, in list order, as its own role Div (a sibling, not nested in the root Div). An entry’s `role` and that file’s YAML `role` MUST match when both are set; if neither is set, processing fails. A spine file MUST NOT contain its own `spine`. Child YAML MUST NOT replace the root manuscript’s other meta. Flow breaks inside an entry obey §5.
- Unknown keys MUST be preserved when the underlying Pandoc path preserves them.

## 3. Roles (semantic structure)

Markdown headings alone do not say *why* a block exists. MarkBreak labels print roles in YAML.

### 3.1 Closed vocabulary (0.2.0)

`dedication` · `epigraph` · `preface` · `part` · `chapter` · `appendix` · `epilog` · `afterword` · `colophon` · `toc` (optional stub)

Unknown `role` values: processors MUST preserve them and MUST NOT invent layout.

### 3.2 Export

Compliant processors MUST expose each known file-level `role` as a Pandoc Div (or equivalent) with attribute/class `role=<value>` wrapping that file’s body (or the spine entry’s body after concat).

## 4. Structure (headings)

| Level | Role |
|-------|------|
| `#` | Book title (at most one near the start) OR part / book division |
| `##` | Chapter |
| `###` | Section within a chapter |
| `####`+ | Optional finer structure; print styles MAY collapse them |

Parts SHOULD be titled like `# Book I - Genesis` or `# Part I - The wound`.

Heading level is hierarchy. YAML `role` is **semantic**. They cooperate; neither replaces the other.

## 5. Flow breaks (the load-bearing rule)

A **flow break** advances the story. In a layout with **no columns**, that is a **page break**. If fulfillment uses columns, the same default break advances to the next column/frame of flow. Authors only name a break type when they need a different advance.

There is **no** distinct `frame` break token — the default break *is* frame-advance unless overridden.

### 5.1 Default (canonical)

On its own line, surrounded by blank lines:

```markdown
\newpage
```

Compliant processors MUST treat this as a Docx page break (`w:br` with `w:type="page"`) via the reference filter (or equivalent OpenXML).

### 5.2 Authoring aliases (normative)

These MUST normalize to `\newpage` before or during the reference toolchain:

- `//---` (processors MUST also accept the smart-typography form `//—`)
- `//break`

### 5.3 Overrides (gated)

On their own line, surrounded by blank lines:

| Authoring | Intent | Docx gate | TeX |
|-----------|--------|-----------|-----|
| `//break column` | Force column | `w:br` `w:type="column"` | `\columnbreak` |
| `//break odd` | Force odd (recto) page | `w:type w:val="oddPage"` section mark | `\cleardoublepage` |
| `//break even` | Force even (verso) page | `w:type w:val="evenPage"` section mark | best-effort clear-to-even |

Processors MUST also accept TeX forms `\columnbreak` and `\cleardoublepage` as column and odd overrides when present as raw TeX.

### 5.4 Forbidden as hard break

- `---` / `***` / `___` thematic breaks  
- A heading alone (layout MAY start chapters on new pages; that is fulfillment, not dialect)

### 5.5 Form feed

Processors MAY accept a form-feed-only paragraph (`\f`) as a default flow break. Authors SHOULD prefer `\newpage` or `//---`.

### 5.6 Docx requirement

With `bash tools/verify.sh`:

- each default flow break MUST produce at least one Word page break (`w:type="page"`) in document order  
- `fixtures/break-overrides.md` MUST produce at least one `w:type="column"`, one `oddPage`, and one `evenPage` mark

## 6. Thematic breaks

`---` / `***` / `___` mean **scene or section pause**, not a new page. Print layout MAY render them as ornaments or space.

## 7. Body elements (inherited)

Unless this spec forbids them, Pandoc Markdown body forms are allowed: paragraphs, emphasis, strong, links, block quotes, fenced code, lists, tables, footnotes (if enabled).

Books SHOULD keep tables simple.

## 8. Code

Fenced code blocks are allowed. Print styling is fulfillment. A gate MAY assert fences survive Docx; it NEED NOT assert monospace metrics.

## 9. Explicit non-goals

- HTML-first page CSS as the source of truth  
- Requiring LaTeX as the author format  
- Guaranteeing identical line breaks across engines (only **flow** breaks are dialect-mandatory)  
- A distinct frame-break token  
- DITA-style rhetorical typing (claim / evidence / aside as KM types)

## 10. Conformance

A processor is **MarkBreak Docx-conformant (0.3.0)** if `bash tools/verify.sh` exits 0 against:

- `fixtures/minimal-pagebreak.md`
- `fixtures/parts-and-chapters.md`
- `fixtures/roles-and-breaks.md`
- `fixtures/break-overrides.md`
- `fixtures/spine-book/book.md`
