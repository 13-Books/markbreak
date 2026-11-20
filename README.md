# MarkBreak

MarkBreak is a plain-text manuscript format for print: roles, flow breaks, and
tables that calculate — still Pandoc Markdown, proven by Docx round-trip.

- Site: [markbreak.com](https://markbreak.com)
- Repository: [13-Books/markbreak](https://github.com/13-Books/markbreak)
- Writer: [markbreak.app](https://markbreak.app)

**Version:** [0.7.0](VERSION). Tag it `v0.7.0`.

## Purpose

Standard Markdown does not record print function or flow breaks.

- Put the print `role` in the YAML front matter. A heading gives hierarchy only; it does not give the print function.
- Write the normal advance as `//break` on its own line. With one column, Word shows that as the next page. With more columns, it is the next column.
- Write `//break page` to force a page. Write `//break odd` or `//break even` when the page side must be specific.
- `---` is a pause in the scene. Do not use `---` as a page break.
- Tables MAY calculate: a cell that starts with `=` is a formula (`=C2*C3`, `@Qty`, `SUM(…)`). Export shows the result; the formula stays in the file.
- **CSV from the start:** a `.csv` file is a table source with the same calculation dialect. List it in `spine`, or process it alone with Pandoc’s CSV reader.

A processor that obeys MarkBreak emits those advances as Word column or page marks. The full rules are in [specification.md](specification.md).

## The name

- **Mark** — Markdown, and the older sense of the word: an author's mark on a manuscript. *This is a chapter. This file is the epilog. Start here.*
- **Break** — `//break` on its own line: the flow break standard Markdown never records, so a manuscript could not say, in plain text, *turn the page*.

Markdown never had a page break — only the scene pause (`---`). Headings never carried print role. “New page” lived as a button in one app, forgotten by the file. MarkBreak puts role and break in the manuscript. It stays Pandoc Markdown; `---` stays a pause in the scene.

Praised by [Plain Text Humans](https://plaintexthumans.com).

## Roles

One file, one role.

```yaml
---
title: "Commit Don't Push"
role: epilog
---

# After the gates
```

A second role is a second file.

## Tables that calculate

A cell that starts with `=` is a calculation; every other cell is a literal. References are column-then-row: `C2` is column 2 on the same row, `C2R4` is column 2, row 4, and `@Qty` names a column by its header. Rows are named by their first cell too, so `@Qty@Pears` is the Qty cell on the Pears row and `SUM(@Pears)` totals that row — no counting in either direction.

```markdown
| Item | Qty | Price | Line total |
|------|-----|-------|------------|
| Apples | 2 | 3 | =C2*C3 |
| Pears | 4 | 5 | =@Qty*@Price |
| Total | =SUM(C2R1:C2R2) | | =SUM(C4R1:C4R2) |
```

The same dialect works in **CSV** — MarkBreak supports it from the start:

```csv
Item,Qty,Price,Line total
Apples,2,3,=C2*C3
Pears,4,5,=@Qty*@Price
```

Put `prices.csv` in the `spine`, or run `pandoc prices.csv -f csv -L tools/markbreak.lua`. The export shows only the results — to a reader it is an ordinary extra column. The formula stays hidden in the cell (`data-calc`, and hidden text in Docx) so it can round-trip. A header ending in `(hidden)` makes a helper column that formulas can use but readers never see. The full rules are in [specification.md](specification.md) §8 and §8.6.

## Book shape

The root manuscript names publication facts, layout, and the spine. Each listed file keeps its own `role`.

```yaml
---
role: toc
meta: meta.md
layout: layout.rig.json
spine:
  - { file: "00-dedication.md", role: dedication }
  - { file: "01-genesis.md", role: chapter }
---
```

A file listed in `spine` carries only its own role:

```yaml
---
title: "Genesis"
role: chapter
---
```

- `meta.md` holds `title`, `subtitle`, `author`, `language`, `isbn13`, and `publisher`.
- Paths in `meta`, `layout`, and `spine` are relative to the root manuscript. Absolute paths and `..` fail.
- The layout file holds trim, margins, `fontSize`, and `leading`. A chapter file does not.
- A file processed alone is its own root and may carry `meta` / `layout`.
- The writer (`markbreak.app`) copies that page into Docx and PDF. The reference filter rejects bad paths; it does not invent a page size.

## Check

```bash
bash tools/verify.sh
```

The command fails when a break written in a fixture does not reach Word, or when a role is lost. Obey [specification.md](specification.md).

## How it ships

1. You write the manuscript in Markdown.
2. MarkBreak records the roles and the flow breaks in the file.
3. Pandoc and `tools/markbreak.lua` write a Docx file.
4. Relay, Word, InDesign, or a press PDF does the layout.

[markbreak.app](https://markbreak.app) is the writer. It emits MarkBreak manuscripts.

MarkBreak is not GFM, not an HTML book generator, and not a layout engine.

## Files

| Path | Contents |
|------|----------|
| [VERSION](VERSION) | Format version. Tags use the form `vX.Y.Z`. |
| [specification.md](specification.md) | Rules |
| [index.html](index.html) | Page for markbreak.com |
| `fixtures/` | Test manuscripts |
| `tools/` | Pandoc filter and the check |
| `out/` | Docx files from the check. Git ignores this directory. |

Open the specification in the writer:

`https://markbreak.app/edit.html?url=https://markbreak.com/specification.md`
