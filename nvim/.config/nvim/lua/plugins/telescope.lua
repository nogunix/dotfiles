return {
  {
    'nvim-telescope/telescope.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    cmd = 'Telescope',
    config = function()
      require('telescope').setup({
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
    end,
  },
  {
    'nvim-telescope/telescope-fzf-native.nvim',
    build = 'make',
    cond = function() return vim.fn.executable('make') == 1 end,
    config = function()
      pcall(require('telescope').load_extension, 'fzf')
    end,
  },
}
