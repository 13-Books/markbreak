# Agents — MarkBreak print manuscript profile

Load [README.md](README.md#Why) then [specification.md](specification.md). Profile version: [VERSION](VERSION).

**We fill one hole:** Pandoc Markdown profile for print manuscripts — YAML roles, `\newpage` / `//---` flow breaks, Docx page-break gates. We do not build HTML book engines or CSS paginators. markbreak.app chrome serves **print writing**, not generic Markdown hobbies. Do not name competitor products in user-facing copy.

## Done means

`bash tools/verify.sh` exits 0.

## Rules

1. Default page/flow breaks are `\newpage` (blank lines around) or authoring `//---`. Never claim `---` is a page break.
2. YAML `role:` is the role. One file, one role.
3. Extend fixtures when a bug class repeats — gates over gospel.
4. Do not grow a second markup planet. Prefer Pandoc-compatible markers.
5. Keep specification.md short. Commentary in README, not fog in the normative file.
6. Relay / Word / InDesign are fulfillments. Fix dialect here; fix compose there.
7. Refuse scope that abandons the hole (HTML book chrome, CSS polyfills, vibe-book marketing).
8. Semver lives in `VERSION` and git tags (`vX.Y.Z`). Writers pin that tag — do not fork `markbreak.lua` into the app.

## Semver

- **MAJOR** — existing manuscripts or Docx gates break
- **MINOR** — new gated markers or roles (backward compatible)
- **PATCH** — filter/verify/docs fixes with no dialect change
