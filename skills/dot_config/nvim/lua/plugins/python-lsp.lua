return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      -- Extend existing servers, don't replace
      opts.servers = opts.servers or {}

      opts.servers.basedpyright = {
        settings = {
          basedpyright = {
            analysis = {
              autoSearchPaths = true,
              typeCheckingMode = "standard",
              autoImportCompletions = true,
              diagnosticMode = "workspace",
              useLibraryCodeForTypes = true,
              diagnosticSeverityOverrides = {
                reportUnusedCallResult = false,
                reportAny = false,
                reportMissingTypeStubs = "information",
              },
            },
          },
        },
      }

      opts.servers.ruff = {
        settings = {
          lineLength = 88,
          lint = {
            select = { "E", "F", "I" }, -- Error, Pyflakes, Isort
          },
        },
      }

      -- Setup ruff to work alongside basedpyright
      opts.setup = opts.setup or {}
      opts.setup.ruff = function()
        Snacks.util.lsp.on({ name = "ruff" }, function(_, client)
          client.server_capabilities.hoverProvider = false
        end)
      end

      return opts
    end,
  },
}
