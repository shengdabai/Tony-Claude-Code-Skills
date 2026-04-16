return {
  {
    -- "NickvanDyke/opencode.nvim",
    -- dependencies = {
    --   -- Recommended for `ask()` and `select()`.
    --   -- Required for default `toggle()` implementation.
    --   { "folke/snacks.nvim", opts = { input = {}, picker = {}, terminal = {} } },
    -- },
    -- config = function()
    --   ---@type opencode.Opts
    --   vim.g.opencode_opts = {
    --     -- Your configuration, if any — see `lua/opencode/config.lua`, or "goto definition".
    --   }
    --
    --   -- Required for `opts.auto_reload`.
    --   vim.o.autoread = true
    --
    --   -- Conflict-free keymaps using <leader> prefix.
    --   vim.keymap.set({ "n", "x" }, "<leader>oa", function()
    --     require("opencode").ask("@this: ", { submit = true })
    --   end, { desc = "OpenCode: Ask" })
    --   vim.keymap.set({ "n", "x" }, "<leader>ox", function()
    --     require("opencode").select()
    --   end, { desc = "OpenCode: Execute action" })
    --   vim.keymap.set({ "n", "x" }, "<leader>op", function()
    --     require("opencode").prompt("@this")
    --   end, { desc = "OpenCode: Add to prompt" })
    --   vim.keymap.set({ "n", "t" }, "<leader>ot", function()
    --     require("opencode").toggle()
    --   end, { desc = "OpenCode: Toggle" })
    --   vim.keymap.set("n", "<leader>ou", function()
    --     require("opencode").command("session.half.page.up")
    --   end, { desc = "OpenCode: Half page up" })
    --   vim.keymap.set("n", "<leader>od", function()
    --     require("opencode").command("session.half.page.down")
    --   end, { desc = "OpenCode: Half page down" })
    -- end,
  },
}
