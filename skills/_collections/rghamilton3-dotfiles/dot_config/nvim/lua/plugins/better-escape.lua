return {
  {
    "max397574/better-escape.nvim",
    config = function()
      require("better_escape").setup({
        mappings = {
          i = {
            j = {
              o = "<Esc>o",
              O = "<Esc>O",
              l = "<Esc>A",
              h = "<Esc>I",
            },
          },
        },
      })
    end,
  },
}
