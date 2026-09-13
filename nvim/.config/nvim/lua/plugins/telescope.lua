-- Telescope stays unloaded until a picker keymap or :Telescope is used, so the
-- keymaps below are lazy `keys` entries rather than a top-level require.
local function picker(name)
  return function()
    require('telescope.builtin')[name]()
  end
end

return {
  {
    'nvim-telescope/telescope.nvim',
    dependencies = {
      'nvim-lua/plenary.nvim',
      {
        'nvim-telescope/telescope-fzf-native.nvim',
        build = 'make',
        cond = function() return vim.fn.executable('make') == 1 end,
      },
    },
    cmd = 'Telescope',
    keys = {
      -- LSP (selection with preview via Telescope)
      { 'gd', picker('lsp_definitions'), desc = 'LSP: Go to Definition (Telescope)' },
      { 'gr', picker('lsp_references'), desc = 'LSP: References (Telescope)' },
      { 'gi', picker('lsp_implementations'), desc = 'LSP: Implementations (Telescope)' },
      { 'gD', picker('lsp_type_definitions'), desc = 'LSP: Type Definitions (Telescope)' },
      { '<leader>ds', picker('lsp_document_symbols'), desc = 'LSP: Document Symbols' },
      { '<leader>ws', picker('lsp_dynamic_workspace_symbols'), desc = 'LSP: Workspace Symbols' },
      -- ctags (Telescope picker)
      { '<leader>tt', picker('tags'), desc = 'ctags: Project tags' },
      { '<leader>tb', picker('current_buffer_tags'), desc = 'ctags: Current buffer tags' },
    },
    config = function()
      local telescope = require('telescope')
      telescope.setup({
        defaults = {
          layout_strategy = 'horizontal',
          mappings = {
            i = { ['<C-h>'] = 'which_key' },
          },
        },
        pickers = {
          lsp_references = { fname_width = 80 },
          lsp_definitions = { fname_width = 80 },
          lsp_implementations = { fname_width = 80 },
          lsp_type_definitions = { fname_width = 80 },
        },
      })
      -- Loaded here rather than from its own spec: a separate spec would have to
      -- be eager, and its config would drag Telescope in at startup.
      pcall(telescope.load_extension, 'fzf')
    end,
  },
}
