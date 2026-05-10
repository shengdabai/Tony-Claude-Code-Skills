return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        ruby_lsp = {
          mason = false,
          cmd = { "/usr/bin/ruby-lsp" },
        },
      },
    },
  },
}
