-- MarkBreak filter: flow breaks + YAML/file role → Div.
-- //break is the normal advance (column mark; a one-column page shows it as a page).
-- //break page, \newpage, and \pagebreak force a page.
-- //break odd | even name the page side. \columnbreak is the normal advance.
-- Roles: meta.role wraps that file's body in a Div with attribute role=...
-- Spine: a root spine list is concatenated in this pass; each file is its own role Div.

local role_from_meta = nil

local function normalize_command(command)
  if not command then return nil end
  return command:gsub('^%s+', ''):gsub('%s+$', '')
end

-- Returns 'page' | 'column' | 'odd' | 'even' | nil
local function break_kind(command)
  local s = normalize_command(command)
  if not s then return nil end
  if s == '//break page'
      or s:match '^\\newpage%{?%}?$'
      or s:match '^\\pagebreak%{?%}?$' then
    return 'page'
  end
  if s == '//break' or s == '\f' or s:match '^\\columnbreak%{?%}?$' then
    return 'column'
  end
  if s == '//break odd' or s:match '^\\cleardoublepage%{?%}?$' then
    return 'odd'
  end
  if s == '//break even' then
    return 'even'
  end
  return nil
end

local function emit_break(format, kind)
  if format == 'docx' then
    if kind == 'page' then
      return pandoc.RawBlock('openxml', '<w:p><w:r><w:br w:type="page"/></w:r></w:p>')
    elseif kind == 'column' then
      return pandoc.RawBlock('openxml', '<w:p><w:r><w:br w:type="column"/></w:r></w:p>')
    elseif kind == 'odd' then
      return pandoc.RawBlock('openxml',
        '<w:p><w:pPr><w:sectPr><w:type w:val="oddPage"/></w:sectPr></w:pPr></w:p>')
    elseif kind == 'even' then
      return pandoc.RawBlock('openxml',
        '<w:p><w:pPr><w:sectPr><w:type w:val="evenPage"/></w:sectPr></w:pPr></w:p>')
    end
  elseif format:match 'html' or format:match 'epub' then
    local css =
      (kind == 'column' and 'column') or
      (kind == 'odd' and 'right') or
      (kind == 'even' and 'left') or
      'page'
    local tag = format:match 'epub' and 'p' or 'div'
    return pandoc.RawBlock('html',
      '<' .. tag .. ' style="break-before: ' .. css .. ';"></' .. tag .. '>')
  elseif format:match 'tex$' then
    if kind == 'page' then
      return pandoc.RawBlock('tex', '\\newpage{}')
    elseif kind == 'column' then
      -- \columnbreak exists only when a column package defines it.
      return pandoc.RawBlock('tex',
        '\\ifdefined\\columnbreak\\columnbreak\\else\\newpage\\fi')
    elseif kind == 'odd' then
      return pandoc.RawBlock('tex', '\\cleardoublepage{}')
    elseif kind == 'even' then
      -- Best-effort: clear until the next page number is even (no memoir required).
      return pandoc.RawBlock('tex',
        '\\clearpage\\ifodd\\c@page\\hbox{}\\newpage\\fi')
    end
  elseif format == 'icml' then
    -- InDesign Place(ICML): Br type is the hard break InCopy understands.
    local br =
      (kind == 'column' and 'nextColumn') or
      (kind == 'odd' and 'nextOddPage') or
      (kind == 'even' and 'nextEvenPage') or
      'nextPage'
    return pandoc.RawBlock('icml',
      '<ParagraphStyleRange AppliedParagraphStyle="ParagraphStyle/Paragraph">' ..
      '<CharacterStyleRange AppliedCharacterStyle="$ID/NormalCharacterStyle">' ..
      '<Br type="' .. br .. '" />' ..
      '</CharacterStyleRange></ParagraphStyleRange>')
  else
    return pandoc.Para{pandoc.Str '\f'}
  end
end

local function para_text(el)
  if not el.content or #el.content == 0 then return nil end
  local parts = {}
  for _, inline in ipairs(el.content) do
    if inline.text then
      table.insert(parts, inline.text)
    elseif inline.tag == 'Space' then
      table.insert(parts, ' ')
    else
      return nil
    end
  end
  return table.concat(parts)
