-- LSP servers to enable, with their settings. They are listed here rather than
-- discovered from mason so that they can start from nvim-lspconfig and the
-- built-in vim.lsp alone: mason is only needed to *install* servers, and
-- loading it costs ~20 ms, so it stays off the startup path. A server installed
-- through :Mason has to be added here before it is enabled.
local servers = {
  lua_ls = {
    settings = {
      Lua = {
        runtime = { version = 'LuaJIT' },
        diagnostics = { globals = { 'vim' } },
        workspace = {
          -- Neovim's own runtime only. Handing lua_ls every directory on the
          -- rtp (~2000 plugin files) took it ~3.7 s to index instead of ~1.4 s.
          library = { vim.env.VIMRUNTIME },
          checkThirdParty = false,
        },
        telemetry = { enable = false },
      },
    },
  },
}

return {
  {
    'neovim/nvim-lspconfig',
    event = { 'BufReadPre', 'BufNewFile' },
    config = function()
      vim.lsp.config('*', {
        on_attach = function(_, bufnr)
          vim.bo[bufnr].formatexpr = 'v:lua.vim.lsp.formatexpr(#{timeout_ms:250})'
        end,
      })
      for name, opts in pairs(servers) do
        vim.lsp.config(name, opts)
      end
      vim.lsp.enable(vim.tbl_keys(servers))

      -- First run on a new machine: load mason so that mason-lspconfig installs
      -- whatever is missing. Once installed, mason is never loaded again.
      for name in pairs(servers) do
        local cmd = vim.lsp.config[name].cmd
        if type(cmd) == 'table' and vim.fn.executable(cmd[1]) == 0 then
          vim.schedule(function()
            require('lazy').load({ plugins = { 'mason.nvim' } })
          end)
          break
        end
      end
    end,
  },
  {
    'williamboman/mason.nvim',
    dependencies = { 'williamboman/mason-lspconfig.nvim' },
    cmd = { 'Mason', 'MasonInstall', 'MasonUninstall', 'MasonUninstallAll', 'MasonUpdate', 'MasonLog' },
    init = function()
      -- mason.setup() prepends this itself. Doing it up front lets the servers
      -- it installed start without mason being loaded at all.
      local bin = vim.fn.stdpath('data') .. '/mason/bin'
      if not vim.tbl_contains(vim.split(vim.env.PATH or '', ':', { plain = true }), bin) then
        vim.env.PATH = bin .. ':' .. (vim.env.PATH or '')
      end
    end,
    config = function()
      require('mason').setup({})
      require('mason-lspconfig').setup({
        ensure_installed = vim.tbl_keys(servers),
        -- The servers table above decides what runs; don't let mason-lspconfig
        -- enable every installed server behind its back.
        automatic_enable = false,
      })
    end,
  },
}
