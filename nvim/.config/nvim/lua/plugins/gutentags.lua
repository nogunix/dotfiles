return {
  'ludovicchabant/vim-gutentags',
  init = function()
    local homebrew_ctags = '/opt/homebrew/bin/ctags'

    vim.g.gutentags_add_default_project_roots = 0
    vim.g.gutentags_add_ctrlp_root_markers = 0
    vim.g.gutentags_generate_on_missing = 0
    vim.g.gutentags_init_user_func = 'DotfilesGutentagsEnabled'
    vim.g.gutentags_project_root = { '.git' }
    if vim.fn.has('macunix') == 1 and vim.fn.executable(homebrew_ctags) == 1 then
      vim.g.gutentags_ctags_executable = homebrew_ctags
    elseif vim.fn.has('unix') == 1 then
      vim.g.gutentags_ctags_executable = 'ctags'
    end
    vim.g.gutentags_ctags_extra_args = {
      '--fields=+l', '--extras=+q', '--kinds-C=+p', '--kinds-c++=+p',
      '--exclude=.git', '--exclude=node_modules', '--exclude=build', '--exclude=dist',
    }
    vim.g.gutentags_cache_dir = vim.fn.stdpath('cache') .. '/tags'
  end,
}
