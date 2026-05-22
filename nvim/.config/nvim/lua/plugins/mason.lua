return {
  'williamboman/mason.nvim',
  dependencies = {
    'williamboman/mason-lspconfig.nvim',
    'neovim/nvim-lspconfig',
    'nvim-lua/plenary.nvim',
  },
  event = 'VeryLazy',
  config = function()
    require('mason').setup({})
    local mason_lspconfig = require('mason-lspconfig')
    local on_attach = function(_, bufnr)
      vim.api.nvim_buf_set_option(bufnr, 'formatexpr',
        'v:lua.vim.lsp.formatexpr(#{timeout_ms:250})')
    end

    mason_lspconfig.setup({
      ensure_installed = { 'lua_ls' },
    })

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
      sumneko_lua = lua_settings,
      omnisharp = { useGlobalMono = 'always' },
    }

    for _, server_name in ipairs(mason_lspconfig.get_installed_servers()) do
      local opts = { on_attach = on_attach }
      if server_settings[server_name] then
        opts = vim.tbl_deep_extend('force', opts, server_settings[server_name])
      end
      vim.lsp.config(server_name, opts)
    end
  end,
}
