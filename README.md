# MarkBreak

**The print manuscript profile Markdown never had.**

Open dialect: [markbreak.com](https://markbreak.com) · Repo: [13-Books/markbreak](https://github.com/13-Books/markbreak) · Writer: [markbreak.app](https://markbreak.app)

**Profile version:** [0.3.0](VERSION) (semver — tag as `v0.3.0`)

## Why

**MarkBreak** — a Pandoc Markdown **profile** for print manuscripts: YAML roles + hard flow breaks + conformance tests — engine-agnostic.

Markdown authors writing for **print** have no small, enforceable contract for “this manuscript has pages and roles.”

- GFM is silent on page breaks (`---` is a thematic break).
- A `#` heading does not say *epilog* vs *chapter*.
- HTML book generators and full authoring engines own other jobs.
- General Markdown editors own chrome, not Docx page-break gates.
- Pandoc can carry `\newpage` — as folklore, not as a gated profile.

**MarkBreak** fills the seam between “I wrote `.md`” and “Word / Relay / InDesign / press PDF.”  
A Pandoc Markdown **profile**: YAML roles, parts/chapters, canonical flow breaks (`\newpage` / `//---`), and CI that goes red when Docx lacks real `w:br type="page"`.

This is the **input law**, not another HTML book engine or generic editor.

### Who hurts

Someone with a folder of `.md` who needs chapter starts on **real pages** in Word, Relay, or press PDF — and needs CI to fail when a break is missing. Someone who knows a `#` heading is not an epilog.

Today’s answer is a blog post and tribal Pandoc flags. That is the hole.

Plain Markdown is a thin container for meaning ([Rasmus](https://danielwrasmus.substack.com/p/markdown-is-not-the-future-of-writing)): it confuses formatting with structure. MarkBreak answers that **for print books** with YAML `role:` and gated breaks — not with DITA, and not by becoming another HTML book engine.

### Nearby (not us)

| Kind | Owns |
|------|------|
| HTML book generators | Online books from a summary tree |
| Full authoring engines | Multi-output notebooks / books |
| HTML/CSS paginators | Browser page layout |
| General Markdown editors | Editor chrome, not Docx page-break gates |
| GFM | Screen prose; no page-break law |
| Pandoc | The pipe — not a print-manuscript product |
| Relay / Word / InDesign | Layout after ingest |

### Layer cake

```text
  Author  →  [ MarkBreak profile ]  →  Pandoc / Docx  →  Relay | Word | InDesign | PDF
                 ↑
            spec + fixtures + verify
                 ↑
         markbreak.app (writer chrome)
```

### Brand

- **markbreak.com** — open profile (repo [13-Books/markbreak](https://github.com/13-Books/markbreak)): specification, fixtures, verify.
- **markbreak.app** — writer (online + desktop) that emits MarkBreak.

## Success

1. **Specification** — [specification.md](specification.md) authors and agents can obey.
2. **Roles** — YAML `role:`. One file, one role. A `spine` lists the other files; each file keeps its own role.
3. **Breaks** — `\newpage` / `//---`; `---` never means page break. Default break = flow advance (page when there are no columns).
4. **Gate** — `bash tools/verify.sh` fails closed when fixtures lack real Docx page breaks or lose roles.
5. **Boundary sentence:**  
   *Not another Markdown editor. The print manuscript profile — roles and page breaks you can verify.*

## Quick gate

```bash
bash tools/verify.sh
```

## Layout

| Path | Role |
|------|------|
| [VERSION](VERSION) | Semver of this profile (`vX.Y.Z` tags) |
| [specification.md](specification.md) | Dialect (normative) — single source of truth |
| [index.html](index.html) | markbreak.com landing |
| `fixtures/` | Canonical manuscripts |
| `tools/` | Pandoc MarkBreak filter + verify |
| `out/` | Generated Docx / dumps (gitignored) |

Writer: [markbreak.app](https://markbreak.app) (online editor + desktop). Open the specification in the writer:  
`https://markbreak.app/edit.html?url=https://markbreak.com/specification.md`
