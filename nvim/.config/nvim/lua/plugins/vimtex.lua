return {
  'lervag/vimtex',
  init = function()
    vim.g.vimtex_view_method = 'zathura'
    vim.g.vimtex_view_general_viewer = 'evince'
    vim.g.vimtex_view_general_options = {
      unique = true,
      file = '@pdf',
      src = '@line@tex',
    }
    vim.g.vimtex_compiler_method = 'latexmk'
  end,
}