end

-- ---------------------------------------------------------------------------
-- Table calculations (§8). A cell whose text starts with '=' is a calculation;
-- every other cell is a literal. References are column-first (CR):
--   C2        column 2, same row          C2R4      column 2, row 4
--   @Qty      column headed "Qty", same row   @{Unit Price}R2  headed, row 2
--   @Qty@Pears  Qty column, Pears row (a row is named by its first cell)
--   SUM(@Pears)  whole Pears row           SUM(C2R1:C2R4)  a range
-- R1 is the first body row; the header row is never numbered. A header ending
-- in "(hidden)" marks a helper column: usable in formulas, dropped on export.
-- ---------------------------------------------------------------------------

local function trim(s)
  return (s:gsub('^%s+', ''):gsub('%s+$', ''))
end

local function xml_escape(s)
  return (s:gsub('&', '&amp;'):gsub('<', '&lt;'):gsub('>', '&gt;'))
end

local function inline_text(inlines)
  local parts = {}
  for _, inline in ipairs(inlines or {}) do
    local tag = inline.t
    if tag == 'Str' or tag == 'Code' or tag == 'RawInline' then
      table.insert(parts, inline.text or '')
    elseif tag == 'Space' or tag == 'SoftBreak' or tag == 'LineBreak' then
      table.insert(parts, ' ')
    elseif tag == 'Emph' then
      table.insert(parts, '*' .. inline_text(inline.content) .. '*')
    elseif tag == 'Strong' then
      table.insert(parts, '**' .. inline_text(inline.content) .. '**')
    elseif tag == 'Superscript' then
      table.insert(parts, '^' .. inline_text(inline.content) .. '^')
    elseif tag == 'Subscript' then
      table.insert(parts, '~' .. inline_text(inline.content) .. '~')
    elseif tag == 'Strikeout' then
      table.insert(parts, '~~' .. inline_text(inline.content) .. '~~')
    elseif tag == 'Math' then
      table.insert(parts, inline.text or '')
    elseif inline.content then
      table.insert(parts, inline_text(inline.content))
    elseif inline.caption then
      table.insert(parts, inline_text(inline.caption))
    end
  end
  return table.concat(parts)
end

local function cell_text(cell)
  local parts = {}
  for _, block in ipairs(cell.contents or {}) do
    if block.content then
      table.insert(parts, inline_text(block.content))
    elseif block.t then
      table.insert(parts, pandoc.utils.stringify(block))
    end
  end
  return trim(table.concat(parts, ' '))
end

-- A lone code span is literal text, never a formula (the author quoted it).
local function cell_is_code_only(cell)
  local blocks = cell.contents or {}
  if #blocks ~= 1 then return false end
  local inlines = blocks[1].content
  if not inlines or #inlines ~= 1 then return false end
  return inlines[1].t == 'Code'
end

local function parse_number(text)
  if not text then return nil end
  local t = trim(text)
  if t == '' then return nil end
  local negative = false
  if t:match('^%(.*%)$') then
    negative = true
    t = trim(t:sub(2, -2))
  end
  t = t:gsub('^[$£€]%s*', '')
  local percent = false
  if t:match('%%%s*$') then
    percent = true
    t = trim(t:gsub('%%%s*$', ''))
  end
  t = t:gsub(',', '')
  if not t:match('^[+-]?%d+%.?%d*$') and not t:match('^[+-]?%.%d+$')
      and not t:match('^[+-]?%d+%.?%d*[eE][+-]?%d+$') then
    return nil
  end
  local n = tonumber(t)
  if not n then return nil end
  if percent then n = n / 100 end
  if negative then n = -n end
  return n
end

local function format_number(value)
  if value ~= value or value == math.huge or value == -math.huge then
    error('#NUM!', 0)
  end
  if math.abs(value - math.floor(value + 0.5)) < 1e-12
      and math.abs(value) < 1e15 then
    return string.format('%.0f', value)
  end
  return string.format('%.10g', value)
end

local calc_functions = {
  SUM = true, AVERAGE = true, AVG = true, MIN = true,
  MAX = true, COUNT = true, PRODUCT = true,
}

