# MarkBreak

**Version 0.7.0.**

MarkBreak is a profile of [Pandoc Markdown](https://pandoc.org/MANUAL.html#pandocs-markdown). A MarkBreak document is a Pandoc Markdown document. This profile adds print roles, a spine of files, a publication file, a layout file, flow breaks, and tables that calculate. A construct this profile does not define stays Pandoc Markdown.

The words MUST, MUST NOT, REQUIRED, SHALL, SHALL NOT, SHOULD, SHOULD NOT, RECOMMENDED, MAY, and OPTIONAL in this document are to be interpreted as in [RFC 2119](https://datatracker.ietf.org/doc/html/rfc2119).

## 1. Preliminaries

### 1.1 Lines

A **line** ends at a line feed (U+000A) or at the end of the file. A **blank line** contains no characters, or only spaces (U+0020) and tabs (U+0009).

### 1.2 Manuscripts

A **manuscript** is one Markdown file, or one CSV file given alone as the root input (§8.6).

The **root manuscript** is the file given to a processor. A file processed on its own is its own root.

A **book** is the root manuscript together with the files named in its spine, when it has one. A spine entry may be Markdown or CSV (§5, §8.6).

Markdown files of a book SHOULD use a numeric prefix so a directory listing matches reading order (`01-title.md`, `02-genesis.md`). CSV files SHOULD use a clear name (`prices.csv`). The name is a filing habit. The spine is the order.

### 1.3 Paths

A path in `meta`, `layout`, or a spine `file` is relative to the directory that contains the root manuscript.

A processor MUST reject a path that is absolute or that contains a `..` segment. A path is absolute when it begins with `/` or `\`, or with a drive letter, `:`, and then `/` or `\`.

A spine `file` MUST name a readable file. Otherwise processing MUST fail.

### 1.4 Processors

A **processor** reads a manuscript and produces an output.

The **reference filter** is `tools/markbreak.lua`. It checks the paths in §1.3, resolves roles and the spine, applies table calculations (§8), and emits flow breaks. It does not open the publication file or the layout file. It does not invent a page size.

A **writer** MAY read those files and apply them when it produces Docx or PDF.

Docx conformance is defined in §11.

## 2. Metadata

### 2.1 Front matter

A Markdown manuscript MAY begin with Pandoc YAML metadata: a line containing only `---`, a YAML mapping, and a closing line containing only `---` or `...`. The YAML MUST parse.

The root manuscript's metadata is the metadata of the book. A CSV file has no front matter (§8.6).

### 2.2 Keys

This profile defines four keys.

| Key | Allowed on | Section |
|-----|------------|---------|
| `role` | any Markdown manuscript | §3 |
| `meta` | the root manuscript | §2.3 |
| `layout` | the root manuscript | §2.4 |
| `spine` | the root manuscript | §5 |

A key this profile does not define MUST be left as Pandoc delivered it. A processor MUST NOT give such a key a meaning of its own.

A file named in `spine` MUST NOT itself contain `spine`. Processing MUST fail if it does. Other keys on that file, such as `title`, are allowed. They MUST NOT replace the root manuscript's metadata.

### 2.3 Publication file

`meta` is the path of the **publication file**. That file is Markdown with YAML front matter. Its body MAY be empty.

The publication facts are `title`, `subtitle`, `author`, `language`, `isbn13`, and `publisher`. Trim, margins, type size, and leading are not publication facts.

**Example 1.** A publication file.

````markdown
---
title: "Commit Don't Push"
subtitle: "Gates over Gospel"
author: "Author Name"
language: en
isbn13: "9780000000002"
publisher: "Press Name"
---
````

The reference filter checks the path and leaves the keys where they are. A writer MAY copy them into an output.

### 2.4 Layout file

`layout` is the path of the **layout file**.

The layout file holds the page and the body type. The page is the trim and the margins. The body type is the type size and the leading. A chapter manuscript does not carry those values.

If `layout` is absent, a processor MUST NOT invent a page size.

The reference filter checks the path. It does not read the file. A writer MAY apply the page and the body type when it writes Docx or PDF.

Appendix A names one format a writer may find there. That format is not part of this profile.

## 3. Roles

### 3.1 What a role is

`role` is one scalar string: the print function of that manuscript. A manuscript has at most one role.

Heading level and role are different facts. Heading level is the outline. Role is the function of the file. A processor MUST NOT infer a role from a heading. A processor MUST NOT infer a heading level from a role.

### 3.2 Vocabulary

The known roles are these strings, matched exactly:

`dedication` · `epigraph` · `preface` · `part` · `chapter` · `appendix` · `epilog` · `afterword` · `colophon` · `toc`

`toc` marks a contents file. This profile does not require a processor to build a table of contents.

### 3.3 Values outside the vocabulary

A `role` other than the strings in §3.2 MUST be kept as written. A processor MUST NOT invent layout from it.

### 3.4 In the output

When a manuscript has a role, a processor MUST wrap that manuscript's body in a Pandoc `Div` whose class is the role and whose attribute `role` is the role.

In a book with a spine, each file's `Div` is a sibling. A later file is not nested inside an earlier one.

**Example 2.** One file, one role.

````markdown
---
title: "Commit Don't Push"
role: epilog
---

# After the gates
````

The body is a `Div` with `role=epilog`. A second role is a second file.

The `Div` is the required representation. On formats that drop `Div` attributes, the role still has to be recoverable. The reference filter writes an empty Docx paragraph with the paragraph style `Role <role>`. Other recoveries are described in Appendix B.

## 4. Headings

Headings are Pandoc Markdown headings. Authors use the levels as follows.

| Level | Use |
|-------|-----|
| `#` | Book title, at most one near the start, or a part |
| `##` | Chapter |
| `###` | Section within a chapter |
| `####` and below | Finer structure. A print style MAY collapse these levels. |

A part title SHOULD look like `# Book I - Genesis` or `# Part I - The wound`.

This table is a convention for authors. It does not change §3. A processor MUST NOT read a role off a heading level.

## 5. Spine

`spine` is an ordered list of files. Each entry is a mapping:

| Field | Required | Meaning |
|-------|----------|---------|
| `file` | yes | path of the file, under the rules in §1.3 |
| `role` | no | role of that file; SHOULD be set |

An entry that is not a mapping, or a mapping with no `file`, MUST fail processing.

When `spine` is absent or empty, the book is the root manuscript alone.

When `spine` is not empty, a processor MUST produce one document, in this order:

1. The root body, if it is not empty. When the root manuscript has a role, that body is wrapped in the root role. When it has no role, the body is included as it stands.
2. Each spine entry, in list order. Markdown entries are parsed as Markdown; their flow breaks follow §6. CSV entries are read as tables (§8.6). Each entry's body is wrapped in one role `Div`.

The role of an entry is chosen as follows:

| Spine `role` | File `role` | Result |
|--------------|-------------|--------|
| set | set to the same string | that string |
| set | set to a different string | processing MUST fail |
| set | absent | the spine role |
| absent | set | the file role |
| absent | absent | processing MUST fail |

A CSV spine entry has no YAML. Its `role` MUST come from the spine entry.

**Example 3.** A root manuscript.

````markdown
---
role: toc
meta: meta.md
layout: layout.rig.json
spine:
  - { file: "00-dedication.md", role: dedication }
  - { file: "01-genesis.md", role: chapter }
  - { file: "prices.csv", role: chapter }
---

# Contents

The root body keeps this file's role.
````

**Example 4.** A Markdown file named by that spine.

````markdown
---
title: "Genesis"
role: chapter
---

# Genesis

Chapter body.
````

The result of Example 3, with Example 4, a dedication file, and `prices.csv`, is four sibling `Div`s: `toc`, then `dedication`, then `chapter`, then `chapter` again for the CSV table.

## 6. Flow breaks

### 6.1 Meaning

A **flow break** ends the current place in the story and advances to the next place the text can continue.

With one column, the next place is the next page. With more than one column, the normal advance goes to the next column. An author writes a more specific break only when a different advance is required.

The normal advance is the advance to the next frame of the flow. This profile has no separate frame-break token.

### 6.2 Syntax

A flow break is a paragraph whose text with leading and trailing whitespace removed is exactly one source in the table below.

In Pandoc Markdown a paragraph is separated from surrounding blocks by blank lines. The source therefore stands on a line of its own: a blank line before it when something precedes it, and a blank line after it when something follows it.

| Source | Kind |
|--------|------|
| `//break` | normal advance |
| `//break page` | forced page |
| `//break odd` | next odd page (recto) |
| `//break even` | next even page (verso) |

A processor MUST recognize each row of the table.

A processor MUST also accept the TeX aliases in Appendix B.1. Authors SHOULD write the `//break` forms.

A processor MAY treat a paragraph whose only character is a form feed (U+000C) as a normal advance. Authors SHOULD write `//break`.

These are not flow breaks:

- a thematic break (§7)
- a heading
- a blank line

A layout MAY begin a chapter on a new page. That is a property of the layout. This profile requires an advance only where the manuscript contains a flow break.

CSV files have no flow breaks (§8.6).

### 6.3 Docx

A conformant Docx processor MUST emit one Word mark per flow break, in the same order as the breaks in the manuscript.

| Kind | Word mark |
|------|-----------|
| normal advance | a break `w:br` with `w:type="column"` |
| forced page | a break `w:br` with `w:type="page"` |
| next odd page | a section mark whose type is `oddPage` |
| next even page | a section mark whose type is `evenPage` |

In a one-column Word section, Word displays a column break as a new page. The mark in the file is still a column break. `//break page` is a page break in every section.

**Example 5.** A normal advance.

````markdown
Body before the advance.

//break

Body after the advance.
````

Docx contains a column break between the two paragraphs.

**Example 6.** A forced page, then a side.

````markdown
Body before a forced page.

//break page

Body before an odd page.

//break odd

Body before an even page.

//break even

Body after the even page.
````

Docx contains, in this order, a page break, an `oddPage` section mark, and an `evenPage` section mark.

Behaviour for TeX, HTML, EPUB, and ICML is in Appendix B. It is not part of Docx conformance.

## 7. Thematic breaks

A line containing only `---`, `***`, or `___` is a **thematic break**, as in Pandoc Markdown. It marks a pause in the scene or the section. It is not a flow break. It MUST NOT produce a page break, a column break, or a section mark.

A print layout MAY render a thematic break as an ornament or as space.

**Example 7.** A pause, then a real advance.

````markdown
The scene ends.

---

The next scene.

//break

The next page, in a one-column layout.
````

The thematic break contributes no Word break. The `//break` contributes one column break.

## 8. Tables and calculations

A table cell is either a **literal** or a **calculation**. There is no third kind of cell.

The same rules apply to Markdown tables and to CSV tables (§8.6).

### 8.1 Literal or calculation

- A cell whose trimmed text starts with `=` is a **calculation**. The `=` MUST be the first character. The formula MUST be the whole cell.
- Every other cell is a **literal**, including numbers. A literal is never re-interpreted as a formula.
- A cell that starts with `'=` is a literal that starts with `=`. The leading apostrophe is not printed. A formula written as a lone code span is likewise a literal.

**Example 8.** A Markdown table with calculations.

````markdown
| Item | Qty | Price | Line total |
|------|-----|-------|------------|
| Apples | 2 | 3 | =C2*C3 |
| Pears | 4 | 5 | =@Qty*@Price |
| Total | =SUM(C2R1:C2R2) | | =SUM(C4R1:C4R2) |
````

Export shows these visible values. The formulas stay hidden with the cells (§8.4).

| Item | Qty | Price | Line total |
|------|-----|-------|------------|
| Apples | 2 | 3 | 6 |
| Pears | 4 | 5 | 20 |
| Total | 6 | | 26 |

### 8.2 References

References are written **column, then row**. Columns use `C` and an index. Rows use `R` and an index. That order matches ordinary spreadsheet cells, without a letter that runs out after `Z`.

| Reference | Meaning |
|-----------|---------|
| `C2` | Column 2, same row as the formula |
| `C2R4` | Column 2, row 4 |
| `R4C2` | Accepted alias for `C2R4`; authors SHOULD write the `CR` form |
| `@Qty` | Column headed `Qty`, same row |
| `@{Unit Price}` | Column whose header contains spaces, same row |
| `@QtyR4` / `@{Unit Price}R4` | Headed column, row 4 |
| `@Apples` | Row whose first cell is `Apples`, as a function argument |
| `@Qty@Apples` / `C2@Apples` | Named or numbered column, row named `Apples` |
| `@{Cherry picking}` | Row or column whose name contains spaces |
| `C2R1:C2R4` | Rectangular range, as a function argument |
| `SUM(C2)` / `SUM(@Qty)` | Whole body column, as a function argument |
| `SUM(@Apples)` / `SUM(@Apples:@Pears)` | Whole named row, or named rows, as a function argument |

Rules:

- Columns count from `1` at the left, including hidden columns (§8.4). Rows count from `1` at the first body row. The header row is never numbered. Foot rows continue the body numbering.
- A row is named by the text of its first body cell. Names match case-insensitively with spaces squeezed. When two rows share a name, the first wins. A formula cell cannot name its row.
- Standing alone, `@name` is a column if a header matches, otherwise a row. In second position after a column (`@Qty@Apples`, `C2@Apples`), it is always the row.
- A bare header name (`Qty*Price`) is accepted and means the same as `@Qty`. Authors SHOULD prefer `@`, which cannot be confused with a function name.
- A whole-column reference used outside an aggregate function means the same-row cell. A whole-row reference is only meaningful as a function argument. Used as a scalar operand, it is `#VALUE!` (§8.5).
- References reach only within their own table. There are no cross-table, cross-file, or sheet references.
- A cell with a column or row span is referenced by its top-left (anchor) column and row.

### 8.3 Operators and functions

Formulas support `+`, `-`, `*`, `/`, `^`, parentheses, unary minus, and a trailing `%` (`50%` is `0.5`). Supported functions are `SUM`, `AVERAGE` (alias `AVG`), `MIN`, `MAX`, `COUNT`, and `PRODUCT`. Arguments are separated by commas. Ranges are written as in `SUM(C2R1:C2R4, C3R1)`.

Literal numbers MAY carry commas, a leading `$` / `£` / `€`, a trailing `%`, or accounting parentheses for a negative value. Inside a range or whole column, aggregates ignore empty and non-numeric cells. A non-numeric cell used as a scalar operand is an error (§8.5). Results are plain numbers. Integers print without a decimal point. Other results print with up to ten significant digits. Currency and unit labels belong in the header, not in the result.

### 8.4 What the reader sees

The calculation is worked out at export. Word does not calculate it. The reader does not calculate it.

- A compliant processor MUST replace the visible cell with its result. To the reader, a calculated column is an ordinary column of numbers.
- The processor MUST keep the source formula with the result. The reference filter stamps a `data-calc` attribute on the cell (visible in the Pandoc AST and in HTML). For Docx, it appends the formula as hidden (`w:vanish`) text in the same cell, so import can round-trip it. Hidden text MUST NOT print.
- A **hidden helper column** has a header that ends in `(hidden)`, as in `Factor (hidden)`. It MUST NOT appear in the exported table. Its cells MAY be referenced like any other column. It still counts in column numbering. Its header is referenced without the suffix (`@Factor`).

**Example 9.** A hidden helper column.

````markdown
| Item | Qty | Pack price | Factor (hidden) | Line total |
|------|-----|------------|-----------------|------------|
| Apples | 2 | 3 | 10 | =C2*C3*C4 |
| Pears | 4 | 5 | 2 | =@Qty*@{Pack price}*@Factor |
````

Export shows four columns. `Factor` is gone. Line totals are `60` and `40`.

### 8.5 Errors

A broken formula MUST NOT abort the export. It MUST NOT silently become `0`. The cell shows one of these values instead of a result:

| Value | Cause |
|-------|-------|
| `#DIV/0!` | Division by zero, or `AVERAGE` of no numbers |
| `#VALUE!` | Non-numeric scalar operand, malformed formula, or a range used as a scalar |
| `#REF!` | Reference outside the table, or an unknown header or row name |
| `#NAME?` | Unknown function or name |
| `#CYCLE!` | A cell that depends on itself, directly or through other cells |
| `#NUM!` | A result that is not a finite number |

Live Word fields, string and date arithmetic, comparisons, and `IF` are not part of this section.

**Example 10.** Errors stay visible.

````markdown
| Label | Value |
|-------|-------|
| Broken | =C2R1/0 |
| Missing | =C9R9 |
````

Export shows `#DIV/0!` and `#REF!` in those cells.

### 8.6 CSV tables

A `.csv` file is a table source under §8.1 through §8.5. Encoding MUST be UTF-8. The field separator is a comma. Quoting and newlines inside fields follow RFC 4180.

- The first row is the header. Later rows are body rows. There is no foot row in CSV.
- A spine `file` whose path ends in `.csv` (ASCII, case-insensitive) MUST be read as CSV, not as Markdown.
- A CSV file MUST NOT carry YAML front matter. It MUST NOT contain flow breaks.
- When the file is listed in `spine`, its `role` MUST come from the spine entry (§5). When the CSV is the sole root input, `role` MAY be omitted.

**Example 11.** A CSV table.

````csv
Item,Qty,Price,Line total
Apples,2,3,=C2*C3
Pears,4,5,=@Qty*@Price
````

Export shows `6` and `20` in the last column. The formulas stay hidden as in §8.4.

A Markdown file on the spine may still contain a Markdown table. That is unchanged. References still reach only within one table. There are no cross-CSV or CSV-to-Markdown cell references.

## 9. The rest of Pandoc Markdown

Paragraphs, emphasis, strong emphasis, links, images, block quotes, fenced code blocks, lists, tables, and footnotes are allowed. Footnotes require Pandoc's footnotes extension, as usual.

Fenced code is allowed. This profile does not set a measure for it. It does not require a monospace face.

Books SHOULD keep tables simple. Tables MAY calculate (§8).

## 10. What this profile does not specify

- CSS or HTML as the source of the page
- LaTeX as the language an author must write
- The same line breaks from every processor
- A frame-break token other than the normal advance in §6.1
- Rhetorical labels such as claim, evidence, and aside

## 11. Conformance

A processor is **MarkBreak Docx-conformant** at version 0.7.0 when this command exits 0:

```bash
bash tools/verify.sh
```

The command runs the reference filter on the fixtures below.

| Fixture | What it requires |
|---------|------------------|
| `fixtures/minimal-pagebreak.md` | a Word page break from `\newpage`, and role `chapter` |
| `fixtures/parts-and-chapters.md` | Word page breaks, and role `part` |
| `fixtures/roles-and-breaks.md` | a Word page break, a Word column break, and role `dedication` |
| `fixtures/break-overrides.md` | at least one Word column break, one Word page break, one `oddPage` mark, and one `evenPage` mark, and role `chapter` |
| `fixtures/spine-book/book.md` | top-level roles `toc`, `dedication`, `chapter` in that order, plus a Word page break and a Word column break |
| `fixtures/spine-mismatch/book.md` | failure: the spine role and the file role disagree |
| `fixtures/meta-layout/book.md` | top-level roles `toc`, `chapter` in that order, and a Word column break |
| `fixtures/meta-layout-bad/book.md` | failure: the layout path leaves the manuscript directory |
| `fixtures/table-calculations.md` | §8: calculated, literal, escaped, hidden-column, and error cells reach Docx as specified |
| `fixtures/table-calculations.csv` | §8.6: the same calculation dialect on a CSV root |
| `fixtures/csv-spine/book.md` | §5 / §8.6: a spine entry may be a `.csv` file |

A manuscript with no role and no flow break is valid. The command does not require breaks in every file. It fails when a break, a role, or a calculation written in one of these fixtures does not survive.

## Appendix A. Layout files

This appendix is informative. A processor implements this profile without reading it.

`layout` names a file. Section 2.4 states the duties toward that path. This profile does not state the grammar of the file.

One format writers use is a [RigWorks](https://rig.works/) document. `fixtures/meta-layout/layout.rig.json` is an example. The page there has a width, a height, and margins. A paragraph style there has `fontSize` and `leading`. Those names belong to RigWorks. They are not keys of this profile. They do not appear in the manuscript.

`fixtures/markbreak-chapter.rig.json` stores a manuscript inside a RigWorks document. That too is a RigWorks encoding. An author writing `//break` in Markdown does not write those identifiers.

## Appendix B. TeX aliases and other outputs

### B.1 TeX aliases in the manuscript

This subsection is normative. It does not change the kinds in §6. It names older Pandoc/TeX spellings that mean the same advance.

A flow break MAY also be a raw TeX block, or a paragraph, whose text with leading and trailing whitespace removed is exactly one source below. A processor MUST treat that source as the kind shown.

| Source | Kind |
|--------|------|
| `\columnbreak` | normal advance |
| `\newpage` | forced page |
| `\pagebreak` | forced page |
| `\cleardoublepage` | next odd page (recto) |

A TeX command followed by an empty group is the same command: `\newpage` and `\newpage{}` are both a forced page.

There is no standard TeX one-liner for next even page. Authors write `//break even`.

### B.2 Role recovery outside Docx

This subsection is informative. Docx conformance (§11) does not depend on it.

In ICML, the reference filter sets body paragraphs to `ParagraphStyle/<role>`.

### B.3 Flow breaks outside Docx

This subsection is informative. It records what the reference filter emits for formats other than Docx.

When the output is TeX, a flow break that is a Markdown paragraph is written as follows. A raw TeX block that is already one of the commands in B.1 is left as written.

| Kind | TeX |
|------|-----|
| normal advance | `\columnbreak` when that command is defined, otherwise `\newpage` |
| forced page | `\newpage` |
| next odd page | `\cleardoublepage` |
| next even page | clear forward to the next even page |

When the output is HTML or EPUB, the filter emits an empty element with a `break-before` style. HTML uses `div`. EPUB uses `p`.

| Kind | `break-before` | ICML `Br` |
|------|----------------|-----------|
| normal advance | `column` | `nextColumn` |
| forced page | `page` | `nextPage` |
| next odd page | `right` | `nextOddPage` |
| next even page | `left` | `nextEvenPage` |

For any other output format, the reference filter emits a paragraph that contains a form feed.
