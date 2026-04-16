return {
  {
    "folke/which-key.nvim",
    opts = function(_, opts)
      opts.spec = opts.spec or {}
      table.insert(opts.spec, { "<leader>r", group = "ros2", icon = "🤖" })
    end,
  },
  {
    "nvim-lua/plenary.nvim",
    config = function()
      local map = vim.keymap.set
      -- Colcon build commands
      map(
        "n",
        "<leader>rb",
        ":!colcon build --symlink-install --cmake-args -DCMAKE_EXPORT_COMPILE_COMMANDS=ON<CR>",
        { desc = "Colcon Build All" }
      )
      map("n", "<leader>rB", ":!colcon build --symlink-install --packages-select ", { desc = "Colcon Build Package" })
      map("n", "<leader>rt", ":!colcon test<CR>", { desc = "Colcon Test" })
      map("n", "<leader>rc", ":!colcon test --packages-select ", { desc = "Colcon Test Package" })
      -- ROS2 introspection
      map("n", "<leader>rn", ":!ros2 node list<CR>", { desc = "List Nodes" })
      map("n", "<leader>rl", ":!ros2 topic list<CR>", { desc = "List Topics" })
      map("n", "<leader>rs", ":!ros2 service list<CR>", { desc = "List Services" })
    end,
  },
}
