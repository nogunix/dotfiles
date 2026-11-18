-- vim options
vim.scriptencoding = 'utf-8'
vim.opt.encoding = 'utf-8'
vim.opt.fileencoding = 'utf-8'
vim.wo.number = true
vim.opt.clipboard = "unnamedplus"
vim.opt.cursorline = true
vim.opt.termguicolors = true
vim.opt.background = 'dark'
vim.opt.showmatch = true
vim.opt.matchtime = 1

-- Show invisible characters
vim.opt.list = true
vim.opt.listchars = {
  tab   = "» ",
  space = "·",
  trail = "×",
}
vim.keymap.set("n", "<leader>l", function()
  vim.opt.list = not vim.opt.list:get()
end, { desc = "Toggle listchars" })

-- Highlight CR at end of line when fileformat is unix
vim.api.nvim_create_autocmd({ "BufWinEnter", "InsertLeave" }, {
  pattern = "*",
  callback = function()
    if vim.bo.fileformat == "unix" then
      if vim.w.cr_match_id then
        pcall(vim.fn.matchdelete, vim.w.cr_match_id)
        vim.w.cr_match_id = nil
      end
      vim.w.cr_match_id = vim.fn.matchadd("ErrorMsg", [[\r$]])
    end
  end,
})

-- vim.cmd("set mouse=") -- Uncomment to enable mouse
-- filetype detection/plugin/indent and syntax are on by default in Neovim
-- (:help nvim-defaults); re-enabling them only re-sources the runtime files.
vim.opt.title = true -- Display filename in terminal title bar

-- Pick up files changed on disk by another process: an AI agent or another
-- editor working in the same tree, a git checkout. 'autoread' (on by default)
-- only reloads when Neovim checks, and by itself it checks on focus changes.
local autoreload = vim.api.nvim_create_augroup('dotfiles_autoreload', { clear = true })
local function can_checktime()
  -- Not from the cmdline, cmdwin or a hit-enter/confirm prompt.
  return not vim.api.nvim_get_mode().mode:match('^[cr!]') and vim.fn.getcmdwintype() == ''
end
vim.api.nvim_create_autocmd({ 'FocusGained', 'BufEnter', 'TermLeave', 'CursorHold' }, {
  group = autoreload,
  callback = function()
    if can_checktime() then vim.cmd.checktime() end
  end,
})
-- While Neovim just sits there focused, none of those events fire, so also
-- poll once a second (one stat per buffer). Only unmodified file buffers: they
-- reload silently, whereas a clash with local edits puts up a prompt, and that
-- should come from an event above rather than land in the middle of typing.
vim.uv.new_timer():start(1000, 1000, vim.schedule_wrap(function()
  if not can_checktime() then return end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local name = vim.api.nvim_buf_get_name(buf)
    -- A deleted file is reported once by the events above; checking it every
    -- second would re-fire FileChangedShellPost every second.
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == ''
        and not vim.bo[buf].modified and name ~= '' and vim.uv.fs_stat(name) then
      vim.cmd.checktime(buf)
    end
  end
end))
vim.api.nvim_create_autocmd('FileChangedShellPost', {
  group = autoreload,
  callback = function(ev)
    vim.notify('Reloaded ' .. vim.fn.fnamemodify(ev.file, ':~:.') .. ' (changed on disk)')
  end,
})

-- No plugin here needs the perl/ruby/node/python3 hosts. Skipping them avoids
-- the interpreter probe at startup and keeps :checkhealth quiet.
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_node_provider = 0
vim.g.loaded_python3_provider = 0

-- Search for tags files up to the parent directory
vim.opt.tags = "./tags;,tags"

-- Gutentags enable-predicate (referenced by vim.g.gutentags_init_user_func)
_G.dotfiles_gutentags_enabled = function(file_path)
  local absolute_path = vim.fn.fnamemodify(file_path, ':p')
  if absolute_path == '' then
    return false
  end

  local dir = vim.fs.dirname(absolute_path)
  if not dir or dir == '' then
    return false
  end

  local git_dir = vim.fs.find('.git', {
    path = dir,
    upward = true,
    type = 'directory',
  })[1]
  if not git_dir then
    return false
  end

  local home = vim.loop.os_homedir()
  if home and home ~= '' and vim.fs.dirname(git_dir) == home then
    return false
  end

  return true
end

vim.cmd([[
function! DotfilesGutentagsEnabled(file_path) abort
  return v:lua.dotfiles_gutentags_enabled(a:file_path)
endfunction
]])

local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system {
    'git',
    'clone',
    '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable',
    lazypath,
  }
end
vim.opt.rtp:prepend(lazypath)

require('lazy').setup({
  { import = 'plugins' },
}, {
  performance = {
    rtp = {
      -- Archive/misc runtime plugins this config never reaches for. netrw and
      -- matchit stay enabled: they back `gx`, directory browsing and `%`.
      disabled_plugins = {
        'gzip',
        'tarPlugin',
        'zipPlugin',
        'tutor',
        'rplugin',
      },
    },
  },
})

-- Telescope keymaps live in lua/plugins/telescope.lua as lazy `keys` entries,
-- so pressing one loads Telescope instead of requiring it at startup.

-- Traditional: Built-in tag jump (instant movement)
-- Ctrl-] to go to definition, Ctrl-T to go back (Vim standard)
-- g] to select when there are multiple candidates
-- * This is default, so no need to add. Useful to remember!
