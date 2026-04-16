return {
  -- ROS2 specific plugin
  {
    "thibthib18/ros-nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("ros-nvim").setup({
        catkin_ws_path = vim.fn.expand("~/ros2_ws"),
        catkin_program = "colcon",
      })
    end,
  },

  -- LSP configuration for C++ and Python
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- C++ LSP with ROS2 support
        clangd = {
          cmd = {
            "clangd",
            "--background-index",
            "--clang-tidy",
            "--header-insertion=iwyu",
            "--completion-style=detailed",
            "--function-arg-placeholders",
          },
          root_dir = function(fname)
            return require("lspconfig.util").root_pattern("compile_commands.json", ".clangd")(fname)
          end,
        },
        -- Python LSP with ROS2 paths
        basedpyright = {
          settings = {
            python = {
              analysis = {
                extraPaths = {
                  "/opt/ros/jazzy/lib/python3.12/site-packages",
                },
              },
            },
          },
        },
      },
    },
  },
}
