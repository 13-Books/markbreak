-- MarkBreak filter: flow breaks + YAML/file role → Div.
-- Default breaks: \newpage / \pagebreak / //--- / //break → page advance.
-- Overrides: //break column | odd | even (and TeX aliases where noted).
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
  -- Pandoc smart typography may turn //--- into //— (em dash).
  if s:match '^\\newpage%{?%}?$'
      or s:match '^\\pagebreak%{?%}?$'
      or s == '//---'
      or s == '//—'
      or s == '//--'
      or s == '//break'
      or s == '\f' then
    return 'page'
  end
  if s == '//break column' or s:match '^\\columnbreak%{?%}?$' then
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
      return pandoc.RawBlock('tex', '\\columnbreak{}')
    elseif kind == 'odd' then
      return pandoc.RawBlock('tex', '\\cleardoublepage{}')
    elseif kind == 'even' then
      -- Best-effort: clear until the next page number is even (no memoir required).
      return pandoc.RawBlock('tex',
        '\\clearpage\\ifodd\\c@page\\hbox{}\\newpage\\fi')
    end
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

local function role_name(value)
  if not value then return nil end
  local name = pandoc.utils.stringify(value)
  if name == '' then return nil end
  return name
end

local function role_div(blocks, role)
  return pandoc.Div(blocks, pandoc.Attr('', { role }, { role = role }))
end

-- Included files are parsed inside Pandoc(), after the root walk, so breaks
-- in those files must be rewritten here.
local function apply_breaks(blocks)
  local walked = pandoc.Pandoc(blocks):walk({
    Para = Para,
    RawBlock = RawBlock,
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

local function spine_path(base, rel)
  if not rel or rel == '' then
    error('MarkBreak spine entry missing file')
  end
  if rel:match('^[/\\]') or rel:match('^%a:[/\\]') then
    error('MarkBreak spine path must stay in the manuscript directory: ' .. rel)
  end
  for seg in rel:gmatch('[^/\\]+') do
    if seg == '..' then
      error('MarkBreak spine path must stay in the manuscript directory: ' .. rel)
    end
  end
  if base == '.' then
    return rel
  end
  return base .. '/' .. rel
end

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

function Meta(meta)
  role_from_meta = role_name(meta.role)
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
