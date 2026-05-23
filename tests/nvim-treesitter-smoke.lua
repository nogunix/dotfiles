-- Smoke test for the treesitter plugin.
-- Loaded via `nvim --headless +luafile <this file>`.
-- Exits with status 1 (via :cquit) when any check fails.

local failures = {}
local function fail(msg)
  failures[#failures + 1] = msg
end

local notify_errors = {}
local orig_notify = vim.notify
vim.notify = function(msg, level, opts)
  if level and level >= vim.log.levels.ERROR then
    notify_errors[#notify_errors + 1] = tostring(msg)
  end
  return orig_notify(msg, level, opts)
end

local bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
  'local function add(a, b)',
  '  return a + b',
  'end',
  'print(add(1, 2))',
})
vim.api.nvim_set_current_buf(bufnr)

-- Setting filetype should trigger the plugin's FileType autocmd, which
-- calls vim.treesitter.start(). Use that as the primary code path.
vim.bo[bufnr].filetype = 'lua'

local active = vim.treesitter.highlighter.active or {}
if not active[bufnr] then
  -- Autocmd swallows errors via pcall; call start() directly so any
  -- failure surfaces with a real message instead of a silent miss.
  local ok, err = pcall(vim.treesitter.start, bufnr, 'lua')
  if not ok then
    fail('vim.treesitter.start failed: ' .. tostring(err))
  else
    fail('treesitter.highlighter not active after FileType=lua')
  end
end

-- Force a synchronous parse: this is the path that raised
-- "attempt to call method 'range' (a nil value)" before the fix.
local parser = vim.treesitter.get_parser(bufnr, 'lua')
if not parser then
  fail('vim.treesitter.get_parser returned nil for lua')
else
  local ok, err = pcall(function() parser:parse(true) end)
  if not ok then
    fail('parser:parse failed: ' .. tostring(err))
  end
end

for _, msg in ipairs(notify_errors) do
  fail('vim.notify error: ' .. msg)
end

if #failures > 0 then
  io.stderr:write('TREESITTER SMOKE FAILED:\n')
  for _, msg in ipairs(failures) do
    io.stderr:write('  - ' .. msg .. '\n')
  end
  vim.cmd('cquit')
end

io.stdout:write('TREESITTER SMOKE OK\n')
vim.cmd('qa!')
