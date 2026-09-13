local function setup_lualine()
  require('lualine').setup({
    options = {
      icons_enabled = true,
      theme = 'auto',
    },
  })
end

return {
  'nvim-lualine/lualine.nvim',
  event = 'VeryLazy',
  config = function()
    setup_lualine()
    vim.api.nvim_create_autocmd('FileType', {
      pattern = 'lsdyna',
      callback = setup_lualine,
    })
    vim.api.nvim_create_autocmd('ColorScheme', {
      callback = setup_lualine,
    })
  end,
}