local function tokenize(formula)
  local tokens = {}
  local i = 1
  local len = #formula
  while i <= len do
    local rest = formula:sub(i)
    local ch = rest:sub(1, 1)
    if ch:match('%s') then
      i = i + 1
    elseif ch == '@' then
      local name, row
      if rest:sub(2, 2) == '{' then
        local close = rest:find('}', 3, true)
        if not close then error('#VALUE!', 0) end
        name = rest:sub(3, close - 1)
        local suffix = rest:sub(close + 1)
        local digits = suffix:match('^[Rr](%d+)')
        if digits then
          row = tonumber(digits)
          i = i + close + 1 + #digits
        else
          i = i + close
        end
      else
        local word = rest:match('^@([%w_%.%-]+)')
        if not word then error('#VALUE!', 0) end
        name = word
        i = i + 1 + #word
      end
      table.insert(tokens, { kind = 'header', name = name, row = row })
    elseif ch:match('%d') or (ch == '.' and rest:sub(2, 2):match('%d')) then
      local num = rest:match('^%d+%.?%d*[eE][+-]?%d+')
        or rest:match('^%d+%.?%d*') or rest:match('^%.%d+')
      table.insert(tokens, { kind = 'number', value = tonumber(num) })
      i = i + #num
    elseif ch:match('[%a_]') then
      local col, row = rest:match('^[Cc](%d+)[Rr](%d+)')
      if col then
        table.insert(tokens,
          { kind = 'cell', col = tonumber(col), row = tonumber(row) })
        i = i + #col + #row + 2
      else
        local colonly = rest:match('^[Cc](%d+)')
        -- C<digits> is a column reference unless a header is literally
        -- named e.g. "C2"; headers win only via @, so this is unambiguous.
        if colonly and not rest:match('^[Cc]%d+[%a_]') then
          table.insert(tokens, { kind = 'column', col = tonumber(colonly) })
          i = i + 1 + #colonly
        else
          local r, c = rest:match('^[Rr](%d+)[Cc](%d+)')
          if r and c then
            -- Accept RC as a spoken alias, but CR is the written standard.
            table.insert(tokens,
              { kind = 'cell', col = tonumber(c), row = tonumber(r) })
            i = i + #r + #c + 2
          else
            local word = rest:match('^[A-Za-z_][A-Za-z0-9_%.%-]*')
            table.insert(tokens, { kind = 'ident', name = word })
            i = i + #word
          end
        end
      end
    elseif ('+-*/^%(),:'):find(ch, 1, true) then
      table.insert(tokens, { kind = 'op', value = ch })
      i = i + 1
    else
      error('#VALUE!', 0)
    end
  end
  return tokens
end

