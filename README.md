# MarkBreak

MarkBreak is a Pandoc Markdown profile for print manuscripts.

- Open profile: [markbreak.com](https://markbreak.com)
- Repository: [13-Books/markbreak](https://github.com/13-Books/markbreak)
- Writer: [markbreak.app](https://markbreak.app)

**Profile version:** [0.5.2](VERSION). Tag it `v0.5.2`.

## Purpose

Standard Markdown does not record print function or flow breaks.

- Put the print `role` in the YAML front matter. A heading gives hierarchy only; it does not give the print function.
- Write the normal advance as `//break` on its own line. With one column, Word shows that as the next page. With more columns, it is the next column.
- Write `//break page` to force a page. Write `//break odd` or `//break even` when the page side must be specific.
- `---` is a pause in the scene. Do not use `---` as a page break.

A processor that obeys this profile emits those advances as Word column or page marks. The full rules are in [specification.md](specification.md).

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
2. The MarkBreak profile supplies the roles and the flow breaks.
3. Pandoc and `tools/markbreak.lua` write a Docx file.
4. Relay, Word, InDesign, or a press PDF does the layout.

[markbreak.app](https://markbreak.app) is the writer. The writer emits this profile.

MarkBreak is not GFM, not an HTML book generator, and not a layout engine.

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
