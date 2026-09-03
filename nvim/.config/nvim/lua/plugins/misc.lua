return {
  { 'nvim-tree/nvim-web-devicons' },
  { 'h-hg/fcitx.nvim' },
  {
    'nogunix/vim-lsdyna',
    event = { 'BufReadPre *.k', 'BufReadPre *.key', 'BufNewFile *.k', 'BufNewFile *.key' },
  },
  {
    'lukas-reineke/indent-blankline.nvim',
    main = 'ibl',
    opts = {
      indent = { char = '│' },
      whitespace = { remove_blankline_trail = false },
    },
  },
}
