return {
  -- MicroPython development support
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      -- Extend Pyright settings for MicroPython
      opts.servers = opts.servers or {}
      opts.servers.pyright = vim.tbl_deep_extend("force", opts.servers.pyright or {}, {
        settings = {
          python = {
            analysis = {
              -- Add MicroPython stubs path
              extraPaths = {
                vim.fn.stdpath("data") .. "/micropython-stubs",
              },
              -- Disable type checking for MicroPython-specific imports
              diagnosticSeverityOverrides = {
                reportMissingImports = "none",
                reportMissingModuleSource = "none",
              },
            },
          },
        },
      })
    end,
  },

  -- Serial monitor for MicroPython REPL
  {
    "miversen33/netman.nvim",
    lazy = false,
    config = function()
      require("netman")
    end,
  },

  -- Terminal helpers for MicroPython tools
  {
    "akinsho/toggleterm.nvim",
    opts = {
      size = function(term)
        if term.direction == "horizontal" then
          return 15
        elseif term.direction == "vertical" then
          return vim.o.columns * 0.4
        end
      end,
      open_mapping = [[<c-\>]],
      hide_numbers = true,
      shade_terminals = true,
      start_in_insert = true,
      insert_mappings = true,
      terminal_mappings = true,
      persist_size = true,
      direction = "horizontal",
      close_on_exit = true,
      shell = vim.o.shell,
    },
  },
}
