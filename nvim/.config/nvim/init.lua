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
vim.cmd('filetype plugin indent on') -- Enable file type detection, plugins, and indentation
vim.cmd('syntax on')                -- Enable syntax highlighting
vim.opt.title = true                -- Display filename in terminal title bar

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
})

-- Telescope keymaps (kept at top level so they bind without :Telescope first)
local tb = require('telescope.builtin')

-- LSP (selection with preview via Telescope)
vim.keymap.set('n', 'gd', tb.lsp_definitions,        { desc = 'LSP: Go to Definition (Telescope)' })
vim.keymap.set('n', 'gr', tb.lsp_references,         { desc = 'LSP: References (Telescope)' })
vim.keymap.set('n', 'gi', tb.lsp_implementations,    { desc = 'LSP: Implementations (Telescope)' })
vim.keymap.set('n', 'gD', tb.lsp_type_definitions,   { desc = 'LSP: Type Definitions (Telescope)' })
vim.keymap.set('n', '<leader>ds', tb.lsp_document_symbols, { desc = 'LSP: Document Symbols' })
vim.keymap.set('n', '<leader>ws', tb.lsp_dynamic_workspace_symbols, { desc = 'LSP: Workspace Symbols' })

-- ctags (Telescope picker)
vim.keymap.set('n', '<leader>tt', tb.tags,           { desc = 'ctags: Project tags' })
vim.keymap.set('n', '<leader>tb', tb.current_buffer_tags, { desc = 'ctags: Current buffer tags' })

-- Traditional: Built-in tag jump (instant movement)
-- Ctrl-] to go to definition, Ctrl-T to go back (Vim standard)
-- g] to select when there are multiple candidates
-- * This is default, so no need to add. Useful to remember!
