-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Load project-specific commands from .neoconf.json
local function load_project_commands()
  local cwd = vim.fn.getcwd()
  local neoconf_file = cwd .. "/.neoconf.json"

  if vim.fn.filereadable(neoconf_file) == 1 then
    local ok, config = pcall(vim.fn.json_decode, vim.fn.readfile(neoconf_file))
    if ok and config.commands then
      for cmd_name, cmd_config in pairs(config.commands) do
        vim.api.nvim_create_user_command(cmd_name, function()
          vim.cmd(cmd_config.command)
        end, {
          desc = cmd_config.description or "",
        })
      end
    end
  end
end

-- Load commands when entering a directory
vim.api.nvim_create_autocmd({ "VimEnter", "DirChanged" }, {
  callback = load_project_commands,
})

-- Framework-specific commands moved to neoconf templates
-- See ~/.config/nvim/templates/ for project-local configuration examples

-- Disable auto-formatting for chezmoi templates
-- Prevents formatters from adding spaces to Go template delimiters (e.g., {{- becomes { { -)
vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
  pattern = { "*.tmpl" },
  callback = function()
    -- Disable format on save
    vim.b.autoformat = false

    -- Set filetype to the base file type for syntax highlighting
    -- e.g., config.fish.tmpl -> fish, env.fish.tmpl -> fish
    local filename = vim.fn.expand("%:t")
    if filename:match("%.fish%.tmpl$") then
      vim.bo.filetype = "fish"
    elseif filename:match("%.sh%.tmpl$") then
      vim.bo.filetype = "sh"
    elseif filename:match("%.yaml%.tmpl$") or filename:match("%.yml%.tmpl$") then
      vim.bo.filetype = "yaml"
    end
  end,
  desc = "Disable formatting for chezmoi templates",
})

-- Don't auto-insert comment leader on new lines
-- r - Auto-insert comment leader after hitting <Enter> in Insert mode
-- o - Auto-insert comment leader after hitting o or O in Normal mode
vim.api.nvim_create_autocmd("FileType", {
  pattern = "*",
  callback = function()
    vim.opt_local.formatoptions:remove({ "r", "o" })
  end,
})