function Table(el)
  -- Collect header names from the first head row.
  local header_col = {}
  local hidden_col = {}
  local head_rows = (el.head and el.head.rows) or {}
  if #head_rows > 0 then
    local visual = 1
    for _, cell in ipairs(head_rows[1].cells) do
      local span = tonumber(cell.colspan) or 1
      local name = cell_text(cell)
      if name:lower():match('%(hidden%)%s*$') then
        for offset = 0, span - 1 do hidden_col[visual + offset] = true end
        name = trim(name:gsub('%s*%(hidden%)%s*$', ''))
      end
      local key = trim(name:lower():gsub('%s+', ' '))
      if key ~= '' and not header_col[key] then
        header_col[key] = visual
      end
      visual = visual + span
    end
  end

  -- Index every cell by (row, visual column). Body rows are numbered from 1;
  -- head rows are row 0 and foot rows continue the body numbering.
  local grid = {}
  local body_rows = {}
  local records = {}
  local row_by_label = {}
  local max_col = 0
  local next_row = 1

  local function register(row, row_index)
    local visual = 1
    for _, cell in ipairs(row.cells) do
      local span = tonumber(cell.colspan) or 1
      local text = cell_text(cell)
      local rec = {
        cell = cell, row = row_index, col = visual, text = text,
        state = 0, value = nil,
        formula = nil, escaped = false,
      }
      if not cell_is_code_only(cell) then
        if text:sub(1, 2) == "'=" then
          rec.escaped = true
          rec.escape_len = 1
        elseif text:sub(1, 4) == '\226\128\153=' then
          -- Smart typography may turn the leading ' into a right quote.
          rec.escaped = true
          rec.escape_len = 3
        elseif text:sub(1, 1) == '=' then
          rec.formula = trim(text:sub(2))
          rec.source = text
        end
      end
      for offset = 0, span - 1 do
        grid[row_index .. ',' .. (visual + offset)] = rec
      end
      if visual + span - 1 > max_col then max_col = visual + span - 1 end
      -- A row is named by its first cell, so @Apples can find the Apples row.
      if row_index >= 1 and visual == 1 and not rec.formula then
        local key = trim(text:lower():gsub('%s+', ' '))
        if key ~= '' and not row_by_label[key] then
          row_by_label[key] = row_index
        end
      end
      table.insert(records, rec)
      visual = visual + span
    end
  end

  for _, row in ipairs(head_rows) do register(row, 0) end
  for _, body in ipairs(el.bodies or {}) do
    for _, row in ipairs(body.head or {}) do register(row, 0) end
    for _, row in ipairs(body.body or {}) do
      register(row, next_row)
      table.insert(body_rows, next_row)
      next_row = next_row + 1
    end
  end
  local foot_rows = (el.foot and el.foot.rows) or {}
  for _, row in ipairs(foot_rows) do
    register(row, next_row)
    next_row = next_row + 1
  end

  if #records == 0 then return nil end
  local any_calc = false
  for _, rec in ipairs(records) do
    if rec.formula or rec.escaped then any_calc = true break end
  end
  if not any_calc and not next(hidden_col) then return nil end

  local eval_cell

  local function lookup(row, col)
    local rec = grid[row .. ',' .. col]
    if not rec then error('#REF!', 0) end
    return rec
  end

  local function cell_number(rec, in_range)
    if rec.formula then return eval_cell(rec) end
    local n = parse_number(rec.text)
    if n ~= nil then return n end
    if in_range then return nil end
    if trim(rec.text) == '' then return 0 end
    error('#VALUE!', 0)
  end

  eval_cell = function(rec)
    if rec.state == 2 then
      if rec.err then error(rec.err, 0) end
      return rec.value
    end
    if rec.state == 1 then error('#CYCLE!', 0) end
    rec.state = 1
    local ok, result = pcall(function()
      local tokens = tokenize(rec.formula)
      local parser = { tokens = tokens, pos = 1, current = rec }
      local parse_expr

      local function peek()
        return parser.tokens[parser.pos]
      end
      local function take()
        local token = parser.tokens[parser.pos]
        parser.pos = parser.pos + 1
        return token
      end
      local function expect_op(value)
        local token = take()
        if not token or token.kind ~= 'op' or token.value ~= value then
          error('#VALUE!', 0)
        end
      end

      local function as_scalar(node)
        if node.kind == 'scalar' then return node.value end
        if node.kind == 'range' or node.kind == 'values' then
          error('#VALUE!', 0)
        end
        if node.kind == 'column' then
          return cell_number(lookup(parser.current.row, node.col))
        end
        if node.kind == 'cell' then
          return cell_number(lookup(node.row, node.col))
        end
        error('#VALUE!', 0)
      end

      local function collect(node, out)
        if node.kind == 'values' or node.kind == 'range' then
          for _, value in ipairs(node.values) do table.insert(out, value) end
        elseif node.kind == 'column' then
          for _, row_index in ipairs(body_rows) do
            local target = grid[row_index .. ',' .. node.col]
            if target then
              local n = cell_number(target, true)
              if n ~= nil then table.insert(out, n) end
            end
          end
        elseif node.kind == 'row' then
          for col = 1, max_col do
            local target = grid[node.row .. ',' .. col]
            if target then
              local n = cell_number(target, true)
              if n ~= nil then table.insert(out, n) end
            end
          end
        else
          table.insert(out, as_scalar(node))
        end
      end

      local function apply_function(name, args)
        local values = {}
        for _, arg in ipairs(args) do collect(arg, values) end
        if name == 'COUNT' then return #values end
        if name == 'SUM' or name == 'PRODUCT' then
          local acc = (name == 'SUM') and 0 or 1
          if name == 'PRODUCT' and #values == 0 then return 0 end
          for _, value in ipairs(values) do
            acc = (name == 'SUM') and (acc + value) or (acc * value)
          end
          return acc
        end
        if #values == 0 then
          if name == 'AVERAGE' or name == 'AVG' then error('#DIV/0!', 0) end
          return 0
        end
        local acc = values[1]
        for index = 2, #values do
          if name == 'AVERAGE' or name == 'AVG' then acc = acc + values[index]
          elseif name == 'MIN' then acc = math.min(acc, values[index])
          elseif name == 'MAX' then acc = math.max(acc, values[index]) end
        end
        if name == 'AVERAGE' or name == 'AVG' then return acc / #values end
        return acc
      end

      local function ref_node(token)
        if token.kind == 'column' then
          return { kind = 'column', col = token.col }
        end
        if token.kind == 'cell' then
          return { kind = 'cell', col = token.col, row = token.row }
        end
        if token.kind == 'header' then
          local key = trim(token.name:lower():gsub('%s+', ' '))
          local col = header_col[key]
          if not col and not token.row then
            -- @QtyR2: header "Qty", row 2 (the @{Qty}R2 form is preferred).
            local base, digits = key:match('^(.-)r(%d+)$')
            if base and header_col[base] then
              col = header_col[base]
              token = { kind = 'header', name = base, row = tonumber(digits) }
            end
          end
          if not col then
            -- Not a header: a row name (@Apples) is a whole row. A header
            -- wins when a name is both, so existing @Column keeps meaning.
            local row = not token.row and row_by_label[key] or nil
            if row then return { kind = 'row', row = row } end
            error('#REF!', 0)
          end
          if token.row then
            return { kind = 'cell', col = col, row = token.row }
          end
          return { kind = 'column', col = col }
        end
        if token.kind == 'ident' then
          local key = trim(token.name:lower():gsub('%s+', ' '))
          local col = header_col[key]
          if col then return { kind = 'column', col = col } end
          local row = row_by_label[key]
          if row then return { kind = 'row', row = row } end
          error('#NAME?', 0)
        end
        error('#VALUE!', 0)
      end

      local function row_from_name(name)
        local row = row_by_label[trim(name:lower():gsub('%s+', ' '))]
        if not row then error('#REF!', 0) end
        return row
      end

      -- A column reference may carry a row name: @Qty@Apples, C2@Apples.
      -- Position decides meaning, so a name that is both header and row
      -- label is a column standing alone and a row in second position.
      local function node_from(token)
        local node = ref_node(token)
        local following = peek()
        if following and following.kind == 'header' then
          if node.kind ~= 'column' or following.row then
            error('#VALUE!', 0)
          end
          take()
          return { kind = 'cell', col = node.col,
            row = row_from_name(following.name) }
        end
        return node
      end

      local parse_primary
      parse_primary = function()
        local token = take()
        if not token then error('#VALUE!', 0) end
        if token.kind == 'number' then
          return { kind = 'scalar', value = token.value }
        end
        if token.kind == 'op' and token.value == '(' then
          local inner = parse_expr()
          expect_op(')')
          return inner
        end
        if token.kind == 'ident'
            and calc_functions[token.name:upper()] then
          local name = token.name:upper()
          expect_op('(')
          local args = {}
          local closing = peek()
          if closing and closing.kind == 'op' and closing.value == ')' then
            take()
          else
            while true do
              table.insert(args, parse_expr())
              local sep = take()
              if sep and sep.kind == 'op' and sep.value == ')' then break end
              if not sep or sep.kind ~= 'op' or sep.value ~= ',' then
                error('#VALUE!', 0)
              end
            end
          end
          return { kind = 'scalar', value = apply_function(name, args) }
        end
        if token.kind == 'ident' or token.kind == 'header'
            or token.kind == 'cell' or token.kind == 'column' then
          local node = node_from(token)
          local following = peek()
          if following and following.kind == 'op' and following.value == ':' then
            take()
            local other_token = take()
            if not other_token then error('#REF!', 0) end
            local other = node_from(other_token)
            local values = {}
            if node.kind == 'cell' and other.kind == 'cell' then
              for r = math.min(node.row, other.row),
                  math.max(node.row, other.row) do
                for c = math.min(node.col, other.col),
                    math.max(node.col, other.col) do
                  local target = grid[r .. ',' .. c]
                  if target then
                    local n = cell_number(target, true)
                    if n ~= nil then table.insert(values, n) end
                  end
                end
              end
            elseif node.kind == 'row' and other.kind == 'row' then
              for r = math.min(node.row, other.row),
                  math.max(node.row, other.row) do
                for c = 1, max_col do
                  local target = grid[r .. ',' .. c]
                  if target then
                    local n = cell_number(target, true)
                    if n ~= nil then table.insert(values, n) end
                  end
                end
              end
            else
              error('#REF!', 0)
            end
            return { kind = 'values', values = values }
          end
          return node
        end
        error('#VALUE!', 0)
      end

      local function parse_factor()
        local token = peek()
        if token and token.kind == 'op' and token.value == '-' then
          take()
          return { kind = 'scalar', value = -as_scalar(parse_factor()) }
        end
        if token and token.kind == 'op' and token.value == '+' then
          take()
          return parse_factor()
        end
        local base = parse_primary()
        local after = peek()
        if after and after.kind == 'op' and after.value == '%' then
          take()
          return { kind = 'scalar', value = as_scalar(base) / 100 }
        end
        if after and after.kind == 'op' and after.value == '^' then
          take()
          return { kind = 'scalar',
            value = as_scalar(base) ^ as_scalar(parse_factor()) }
        end
        return base
      end

      local function parse_term()
        local left = parse_factor()
        while true do
          local token = peek()
          if not token or token.kind ~= 'op'
              or (token.value ~= '*' and token.value ~= '/') then
            return left
          end
          take()
          local right = as_scalar(parse_factor())
          local value = as_scalar(left)
          if token.value == '/' then
            if right == 0 then error('#DIV/0!', 0) end
            value = value / right
          else
            value = value * right
          end
          left = { kind = 'scalar', value = value }
        end
      end

      parse_expr = function()
        local left = parse_term()
        while true do
          local token = peek()
          if not token or token.kind ~= 'op'
              or (token.value ~= '+' and token.value ~= '-') then
            return left
          end
          take()
          local right = as_scalar(parse_term())
          local value = as_scalar(left)
          value = (token.value == '+') and (value + right) or (value - right)
          left = { kind = 'scalar', value = value }
        end
      end

      local node = parse_expr()
      if parser.pos <= #tokens then error('#VALUE!', 0) end
      return as_scalar(node)
    end)
    rec.state = 2
    if ok then
      rec.value = result
      return result
    end
    rec.err = (type(result) == 'string' and result:match('#[A-Z0-9/!?]+')) or '#VALUE!'
    error(rec.err, 0)
  end

  -- Evaluate and rewrite formula / escaped cells.
  for _, rec in ipairs(records) do
    if rec.escaped then
      rec.cell.contents =
        { pandoc.Plain({ pandoc.Str(rec.text:sub((rec.escape_len or 2) + 1)) }) }
    elseif rec.formula then
      local ok, result = pcall(eval_cell, rec)
      local shown
      if ok then
        local formatted_ok, formatted = pcall(format_number, result)
        shown = formatted_ok and formatted or '#NUM!'
      else
        shown = (type(result) == 'string' and result:match('#[A-Z0-9/!?]+')) or '#VALUE!'
      end
      local inlines = { pandoc.Str(shown) }
      if FORMAT == 'docx' then
        table.insert(inlines, pandoc.RawInline('openxml',
          '<w:r><w:rPr><w:vanish/></w:rPr><w:t xml:space="preserve">'
          .. xml_escape(rec.source) .. '</w:t></w:r>'))
      end
      rec.cell.contents = { pandoc.Plain(inlines) }
      local attrs = {}
      if rec.cell.attr and rec.cell.attr.attributes then
        for key, value in pairs(rec.cell.attr.attributes) do
          attrs[key] = value
        end
      end
      attrs['data-calc'] = rec.source
      rec.cell.attr = pandoc.Attr(
        (rec.cell.attr and rec.cell.attr.identifier) or '',
        (rec.cell.attr and rec.cell.attr.classes) or {}, attrs)
    end
  end

  -- Drop hidden helper columns from the exported table.
  if next(hidden_col) then
    local function filter_row(row)
      local kept = pandoc.List()
      local visual = 1
      for _, cell in ipairs(row.cells) do
        local span = tonumber(cell.colspan) or 1
        if not hidden_col[visual] then kept:insert(cell) end
        visual = visual + span
      end
      row.cells = kept
      return row
    end
    for _, row in ipairs(head_rows) do filter_row(row) end
    for _, body in ipairs(el.bodies or {}) do
      for _, row in ipairs(body.head or {}) do filter_row(row) end
      for _, row in ipairs(body.body or {}) do filter_row(row) end
    end
    for _, row in ipairs(foot_rows) do filter_row(row) end
    if el.colspecs then
      local kept = pandoc.List()
      for index, spec in ipairs(el.colspecs) do
        if not hidden_col[index] then kept:insert(spec) end
      end
      el.colspecs = kept
    end
  end
  return el
