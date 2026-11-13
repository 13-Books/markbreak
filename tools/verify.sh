#!/usr/bin/env bash
# MarkBreak gate: Docx page breaks + YAML role survival in the Pandoc AST.
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

count_page_breaks() {
  "$python" - "$1" <<'PY'
import re, sys, zipfile
with zipfile.ZipFile(sys.argv[1]) as z:
    xml = z.read("word/document.xml").decode("utf-8")
print(len(re.findall(r'w:type\s*=\s*"page"', xml)))
PY
}

role_present() {
  grep -Eq '"role"[[:space:]]*,[[:space:]]*"'"$2"'"' "$1"
}

failed=0
check() {
  local name="$1" min="$2" role="$3"
  local src="$root/fixtures/${name}.md"
  local docx="$out/${name}.docx"
  local json="$out/${name}.json"

  "$pandoc" "$src" -f markdown -t docx -L "$filter" -o "$docx"
  "$pandoc" "$src" -f markdown -t json -L "$filter" -o "$json"

  local count
  count="$(count_page_breaks "$docx")"
  echo "$name: page breaks = $count (need >= $min)"
  if (( count < min )); then
    echo "FAIL $name page breaks"
    failed=$((failed + 1))
  else
    echo "OK   $name page breaks"
  fi

  if role_present "$json" "$role"; then
    echo "OK   $name role=$role"
  else
    echo "FAIL $name missing role=$role in AST"
    failed=$((failed + 1))
  fi
}

check minimal-pagebreak 1 chapter
check parts-and-chapters 3 part
check roles-and-breaks 2 dedication

if (( failed > 0 )); then
  echo "verify FAILED ($failed check(s))"
  exit 1
fi
echo "verify OK"
exit 0
