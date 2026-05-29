return {
  {
    "akinsho/flutter-tools.nvim",
    lazy = false,
    dependencies = {
      "nvim-lua/plenary.nvim",
      "stevearc/dressing.nvim",
    },
    config = function()
      require("flutter-tools").setup({
        ui = {
          border = "rounded",
          notification_style = "native",
        },
        widget_guides = { enabled = true },
        closing_tags = {
          highlight = "Comment",
          prefix = " // ",
          enabled = true,
        },
        dev_log = {
          enabled = true,
          open_cmd = "15split",
          notify_errors = false,
        },
        dev_tools = {
          autostart = false,
          auto_open_browser = false,
        },
        lsp = {
          color = {
            enabled = true,
            background = false,
            virtual_text = true,
            virtual_text_str = "■",
          },
          settings = {
            showTodos = true,
            completeFunctionCalls = true,
            renameFilesWithClasses = "prompt",
            enableSnippets = true,
            analysisExcludedFolders = {
              vim.fn.expand("$HOME/flutter/packages"),
              vim.fn.expand("$HOME/.pub-cache"),
            },
          },
        },
        debugger = {
          enabled = true,
          run_via_dap = true,
        },
      })
    end,
  },
}