end

local function role_name(value)
  if not value then return nil end
  local name = pandoc.utils.stringify(value)
  if name == '' then return nil end
  return name
end

local function role_div(blocks, role)
  -- ICML ignores Div attrs; stamp ParagraphStyle/{role} onto body paragraphs.
  if FORMAT == 'icml' then
    local out = pandoc.List()
    for _, block in ipairs(blocks) do
      if block.t == 'Para' then
        local frag = pandoc.write(pandoc.Pandoc({ block }), 'icml')
        frag = frag:gsub(
          'AppliedParagraphStyle="ParagraphStyle/Paragraph"',
          'AppliedParagraphStyle="ParagraphStyle/' .. role .. '"',
          1)
        out:insert(pandoc.RawBlock('icml', frag))
      else
        out:insert(block)
      end
    end
    return pandoc.Div(out, pandoc.Attr('', { role }, { role = role }))
  end
  -- Docx: a leading empty paragraph with custom style "Role <role>" so import
  -- can recover front-matter role: (mammoth style map → role-*).
  if FORMAT == 'docx' then
    local style = 'Role ' .. role
    local marker = pandoc.RawBlock(
      'openxml',
      '<w:p><w:pPr><w:pStyle w:val="' .. style .. '"/></w:pPr><w:r><w:t></w:t></w:r></w:p>'
    )
    local out = pandoc.List({ marker })
    for _, block in ipairs(blocks) do
      out:insert(block)
    end
    return pandoc.Div(out, pandoc.Attr('', { role }, { role = role }))
  end
  return pandoc.Div(blocks, pandoc.Attr('', { role }, { role = role }))
