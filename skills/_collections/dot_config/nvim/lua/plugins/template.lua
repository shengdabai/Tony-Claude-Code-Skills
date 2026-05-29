return {
  {
    "motosir/skel-nvim",
    config = function()
      require("skel-nvim").setup({
        -- Templates directory
        templates_dir = vim.fn.stdpath("config") .. "/skeleton/",

        -- Map filename patterns to template files
        mappings = {
          ["*.c"] = "skel.c",
          ["*.h"] = "skel.h",
          ["*.py"] = "skel.py",
          ["*.rs"] = "skel.rs",
          ["*.vue"] = "skel.vue",
        },

        -- Define placeholder substitutions
        substitutions = {
          ["AUTHOR"] = "Robert Hamilton",
          ["EMAIL"] = "robert@rghsoftware.com",
          ["YEAR"] = function()
            return os.date("%Y")
          end,
          ["DATE"] = function()
            return os.date("%Y-%m-%d")
          end,
          ["FILENAME"] = function()
            return vim.fn.expand("%:t")
          end,
          ["GUARD"] = function()
            local filename = vim.fn.expand("%:t:r")
            return string.upper(filename) .. "_H"
          end,
        },
      })
    end,
  },
}
