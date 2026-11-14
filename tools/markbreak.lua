-- MarkBreak filter: flow breaks + YAML/file role → Div.
-- Default breaks: \newpage / \pagebreak / //--- / //break → page advance.
-- Overrides: //break column | odd | even (and TeX aliases where noted).
-- Roles: meta.role wraps the document body in a Div with attribute role=...

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

function Meta(meta)
  if meta.role then
    role_from_meta = pandoc.utils.stringify(meta.role)
  end
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
  if role_from_meta and role_from_meta ~= '' then
    local div = pandoc.Div(doc.blocks, pandoc.Attr('', { role_from_meta }, { role = role_from_meta }))
    doc.blocks = { div }
  end
  return doc
end
