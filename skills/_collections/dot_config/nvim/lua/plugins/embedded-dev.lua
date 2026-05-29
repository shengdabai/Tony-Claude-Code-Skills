return {
  -- Enhanced C/C++ support
  -- This is now handled by neoconf
  -- {
  --   "neovim/nvim-lspconfig",
  --   opts = {
  --     servers = {
  --       clangd = {
  --         cmd = {
  --           "clangd",
  --           "--background-index",
  --           "--clang-tidy",
  --           "--header-insertion=iwyu",
  --           "--completion-style=detailed",
  --           "--function-arg-placeholders=1",
  --         },
  --         filetypes = { "c", "cpp", "objc", "objcpp", "cuda" },
  --       },
  --     },
  --   },
  -- },

  -- CMake support
  {
    "Civitasv/cmake-tools.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {
      cmake_build_directory = "build",
      cmake_regenerate_on_save = false,
    },
  },

  -- Serial monitor for embedded debugging
  {
    "kkharji/sqlite.lua",
  },

  -- Git integration (enhanced)
  {
    "NeogitOrg/neogit",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "sindrets/diffview.nvim",
      "nvim-telescope/telescope.nvim",
    },
    config = true,
  },
}
