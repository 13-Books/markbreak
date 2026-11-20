#!/usr/bin/env bash
# MarkBreak gate: Docx flow breaks + YAML role survival in the Pandoc AST.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out="$root/out"
filter="$root/tools/markbreak.lua"
if [[ ! -f "$filter" ]]; then
  echo "markbreak.lua not found" >&2
  exit 1
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

top_roles() {
  "$python" - "$1" <<'PY'
import json, sys
doc = json.load(open(sys.argv[1], encoding="utf-8"))
if isinstance(doc, dict) and "blocks" in doc:
    blocks = doc["blocks"]
elif isinstance(doc, list) and len(doc) == 2:
    blocks = doc[1]
else:
    blocks = []

def role_of(attr):
    if not isinstance(attr, list) or len(attr) < 3:
        return ""
    for kv in attr[2]:
        if isinstance(kv, list) and len(kv) >= 2 and kv[0] == "role":
            return kv[1]
    classes = attr[1] if isinstance(attr[1], list) else []
    return classes[0] if classes else ""

roles = []
for block in blocks:
    if isinstance(block, dict) and block.get("t") == "Div":
        content = block.get("c") or []
        if content:
            roles.append(role_of(content[0]))
print(" ".join(roles))
PY
}

failed=0

ok() { echo "OK   $1"; }
fail() { echo "FAIL $1"; failed=$((failed + 1)); }

check() {
  local name="$1" min="$2" role="$3" colmin="${4:-}"
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

  if [[ -n "$colmin" ]]; then
    local columns
    columns="$(count_re "$docx" 'w:type\s*=\s*"column"')"
    echo "$name: column breaks = $columns (need >= $colmin)"
    if (( columns < colmin )); then
      fail "$name column breaks"
    else
      ok "$name column breaks"
    fi
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

  local columns pages odds evens
  columns="$(count_re "$docx" 'w:type\s*=\s*"column"')"
  pages="$(count_re "$docx" 'w:type\s*=\s*"page"')"
  odds="$(count_re "$docx" 'w:val\s*=\s*"oddPage"')"
  evens="$(count_re "$docx" 'w:val\s*=\s*"evenPage"')"

  echo "$name: column=$columns page=$pages oddPage=$odds evenPage=$evens (need >= 1 each)"
  if (( columns < 1 )); then fail "$name column break"; else ok "$name column break"; fi
  if (( pages < 1 )); then fail "$name page break"; else ok "$name page break"; fi
  if (( odds < 1 )); then fail "$name oddPage break"; else ok "$name oddPage break"; fi
  if (( evens < 1 )); then fail "$name evenPage break"; else ok "$name evenPage break"; fi

  if role_present "$json" "chapter"; then
    ok "$name role=chapter"
  else
    fail "$name missing role=chapter in AST"
  fi
}

check_spine() {
  local name="spine-book"
  local src="$root/fixtures/${name}/book.md"
  local docx="$out/${name}.docx"
  local json="$out/${name}.json"
  local expect="toc dedication chapter"

  "$pandoc" "$src" -f markdown -t docx -L "$filter" -o "$docx"
  "$pandoc" "$src" -f markdown -t json -L "$filter" -o "$json"

  local count columns roles
  count="$(count_re "$docx" 'w:type\s*=\s*"page"')"
  columns="$(count_re "$docx" 'w:type\s*=\s*"column"')"
  echo "$name: page breaks = $count (need >= 1); column breaks = $columns (need >= 1)"
  if (( count < 1 )); then
    fail "$name page breaks"
  else
    ok "$name page breaks"
  fi
  if (( columns < 1 )); then
    fail "$name column breaks"
  else
    ok "$name column breaks"
  fi

  roles="$(top_roles "$json")"
  echo "$name: top roles = $roles (need $expect)"
  if [[ "$roles" == "$expect" ]]; then
    ok "$name role order"
  else
    fail "$name role order"
  fi
}

check_spine_mismatch() {
  local src="$root/fixtures/spine-mismatch/book.md"
  if "$pandoc" "$src" -f markdown -t json -L "$filter" -o "$out/spine-mismatch.json" \
      2>"$out/spine-mismatch.err"; then
    fail "spine-mismatch should have failed"
  else
    ok "spine-mismatch rejected"
  fi
}

