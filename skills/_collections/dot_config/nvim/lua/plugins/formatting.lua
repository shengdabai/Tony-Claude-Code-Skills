-- Formatting configuration with conform.nvim
return {
  {
    "stevearc/conform.nvim",
    opts = {
      -- LazyVim will automatically use conform for formatting
      -- No need to set format_on_save here

      -- Exclude chezmoi template files from formatting
      formatters_by_ft = {
        ["tmpl"] = {},  -- Disable formatters for .tmpl files
        markdown = { "markdownlint-cli2" },
      },
    },
  },
}