end

-- Included files are parsed inside Pandoc(), after the root walk, so breaks
-- in those files must be rewritten here.
local function apply_breaks(blocks)
  local walked = pandoc.Pandoc(blocks):walk({
    Para = Para,
    RawBlock = RawBlock,
    Table = Table,
  })
  return walked.blocks
end

local function manuscript_dir()
  local files = PANDOC_STATE and PANDOC_STATE.input_files
  local input = files and files[1]
  if not input or input == '' or input == '-' then
    return '.'
  end
  local dir = input:match('^(.*)[/\\]')
  if not dir or dir == '' then
    return '.'
  end
  return dir
end

-- Reject absolute paths and '..'. Keys stay in the manuscript tree.
local function require_relative_path(kind, rel)
  if not rel or rel == '' then
    error('MarkBreak ' .. kind .. ' path missing')
  end
  if rel:match('^[/\\]') or rel:match('^%a:[/\\]') then
    error('MarkBreak ' .. kind .. ' path must stay in the manuscript directory: ' .. rel)
  end
  for seg in rel:gmatch('[^/\\]+') do
    if seg == '..' then
      error('MarkBreak ' .. kind .. ' path must stay in the manuscript directory: ' .. rel)
    end
  end
  return rel
end

local function spine_path(base, rel)
  require_relative_path('spine', rel)
  if base == '.' then
    return rel
  end
  return base .. '/' .. rel
