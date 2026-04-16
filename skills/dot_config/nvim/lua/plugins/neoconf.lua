return {
  "folke/neoconf.nvim",
  cmd = "Neoconf",
  config = function()
    require("neoconf").setup({
      import = {
        vscode = true, -- .vscode/settings.json
        coc = true, -- coc-settings.json
      },
      live_reload = true,
      filetype_jsonc = true,
      plugins = {
        lspconfig = { enabled = true },
        jsonls = {
          enabled = true,
          configured_servers_only = true,
        },
      },
    })
  end,
}
