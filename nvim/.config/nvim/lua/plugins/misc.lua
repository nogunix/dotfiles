return {
  -- Pulled in on demand by lualine/telescope; nothing needs it at startup.
  { 'nvim-tree/nvim-web-devicons', lazy = true },
  { 'h-hg/fcitx.nvim', event = 'InsertEnter' },
  {
    'nogunix/vim-lsdyna',
    event = { 'BufReadPre *.k', 'BufReadPre *.key', 'BufNewFile *.k', 'BufNewFile *.key' },
  },
  {
    'lukas-reineke/indent-blankline.nvim',
    main = 'ibl',
    event = { 'BufReadPost', 'BufNewFile' },
    opts = {
      indent = { char = '│' },
      whitespace = { remove_blankline_trail = false },
    },
  },
}