end

-- Validate meta/layout paths; preserve the keys. Layout rendering is the writer's job.
local function validate_path_keys(meta)
  local meta_path = role_name(meta.meta)
  if meta_path then
    require_relative_path('meta', meta_path)
  end
  local layout_path = role_name(meta.layout)
  if layout_path then
    require_relative_path('layout', layout_path)
  end
end

local function is_csv_path(path)
  return path:lower():match('%.csv$') ~= nil
end

-- Spine entries MAY be Markdown or CSV (§1, §8.6). CSV becomes a Pandoc table;
-- §8 calculations run in the shared Table walk.
local function read_manuscript(path)
  local f, err = io.open(path, 'r')
  if not f then
    error('MarkBreak spine file not found: ' .. path .. (err and (' (' .. err .. ')') or ''))
  end
  local text = f:read('*a')
  f:close()
  if not text then
    error('MarkBreak spine file unreadable: ' .. path)
  end
  text = text:gsub('\r\n', '\n'):gsub('\r', '\n')
  if is_csv_path(path) then
    return pandoc.read(text, 'csv')
  end
  return pandoc.read(text, 'markdown')
end

local function is_list(value)
  if not value then return false end
  local kind = pandoc.utils.type(value)
  return kind == 'List' or kind == 'MetaList'
