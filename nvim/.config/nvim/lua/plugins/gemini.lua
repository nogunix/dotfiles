-- ~/.config/nvim/lua/plugins/gemini.lua
return {
  "robitx/gp.nvim",
  config = function()
    require("gp").setup({
      providers = {
        googleai = {
          endpoint = "https://generativelanguage.googleapis.com/v1beta/models/{{model}}:streamGenerateContent?key={{secret}}",
          secret = os.getenv("GOOGLEAI_API_KEY"),
        },
      },
      agents = {
        {
          name = "Gemini-Flash",
          provider = "googleai",
          chat = true,
          command = true,
          model = { model = "gemini-1.5-flash" },
        },
      },
    })

    -- キーマップ例
    vim.keymap.set("n", "<leader>gg", function()
      require("gp").chat_toggle()
    end, { desc = "Gemini chat (gp.nvim)" })
  end,
}

