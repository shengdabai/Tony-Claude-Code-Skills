return {
  {
    "kristijanhusak/vim-dadbod-ui",
    dependencies = {
      { "tpope/vim-dadbod", lazy = true },
      { "kristijanhusak/vim-dadbod-completion", ft = { "sql", "mysql", "plsql" }, lazy = true },
    },
    cmd = { "DBUI", "DBUIToggle", "DBUIAddConnection" },
    keys = {
      { "<leader>D", "<cmd>DBUIToggle<cr>", desc = "Toggle DB UI" },
    },
    config = function()
      vim.g.db_ui_use_nerd_fonts = 1
      vim.g.db_ui_show_database_icon = 1
      vim.g.db_ui_save_location = "~/.local/share/db_ui"

      -- Configure databases
      vim.g.dbs = {
        altair_dev = "postgresql://localhost:5432/altair_dev",
        altair_test = "postgresql://localhost:5432/altair_test",
      }
    end,
  },

  -- SQL formatter
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        sql = { "sql_formatter" },
      },
      formatters = {
        sql_formatter = {
          prepend_args = { "-l", "postgresql" },
        },
      },
    },
  },
}