end

local function spine_entries(meta)
  local spine = meta.spine
  if not spine then return nil end
  if not is_list(spine) then
    error('MarkBreak spine must be a list')
  end
  if #spine == 0 then return nil end
  local entries = {}
  for _, item in ipairs(spine) do
    local kind = pandoc.utils.type(item)
    if kind ~= 'MetaMap' and kind ~= 'table' then
      error('MarkBreak spine entry must be a file mapping')
    end
    local file = role_name(item.file)
    if not file then
      error('MarkBreak spine entry missing file')
    end
    table.insert(entries, { file = file, role = role_name(item.role) })
  end
  return entries
end

-- Stamp the manuscript-relative path into the image title so Docx descr
-- survives as `original:<path>` and import can re-link the art file.
function Image(img)
  local src = img.src
  if not src or src == '' then return img end
  if src:match('^https?://') or src:match('^data:') then return img end
  if src:match('^original:') then return img end
  local title = img.title or ''
  if title:match('original:') then return img end
  img.title = 'original:' .. src .. (title ~= '' and ('|' .. title) or '')
  return img
end

function Meta(meta)
  role_from_meta = role_name(meta.role)
  validate_path_keys(meta)
  return meta
end

function RawBlock(el)
  if not el.format:match 'tex' then
    return nil
  end
  local kind = break_kind(el.text)
  if not kind then
    return nil
  end
  -- Leave TeX alone when targeting TeX; rewrite for other formats.
  if FORMAT:match 'tex$' then
    return nil
  end
  return emit_break(FORMAT, kind)
end

function Para(el)
  local kind = break_kind(para_text(el))
  if kind then
    return emit_break(FORMAT, kind)
  end
  return nil
end

function Pandoc(doc)
  local entries = spine_entries(doc.meta)
  if not entries then
    if role_from_meta then
      doc.blocks = { role_div(doc.blocks, role_from_meta) }
    end
    return doc
  end

  local blocks = pandoc.List()
  if #doc.blocks > 0 then
    if role_from_meta then
      blocks:insert(role_div(doc.blocks, role_from_meta))
    else
      blocks:extend(doc.blocks)
    end
  end

  local base = manuscript_dir()
  for _, entry in ipairs(entries) do
    local path = spine_path(base, entry.file)
    local child = read_manuscript(path)
    if is_list(child.meta.spine) and #child.meta.spine > 0 then
      error('MarkBreak spine file must not contain its own spine: ' .. entry.file)
    end
    local child_role = role_name(child.meta.role)
    if entry.role and child_role and entry.role ~= child_role then
      error('MarkBreak spine role does not match file role for ' .. entry.file
        .. ': ' .. entry.role .. ' vs ' .. child_role)
    end
    local role = entry.role or child_role
    if not role then
      error('MarkBreak spine entry missing role: ' .. entry.file)
    end
    blocks:insert(role_div(apply_breaks(child.blocks), role))
  end

  doc.blocks = blocks
  return doc
end
