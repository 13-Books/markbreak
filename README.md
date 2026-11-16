# MarkBreak

MarkBreak is a Pandoc Markdown profile for print manuscripts.

- Open profile: [markbreak.com](https://markbreak.com)
- Repository: [13-Books/markbreak](https://github.com/13-Books/markbreak)
- Writer: [markbreak.app](https://markbreak.app)

**Profile version:** [0.5.1](VERSION). Tag it `v0.5.1`.

## Purpose

The profile records two facts that standard Markdown does not record.

- The YAML key `role` gives the print function of a file.
- A heading gives the title level. The heading does not give the print function.
- Write the normal advance as `//break`.
- With one column, Word shows `//break` as the next page. With more columns, it is the next column.
- Write `//break page` to force a page.
- Write `//break odd` or `//break even` when the page side must be specific.
- `---` is a pause in the scene. Do not use `---` as a page break.

A processor that obeys this profile writes `//break` as a Word column break.
The Word mark is `w:br` with `w:type="column"`.
`//break page` uses `w:type="page"`.

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

- `meta.md` holds `title`, `subtitle`, `author`, `language`, `isbn13`, and `publisher`.
- Paths in `meta`, `layout`, and `spine` are relative to the root manuscript. Absolute paths and `..` fail.
- The layout file holds trim, margins, `fontSize`, and `leading`. A chapter file does not.
- A file processed alone is its own root and may carry `meta` / `layout`.
- The writer (`markbreak.app`) copies that page into Docx and PDF. The reference filter rejects bad paths; it does not invent a page size.

Run `bash tools/verify.sh` to check the fixtures.
The full rules are in [specification.md](specification.md).

## When to use it

Use this profile when you write a book as Markdown files.
You need each chapter to start on a new page in Word, Relay, or a press PDF.

## Other tools

| Kind | Work |
|------|------|
| HTML book generators | Online books from a summary tree |
| Full authoring engines | Books and notebooks with many outputs |
| HTML/CSS paginators | Page layout in a browser |
| General Markdown editors | Editor functions |
| GFM | Prose for the screen |
| Pandoc | The conversion program |
| Relay, Word, InDesign | Layout after this profile |

## Sequence

1. You write the manuscript in Markdown.
2. The MarkBreak profile supplies the roles and the flow breaks.
3. Pandoc writes a Docx file.
4. Relay, Word, InDesign, or a press PDF does the layout.
5. [markbreak.app](https://markbreak.app) is the writer. The writer emits this profile.

## Checks

1. Obey [specification.md](specification.md).
2. Put one `role` in the YAML of each file. A `spine` lists the other files. Each listed file keeps its own role.
3. Write the normal advance as `//break`. Write `//break page` to force a page. Do not use `---` as a page break.
4. Run `bash tools/verify.sh`. The command fails when a break written in a fixture does not reach Word, or when a role is lost.

MarkBreak is the print manuscript profile. You can check that written roles and breaks survive.

## Run the check

```bash
bash tools/verify.sh
```

## Files

| Path | Contents |
|------|----------|
| [VERSION](VERSION) | Version of this profile. Tags use the form `vX.Y.Z`. |
| [specification.md](specification.md) | Rules for the profile |
| [index.html](index.html) | Page for markbreak.com |
| `fixtures/` | Test manuscripts |
| `tools/` | Pandoc filter and the check |
| `out/` | Docx files from the check. Git ignores this directory. |

Open the specification in the writer:

`https://markbreak.app/edit.html?url=https://markbreak.com/specification.md`