check_meta_layout() {
  local name="meta-layout"
  local src="$root/fixtures/${name}/book.md"
  local docx="$out/${name}.docx"
  local json="$out/${name}.json"
  local expect="toc chapter"

  "$pandoc" "$src" -f markdown -t docx -L "$filter" -o "$docx"
  "$pandoc" "$src" -f markdown -t json -L "$filter" -o "$json"

  local columns roles
  columns="$(count_re "$docx" 'w:type\s*=\s*"column"')"
  echo "$name: column breaks = $columns (need >= 1)"
  if (( columns < 1 )); then
    fail "$name column breaks"
  else
    ok "$name column breaks"
  fi

  roles="$(top_roles "$json")"
  echo "$name: top roles = $roles (need $expect)"
  if [[ "$roles" == "$expect" ]]; then
    ok "$name role order"
  else
    fail "$name role order"
  fi
}

check_meta_layout_bad() {
  local src="$root/fixtures/meta-layout-bad/book.md"
  if "$pandoc" "$src" -f markdown -t json -L "$filter" -o "$out/meta-layout-bad.json" \
      2>"$out/meta-layout-bad.err"; then
    fail "meta-layout-bad should have failed"
  else
    ok "meta-layout-bad rejected"
  fi
}

check_table_calculations() {
  local name="table-calculations"
  local src="$root/fixtures/${name}.md"
  local docx="$out/${name}.docx"
  local json="$out/${name}.json"

  "$pandoc" "$src" -f markdown -t docx -L "$filter" -o "$docx"
  "$pandoc" "$src" -f markdown -t json -L "$filter" -o "$json"

  if "$python" - "$docx" <<'PY'
import sys, zipfile
import xml.etree.ElementTree as ET

W = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"
with zipfile.ZipFile(sys.argv[1]) as z:
    root = ET.fromstring(z.read("word/document.xml"))

def run_text(run, hidden):
    rpr = run.find(f"{W}rPr")
    vanish = rpr is not None and rpr.find(f"{W}vanish") is not None
    if vanish != hidden:
        return ""
    return "".join(t.text or "" for t in run.iter(f"{W}t"))

def cells(row, hidden=False):
    return ["".join(run_text(r, hidden) for r in tc.iter(f"{W}r")).strip()
            for tc in row.findall(f"{W}tc")]

tables = [[cells(tr) for tr in tbl.findall(f"{W}tr")]
          for tbl in root.iter(f"{W}tbl")]
hidden = [[cells(tr, hidden=True) for tr in tbl.findall(f"{W}tr")]
          for tbl in root.iter(f"{W}tbl")]

expected_first = [
    ["Item", "Qty", "Pack price", "Line total"],
    ["Apples", "2", "3", "60"],
    ["Pears", "4", "5", "40"],
    ["Total", "6", "4", "100"],
]
assert tables[0] == expected_first, f"first table: {tables[0]!r}"

second = {row[0]: row[1] for row in tables[1][1:] if len(row) == 2}
expected_second = {
    "Smallest": "2", "Largest": "6", "Counted": "3", "Product": "48",
    "Specific": "720", "Percent": "1", "Literal": "C2R2*180",
    "Escaped": "=C2R2", "Broken": "#DIV/0!", "Missing": "#REF!",
}
for key, value in expected_second.items():
    assert second.get(key) == value, f"{key}: {second.get(key)!r} != {value!r}"

named = {row[0]: row[1] for row in tables[2][1:] if len(row) == 3}
expected_named = {
    "Cherry picking": "4", "Copied": "4", "Named cell": "6",
    "By number": "5", "Row sum": "9", "Row range": "14",
}
for key, value in expected_named.items():
    assert named.get(key) == value, f"named {key}: {named.get(key)!r} != {value!r}"

assert tables[3][1] == ["#CYCLE!", "#CYCLE!"], f"cycle table: {tables[3]!r}"

visible = [cell for table in tables for row in table for cell in row]
assert "Factor" not in visible, "hidden helper column leaked into Docx"
assert not any(cell.startswith("=") and cell != "=C2R2" for cell in visible), \
    f"formula leaked into visible text: {visible!r}"
hidden_flat = [cell for table in hidden for row in table for cell in row if cell]
assert "=C2*C3*C4" in hidden_flat, f"hidden formulas: {hidden_flat!r}"
assert "=SUM(C5R1:C5R2)" in hidden_flat, f"hidden formulas: {hidden_flat!r}"
print("table-calculations: Docx values, errors, hidden column and formulas OK")
PY
  then
    ok "$name Docx calculations"
  else
    fail "$name Docx calculations"
  fi

  if grep -Fq '"data-calc"' "$json"; then
    ok "$name data-calc in AST"
  else
    fail "$name missing data-calc in AST"
  fi
}

