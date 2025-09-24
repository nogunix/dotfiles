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
-- vim.cmd("set mouse=") -- Uncomment to enable mouse
vim.cmd('filetype plugin indent on') -- Enable file type detection, plugins, and indentation
vim.cmd('syntax on')                -- Enable syntax highlighting
vim.opt.title = true                -- Display filename in terminal title bar

-- ## Plugin Management (`lazy.nvim`)

-- ```lua
-- [[ Install `lazy.nvim` plugin manager ]]
--    [https://github.com/folke/lazy.nvim](https://github.com/folke/lazy.nvim)
--    `:help lazy.nvim.txt` for more info
local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system {
    'git',
    'clone',
    '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable', -- latest stable release
    lazypath,
  }
end
vim.opt.rtp:prepend(lazypath)
require('lazy').setup({
  -- NOTE: First, some plugins that don't require any configuration
  { 'lervag/vimtex' },
  { 'nvim-tree/nvim-web-devicons' },
  { 'github/copilot.vim' },
  { 'h-hg/fcitx.nvim' },
  {
    "nogunix/vim-lsdyna",
    event = { "BufReadPre *.k", "BufReadPre *.key", "BufNewFile *.k", "BufNewFile *.key" },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup {
        ensure_installed = { "c", "lua", "rust" },
        highlight = {
          enable = true,
          -- Avoid Invalid 'end_row' errors for filetypes with unstable parsers
          disable = { "markdown", "tex" },
        }
      }
    end
  },
  {
    'hrsh7th/nvim-cmp',
    dependencies = {
      'hrsh7th/cmp-nvim-lsp',
      'hrsh7th/cmp-buffer',
      'L3MON4D3/LuaSnip',
      'saadparwaiz1/cmp_luasnip',
    },
    config = function()
      local cmp = require('cmp')
      local luasnip = require('luasnip')

      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ['<C-b>'] = cmp.mapping.scroll_docs(-4),
          ['<C-f>'] = cmp.mapping.scroll_docs(4),
          ['<C-Space>'] = cmp.mapping.complete(),
          ['<C-e>'] = cmp.mapping.abort(),
          ['<CR>'] = cmp.mapping.confirm({ select = true }),
        }),
        sources = cmp.config.sources({
          { name = 'nvim_lsp' },
          { name = 'luasnip' },
        }, { { name = 'buffer' } })
      })
    end
  },

  -- Theme
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    opts = {},
    config = function()
      vim.cmd.colorscheme 'tokyonight'
    end
  },

  -- LSP and Mason
  {
    'williamboman/mason.nvim',
    dependencies = {
      "williamboman/mason-lspconfig.nvim",
      "neovim/nvim-lspconfig",
      "nvim-lua/plenary.nvim",
    },
    event = "VeryLazy",
    config = function()
      require("mason").setup {}
      local mason_lspconfig = require("mason-lspconfig")
      local on_attach = function(_, bufnr)
        vim.api.nvim_buf_set_option(bufnr, "formatexpr",
          "v:lua.vim.lsp.formatexpr(#{timeout_ms:250})")
        -- If necessary, you can define and call a global function like lsp_onattach_func here.
        -- _G.lsp_onattach_func(i, bufnr)
      end

      -- Add LSP servers you want to install automatically here
      -- You can add servers you want to install automatically to `ensure_installed`.
      -- 例: ensure_installed = { "lua_ls", "rust_analyzer", "omnisharp" }
      mason_lspconfig.setup({
        ensure_installed = { "lua_ls" }, -- この設定ファイル自体を編集するためにlua_lsを追加
      })

      local lspconfig = require("lspconfig")

      -- サーバーごとのカスタム設定
      local lua_settings = {
        settings = {
          Lua = {
            runtime = { version = 'LuaJIT' },
            diagnostics = { globals = { 'vim' } },
            workspace = {
              library = vim.api.nvim_get_runtime_file('', true),
              checkThirdParty = false,
            },
            telemetry = { enable = false },
          },
        },
      }
      local server_settings = {
        lua_ls = lua_settings,
        -- Corresponding to older server names (sumneko_lua)
        sumneko_lua = lua_settings,
        omnisharp = { useGlobalMono = "always" },
        -- Add other server settings here
        -- rust_analyzer = { ... }
      }

      -- インストール済みのサーバーをセットアップ
      for _, server_name in ipairs(mason_lspconfig.get_installed_servers()) do
        local opts = { on_attach = on_attach }
        -- カスタム設定があればマージする
        if server_settings[server_name] then
          opts = vim.tbl_deep_extend("force", opts, server_settings[server_name])
        end
        lspconfig[server_name].setup(opts)
      end
      --       -- This command is usually not necessary as Mason and lspconfig manage the servers.
    end,
  },
    -- Lualine (Statusline)
    require('plugins.lualine'),
  -- Markdown Preview
  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    build = "cd app && yarn install",
    init = function()
      vim.g.mkdp_filetypes = { "markdown" }
    end,
    ft = { "markdown" },
  },
  -- === Telescope Core + Basic Settings ===
{
  'nvim-telescope/telescope.nvim',
  dependencies = { 'nvim-lua/plenary.nvim' },
  cmd = 'Telescope',
  config = function()
    local telescope = require('telescope')
    telescope.setup({
      defaults = {
        layout_strategy = 'horizontal',
        mappings = {
          i = { ['<C-h>'] = 'which_key' },
        },
        -- If ripgrep is installed, live_grep can be used: sudo dnf install ripgrep
      },
      pickers = {
        -- Quickly select frequently used ones
        lsp_references = { fname_width = 80 },
        lsp_definitions = { fname_width = 80 },
        lsp_implementations = { fname_width = 80 },
        lsp_type_definitions = { fname_width = 80 },
      },
    })
  end,
},

-- === fzf-like fast sorter (optional but highly recommended) ===
{
  'nvim-telescope/telescope-fzf-native.nvim',
  build = 'make',
  cond = function() return vim.fn.executable('make') == 1 end,
  config = function()
    pcall(require('telescope').load_extension, 'fzf')
  end,
},

-- === If you want to auto-update ctags (very common) ===
{
  'ludovicchabant/vim-gutentags',
  init = function()
    -- Auto-generate tags in the project root
        -- Assumes universal-ctags
    vim.g.gutentags_project_root = { '.git', '.hg', '.svn', 'Makefile', 'package.json' }
    vim.g.gutentags_ctags_extra_args = {
      '--fields=+l', '--extras=+q', '--kinds-C=+p', '--kinds-c++=+p',
      '--exclude=.git', '--exclude=node_modules', '--exclude=build', '--exclude=dist',
    }
        -- Cache location
    -- NOTE: If it feels slow in large repositories, you can stop auto-generation and operate manually.
  end,
},
})
-- Viewer options: One may configure the viewer either by specifying a built-in
-- viewer method:
vim.g.vimtex_view_method = 'zathura'

-- Or with a generic interface:
vim.g.vimtex_view_general_viewer = 'evince'
vim.g.vimtex_view_general_options = {
  unique = true,
  file = '@pdf',
  src = '@line@tex'
}

-- VimTeX uses latexmk as the default compiler backend. If you use it, which is
-- strongly recommended, you probably don't need to configure anything. If you
-- want another compiler backend, you can change it as follows. The list of
-- supported backends and further explanation is provided in the documentation,
-- see ":help vimtex-compiler".
vim.g.vimtex_compiler_method = 'latexmk'

-- Most VimTeX mappings rely on localleader and this can be changed with the
-- following line. The default is usually fine and is the symbol "\".
-- vim.cmd('let maplocalleader = ", "')
--
-- Search for tags files up to the parent directory
vim.opt.tags = "./tags;,tags"

-- Telescope keymaps that are less likely to conflict with existing keybindings
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

