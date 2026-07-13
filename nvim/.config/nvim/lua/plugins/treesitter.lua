return {
  'nvim-treesitter/nvim-treesitter',
  enabled = false,
  branch = 'main',
  lazy = false,
  build = ':TSUpdate',
  config = function()
    require('nvim-treesitter').install({ 'c', 'lua', 'vim', 'vimdoc', 'query' })

    vim.api.nvim_create_autocmd('FileType', {
      pattern = { 'c', 'lua', 'vim', 'help', 'query' },
      callback = function()
        pcall(vim.treesitter.start)
      end,
    })
  end,
}