check_csv_calculations() {
  local name="table-calculations-csv"
  local src="$root/fixtures/table-calculations.csv"
  local docx="$out/${name}.docx"

  "$pandoc" "$src" -f csv -t docx -L "$filter" -o "$docx"

  if "$python" - "$docx" <<'PY'
import sys, zipfile
import xml.etree.ElementTree as ET

W = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"
with zipfile.ZipFile(sys.argv[1]) as z:
    root = ET.fromstring(z.read("word/document.xml"))

def run_text(run, hidden):
    rpr = run.find(f"{W}rPr")
    vanish = rpr is not None and rpr.find(f"{W}vanish") is not None
    if vanish != hidden:
        return ""
    return "".join(t.text or "" for t in run.iter(f"{W}t"))

def cells(row, hidden=False):
    return ["".join(run_text(r, hidden) for r in tc.iter(f"{W}r")).strip()
            for tc in row.findall(f"{W}tc")]

tables = [[cells(tr) for tr in tbl.findall(f"{W}tr")]
          for tbl in root.iter(f"{W}tbl")]
hidden = [[cells(tr, hidden=True) for tr in tbl.findall(f"{W}tr")]
          for tbl in root.iter(f"{W}tbl")]

assert len(tables) == 1, f"expected one CSV table, got {len(tables)}"
expected = [
    ["Item", "Qty", "Pack price", "Line total"],
    ["Apples", "2", "3", "60"],
    ["Pears", "4", "5", "40"],
    ["Total", "6", "4", "100"],
]
assert tables[0] == expected, f"csv table: {tables[0]!r}"
visible = [cell for row in tables[0] for cell in row]
assert "Factor" not in visible, "hidden helper column leaked from CSV"
hidden_flat = [cell for row in hidden[0] for cell in row if cell]
assert "=C2*C3*C4" in hidden_flat, f"csv hidden formulas: {hidden_flat!r}"
print("table-calculations.csv: Docx values and hidden column OK")
PY
  then
    ok "$name Docx calculations"
  else
    fail "$name Docx calculations"
  fi
}

check_csv_spine() {
  local name="csv-spine"
  local src="$root/fixtures/csv-spine/book.md"
  local docx="$out/${name}.docx"
  local json="$out/${name}.json"

  "$pandoc" "$src" -f markdown -t docx -L "$filter" -o "$docx"
  "$pandoc" "$src" -f markdown -t json -L "$filter" -o "$json"

  if role_present "$json" "chapter"; then
    ok "$name role=chapter"
  else
    fail "$name missing role=chapter in AST"
  fi

  if "$python" - "$docx" <<'PY'
import sys, zipfile
import xml.etree.ElementTree as ET

W = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"
with zipfile.ZipFile(sys.argv[1]) as z:
    root = ET.fromstring(z.read("word/document.xml"))

def run_text(run):
    rpr = run.find(f"{W}rPr")
    if rpr is not None and rpr.find(f"{W}vanish") is not None:
        return ""
    return "".join(t.text or "" for t in run.iter(f"{W}t"))

def cell_text(tc):
    return "".join(run_text(r) for r in tc.iter(f"{W}r")).strip()

tables = []
for tbl in root.iter(f"{W}tbl"):
    tables.append([[cell_text(tc) for tc in tr.findall(f"{W}tc")]
                   for tr in tbl.findall(f"{W}tr")])
assert tables, "no tables in csv-spine Docx"
expected = [
    ["Item", "Qty", "Price", "Line total"],
    ["Apples", "2", "3", "6"],
    ["Pears", "4", "5", "20"],
    ["Total", "6", "", "26"],
]
assert tables[0] == expected, f"spine csv table: {tables[0]!r}"
print("csv-spine: Docx table OK")
PY
  then
    ok "$name Docx CSV spine"
  else
    fail "$name Docx CSV spine"
  fi
}

check minimal-pagebreak 1 chapter
check parts-and-chapters 3 part
check roles-and-breaks 1 dedication 1
check_overrides
check_spine
check_spine_mismatch
check_meta_layout
check_meta_layout_bad
check_table_calculations
check_csv_calculations
check_csv_spine

if (( failed > 0 )); then
  echo "verify FAILED ($failed check(s))"
  exit 1
fi
echo "verify OK"
exit 0
