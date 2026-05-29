return {
  {
    "eriks47/generate.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    ft = { "c", "cpp" },
    config = function()
      -- Wrapper command that uses ouroboros path logic with generate.nvim
      vim.api.nvim_create_user_command("GenerateKairos", function()
        local header_path = vim.api.nvim_buf_get_name(0)
        
        -- Transform path: include/kairos/*.h -> kairos/*.cpp
        local source_path = header_path:gsub("/include/kairos/", "/kairos/"):gsub("%.h$", ".cpp"):gsub("%.hpp$", ".cpp")
        
        -- Get header declarations
        local header = require("generate.header")
        local ts = vim.treesitter
        local parser = ts.get_parser()
        local root = parser:parse()[1]:root()
        local namespaces = header.get_declarations(root)
        
        -- Switch to/create source file
        vim.cmd("edit " .. source_path)
        
        -- Insert implementations
        local source = require("generate.source")
        source.header_bufnr = vim.fn.bufnr(header_path)
        source.implement_methods(namespaces)
        
        vim.notify("Generated implementations in " .. vim.fn.fnamemodify(source_path, ":t"))
      end, { desc = "Generate C++ implementations (Kairos structure)" })
    end,
    keys = {
      { "<leader>cg", "<cmd>GenerateKairos<cr>", desc = "Generate Implementations", ft = { "c", "cpp" } },
    },
  },
  {
    "jakemason/ouroboros.nvim",
    lazy = false,
    opts = {
      switch_to_open = true,
      -- Handle Kairos project structure: include/kairos/*.h <-> kairos/*.cpp
      switch_patterns = {
        { "include/kairos/(.*)%.h", "kairos/%1.cpp" },
        { "include/kairos/(.*)%.hpp", "kairos/%1.cpp" },
      },
    },
    keys = {
      { "<leader>ch", "<cmd>Ouroboros<cr>", desc = "Switch Header/Implementation" },
    },
  },
}
