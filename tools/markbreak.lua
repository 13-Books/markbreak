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
