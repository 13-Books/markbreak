#!/usr/bin/env bash
# MarkBreak gate: Docx flow breaks + YAML role survival in the Pandoc AST.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out="$root/out"
filter="$root/tools/markbreak.lua"
if [[ ! -f "$filter" ]]; then
  filter="$root/tools/pagebreak.lua"
fi
mkdir -p "$out"

if [[ -n "${MARKBREAK_PANDOC:-}" ]]; then
  pandoc="$MARKBREAK_PANDOC"
elif command -v pandoc >/dev/null 2>&1; then
  pandoc="$(command -v pandoc)"
else
  echo "pandoc not found" >&2
  exit 1
fi

if command -v python3 >/dev/null 2>&1; then
  python="python3"
elif command -v python >/dev/null 2>&1; then
  python="python"
else
  echo "python3 not found (needed to read docx)" >&2
  exit 1
fi

echo "pandoc: $pandoc"
echo "filter: $filter"

count_re() {
  "$python" - "$1" "$2" <<'PY'
import re, sys, zipfile
with zipfile.ZipFile(sys.argv[1]) as z:
    xml = z.read("word/document.xml").decode("utf-8")
print(len(re.findall(sys.argv[2], xml)))
PY
}

role_present() {
  grep -Eq '"role"[[:space:]]*,[[:space:]]*"'"$2"'"' "$1"
}

failed=0

ok() { echo "OK   $1"; }
fail() { echo "FAIL $1"; failed=$((failed + 1)); }

check() {
  local name="$1" min="$2" role="$3"
  local src="$root/fixtures/${name}.md"
  local docx="$out/${name}.docx"
  local json="$out/${name}.json"

  "$pandoc" "$src" -f markdown -t docx -L "$filter" -o "$docx"
  "$pandoc" "$src" -f markdown -t json -L "$filter" -o "$json"

  local count
  count="$(count_re "$docx" 'w:type\s*=\s*"page"')"
  echo "$name: page breaks = $count (need >= $min)"
  if (( count < min )); then
    fail "$name page breaks"
  else
    ok "$name page breaks"
  fi

  if role_present "$json" "$role"; then
    ok "$name role=$role"
  else
    fail "$name missing role=$role in AST"
  fi
}

check_overrides() {
  local name="break-overrides"
  local src="$root/fixtures/${name}.md"
  local docx="$out/${name}.docx"
  local json="$out/${name}.json"

  "$pandoc" "$src" -f markdown -t docx -L "$filter" -o "$docx"
  "$pandoc" "$src" -f markdown -t json -L "$filter" -o "$json"

  local columns odds evens
  columns="$(count_re "$docx" 'w:type\s*=\s*"column"')"
  odds="$(count_re "$docx" 'w:val\s*=\s*"oddPage"')"
  evens="$(count_re "$docx" 'w:val\s*=\s*"evenPage"')"

  echo "$name: column=$columns oddPage=$odds evenPage=$evens (need >= 1 each)"
  if (( columns < 1 )); then fail "$name column break"; else ok "$name column break"; fi
  if (( odds < 1 )); then fail "$name oddPage break"; else ok "$name oddPage break"; fi
  if (( evens < 1 )); then fail "$name evenPage break"; else ok "$name evenPage break"; fi

  if role_present "$json" "chapter"; then
    ok "$name role=chapter"
  else
    fail "$name missing role=chapter in AST"
  fi
}

check minimal-pagebreak 1 chapter
check parts-and-chapters 3 part
check roles-and-breaks 2 dedication
check_overrides

if (( failed > 0 )); then
  echo "verify FAILED ($failed check(s))"
  exit 1
fi
echo "verify OK"
exit 0
