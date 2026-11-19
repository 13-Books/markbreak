# MarkBreak — Specification (0.6.0)

**Product:** [MarkBreak](https://markbreak.com) — print manuscript profile for Pandoc Markdown.  
**Writer:** [markbreak.app](https://markbreak.app) emits this profile; it is not a second dialect.

**Why:** Print authors need an enforceable Markdown contract for **roles** and **flow breaks**.

**Normative intent:** a MarkBreak manuscript MUST round-trip through Pandoc to Docx with hard flow breaks intact, SHOULD carry YAML `role` into the Pandoc AST, and SHOULD remain readable as ordinary Markdown where unknown lines are ignored.

This is a **profile** of Pandoc Markdown, not a rival language. See [Purpose](README.md#Purpose).

**RigWorks:** Portable meaning uses `rig.media.code`, `rig.story.flow` `role`, and `rig.story.paragraph` `breakType`. Publication facts live in `meta.md`. Trim, margins, and type size live in the RigWorks layout file named by `layout`. The chapter does not carry them. The writer (`markbreak.app`) copies that page into Docx and PDF. The reference filter rejects absolute and `..` paths for `meta`, `layout`, and `spine`; it does not invent a page size or render the layout. See [rig.works](http://www.rig.works/) and example `fixtures/markbreak-chapter.rig.json`.

## 1. File shape

A book MAY be:

1. **One file** — single `.md` with YAML front matter, or  
2. **Many files** — the root manuscript lists them in `spine` (§2). The reference filter concatenates that list.

Chapter files SHOULD use a numeric prefix for stable sort (`01-title.md`, `02-genesis.md`).

## 2. Front matter (YAML-first)

YAML front matter MUST be valid YAML between `---` fences at the start of the root manuscript (or root concat output).

Recommended keys on the **root** manuscript:

```yaml
---
role: toc
meta: meta.md
layout: layout.rig.json
spine:
  - { file: "00-dedication.md", role: dedication }
  - { file: "01-genesis.md", role: chapter }
  - { file: "99-epilog.md", role: epilog }
---
```

A file listed in `spine` (or any single chapter file) carries only its own role:

```yaml
---
title: "Genesis"
role: chapter
---
```

`meta.md` holds the publication record. Its body may be empty.

```yaml
---
title: "Commit Don't Push"
subtitle: "Gates over Gospel"
author: "Author Name"
language: en
isbn13: "9780000000002"
publisher: "Press Name"
---
```

A file processed on its own is its own root and may carry `meta` / `layout`. A file listed in a `spine` carries only `role` and MUST NOT carry its own `spine`.

- `role` — print role for **this file** (see §3). One file, one role. The JSON field is `rig.story.flow` `role`.
- `meta` — optional path to the publication file, relative to the root manuscript. Absolute paths and `..` fail (reference filter). That file holds `title`, `subtitle`, `author`, `language`, `isbn13`, and `publisher`. It does not hold margins or type size.
- `layout` — optional path to a RigWorks layout document, relative to the root manuscript. Absolute paths and `..` fail (reference filter). The page there holds trim and margins. A paragraph style there holds `fontSize` and `leading`. No layout file means the writer does not invent a page size. Copying that page into Docx and PDF is the writer’s job, not the reference filter’s.
- `spine` — optional ordered file list for multi-file books; each entry SHOULD include `role`. When `spine` is non-empty, the reference filter concatenates it in one Pandoc pass. Paths are relative to the root manuscript’s directory; absolute paths and `..` fail. A non-empty root body is wrapped with this file’s `role` and comes first. Each entry’s body follows, in list order, as its own role Div (a sibling, not nested in the root Div). An entry’s `role` and that file’s YAML `role` MUST match when both are set; if neither is set, processing fails. A spine file MUST NOT contain its own `spine`. Child YAML MUST NOT replace the root manuscript’s other meta. Flow breaks inside an entry obey §5.
- Unknown keys MUST be preserved when the underlying Pandoc path preserves them.

## 3. Roles (semantic structure)

Markdown headings alone do not say *why* a block exists. MarkBreak labels print roles in YAML.

### 3.1 Closed vocabulary

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

### 5.1 Default

On its own line, surrounded by blank lines:

```markdown
//break
```

This is the normal advance. The reference filter emits a Docx column break (`w:br` with `w:type="column"`). In a one-column section, Word shows that as a new page. In a multi-column section, it advances to the next column.

For TeX, the filter emits `\columnbreak` when that command exists, and `\newpage` otherwise.

### 5.2 Forced page

On its own line, surrounded by blank lines:

```markdown
//break page
```

Compliant processors MUST treat this as a Docx page break (`w:br` with `w:type="page"`). TeX output is `\newpage`.

Processors MUST also treat raw `\newpage` and `\pagebreak` as this forced page.

### 5.3 Page side (gated)

On their own line, surrounded by blank lines:

| Authoring | Intent | Docx gate | TeX |
|-----------|--------|-----------|-----|
| `//break odd` | Force odd (recto) page | `w:type w:val="oddPage"` section mark | `\cleardoublepage` |
| `//break even` | Force even (verso) page | `w:type w:val="evenPage"` section mark | best-effort clear-to-even |

Processors MUST also accept raw `\columnbreak` as `//break`, and raw `\cleardoublepage` as `//break odd`.

### 5.4 Forbidden as hard break

- `---` / `***` / `___` thematic breaks  
- A heading alone (layout MAY start chapters on new pages; that is fulfillment, not dialect)

### 5.5 Form feed

Processors MAY accept a form-feed-only paragraph (`\f`) as `//break`. Authors SHOULD prefer `//break`.

### 5.6 Docx requirement

With `bash tools/verify.sh`:

- each `//break` MUST produce a Word column break (`w:type="column"`) in document order
- each `//break page` and each raw `\newpage` MUST produce a Word page break (`w:type="page"`) in document order
- `fixtures/break-overrides.md` MUST produce at least one `w:type="column"`, one `w:type="page"`, one `oddPage`, and one `evenPage` mark

## 6. Thematic breaks

`---` / `***` / `___` mean **scene or section pause**, not a new page. Print layout MAY render them as ornaments or space.

## 7. Body elements (inherited)

Unless this spec forbids them, Pandoc Markdown body forms are allowed: paragraphs, emphasis, strong, links, block quotes, fenced code, lists, tables, footnotes (if enabled).

Books SHOULD keep tables simple. Tables MAY calculate (§8).

## 8. Tables and calculations

A table cell is either a **literal** or a **calculation**. That difference is the whole dialect here; there is no third kind of cell.

### 8.1 Literal or calculation

- A cell whose trimmed text starts with `=` is a **calculation**. The `=` MUST be the first character and the formula MUST be the whole cell.
- Every other cell is a **literal**, including numbers. A literal is never re-interpreted as a formula.
- A cell starting `'=…` is a literal starting with `=`; the apostrophe is not printed. A formula written as a lone code span is likewise a literal.

```markdown
| Item | Qty | Price | Line total |
|------|-----|-------|------------|
| Apples | 2 | 3 | =C2*C3 |
| Pears | 4 | 5 | =@Qty*@Price |
```

### 8.2 References (column first)

References are written **column, then row** — the Excel A1 order, with explicit `C` / `R` markers instead of a column letter, so a column wider than `Z` and a header rename cannot silently change the meaning.

| Reference | Meaning |
|-----------|---------|
| `C2` | Column 2, **same row** as the formula |
| `C2R4` | Column 2, row 4 |
| `R4C2` | Accepted alias for `C2R4`; authors SHOULD write the `CR` form |
| `@Qty` | Column headed `Qty`, same row |
| `@{Unit Price}` | Column whose header contains spaces, same row |
| `@QtyR4` / `@{Unit Price}R4` | Headed column, row 4 |
| `@Apples` | Row whose first cell is `Apples`, as a function argument |
| `@Qty@Apples` / `C2@Apples` | Named or numbered column, row named `Apples` |
| `@{Cherry picking}` | Row (or column) whose name contains spaces |
| `C2R1:C2R4` | Rectangular range, used as a function argument |
| `SUM(C2)` / `SUM(@Qty)` | Whole body column, as a function argument |
| `SUM(@Apples)` / `SUM(@Apples:@Pears)` | Whole named row, or named rows, as a function argument |

Rules:

- Columns count from `1` at the left, **including** hidden columns (§8.4). Rows count from `1` at the first **body** row; the header row is never numbered and foot rows continue the body numbering.
- A row is named by the text of its first body cell. Names are matched case-insensitively with spaces squeezed; when two rows share a name, the first wins. A formula cell cannot name its row.
- Position decides what an `@name` means: standing alone it is a column if a header matches, otherwise a row; in second position, after a column (`@Qty@Apples`, `C2@Apples`), it is always the row. That keeps `@Qty` meaning what it already meant when a row happens to share the name.
- A bare header name (`Qty*Price`) is accepted and means the same as `@Qty`; authors SHOULD prefer `@`, which cannot be confused with a function name.
- A whole-column reference used outside an aggregate function means the same-row cell. A whole-row reference is only meaningful as a function argument; using one as a scalar operand is `#VALUE!` (§8.5).
- References reach only within their own table. There are no cross-table, cross-file, or sheet references.
- A cell with a column or row span is referenced by its top-left (anchor) column and row.

### 8.3 Operators and functions

Formulas support `+`, `-`, `*`, `/`, `^`, parentheses, unary minus, and a trailing `%` (`50%` is `0.5`). Supported functions are `SUM`, `AVERAGE` (alias `AVG`), `MIN`, `MAX`, `COUNT`, and `PRODUCT`, separated by commas and ranges as in `SUM(C2R1:C2R4, C3R1)`.

Literal numbers MAY carry commas, a leading `$` / `£` / `€`, a trailing `%`, or accounting parentheses for a negative value. Inside a range or whole column, aggregates ignore empty and non-numeric cells; a non-numeric cell used as a scalar operand is an error (§8.5). Results are plain numbers — integers print without a decimal point, other results print with up to ten significant digits. Currency and unit labels belong in the header, not in the result.

### 8.4 What the reader sees; hidden formulas and hidden columns

The calculation is worked out at export, not by Word and not by the reader.

- A compliant processor MUST replace the visible cell with its result. To the reader, a calculated column is an ordinary column of numbers.
- The processor MUST keep the source formula hidden with the result: the reference filter stamps a `data-calc` attribute on the cell (visible in the Pandoc AST and in HTML) and, for Docx, appends the formula as hidden (`w:vanish`) text in the same cell, so import can round-trip it. Hidden text MUST NOT print.
- A **hidden helper column** — a header ending in `(hidden)`, as in `Factor (hidden)` — MUST NOT appear in the exported table, but its cells MAY be referenced like any other column and it still counts in column numbering. Its header is referenced without the suffix (`@Factor`).

### 8.5 Errors

A broken formula MUST NOT abort the export and MUST NOT silently become `0`. The cell shows one of these values instead of a result:

| Value | Cause |
|-------|-------|
| `#DIV/0!` | Division by zero, or `AVERAGE` of no numbers |
| `#VALUE!` | Non-numeric scalar operand, malformed formula, or a range used as a scalar |
| `#REF!` | Reference outside the table, or an unknown header or row name |
| `#NAME?` | Unknown function or name |
| `#CYCLE!` | A cell that depends on itself, directly or through other cells |
| `#NUM!` | A result that is not a finite number |

Live Word fields, string and date arithmetic, comparisons, and `IF` are not part of this section.

## 9. Code

Fenced code blocks are allowed. Print styling is fulfillment. A gate MAY assert fences survive Docx; it NEED NOT assert monospace metrics.

## 10. Explicit non-goals

- HTML-first page CSS as the source of truth  
- Requiring LaTeX as the author format  
- Guaranteeing identical line breaks across engines (only **flow** breaks are dialect-mandatory)  
- A distinct frame-break token  
- DITA-style rhetorical typing (claim / evidence / aside as KM types)

## 11. Conformance

A processor is **MarkBreak Docx-conformant (0.6.0)** if `bash tools/verify.sh` exits 0 against:

- `fixtures/minimal-pagebreak.md`
- `fixtures/parts-and-chapters.md`
- `fixtures/roles-and-breaks.md`
- `fixtures/break-overrides.md`
- `fixtures/spine-book/book.md`
- `fixtures/meta-layout/book.md`
- `fixtures/meta-layout-bad/book.md` (MUST fail)
- `fixtures/table-calculations.md` (§8: calculated, literal, escaped, hidden-column, and error cells MUST reach Docx as specified)
