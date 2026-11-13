-- Compatibility shim for callers that still pass -L pagebreak.lua.
local dir = (PANDOC_SCRIPT_FILE or ''):match('(.*[/\\])') or ''
dofile(dir .. 'markbreak.lua')
