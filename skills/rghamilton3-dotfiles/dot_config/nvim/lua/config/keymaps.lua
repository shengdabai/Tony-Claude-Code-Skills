-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = vim.keymap.set

-- MicroPython development (using tio profiles from ~/.tioconfig)
-- Open REPL in wezterm split
map("n", "<leader>mp", function()
  vim.fn.system("wezterm cli split-pane --right -- tio rp2350")
end, { desc = "MicroPython REPL (RP2350/Presto)" })

map("n", "<leader>me", function()
  vim.fn.system("wezterm cli split-pane --right -- tio esp32")
end, { desc = "MicroPython REPL (ESP32/T-Embed)" })

-- Quick commands via TermExec
map("n", "<leader>mu", "<cmd>TermExec cmd='mpremote cp % :'<cr>", { desc = "Upload current file" })
map("n", "<leader>ms", "<cmd>TermExec cmd='mpremote run %'<cr>", { desc = "Run current file" })
map("n", "<leader>ml", "<cmd>TermExec cmd='mpremote ls'<cr>", { desc = "List files on device" })
map("n", "<leader>md", "<cmd>TermExec cmd='mpremote reset'<cr>", { desc = "Reset device" })

-- Toggle markdown checkbox
map("n", "<leader>T", function()
  local line = vim.api.nvim_get_current_line()
  local new_line

  if line:match("%- %[ %]") then
    -- Unchecked -> Checked
    new_line = line:gsub("%- %[ %]", "- [x]", 1)
  elseif line:match("%- %[x%]") then
    -- Checked -> Unchecked
    new_line = line:gsub("%- %[x%]", "- [ ]", 1)
  elseif line:match("%- %[X%]") then
    -- Uppercase X -> Unchecked
    new_line = line:gsub("%- %[X%]", "- [ ]", 1)
  else
    -- No checkbox found
    vim.notify("No markdown checkbox found on this line", vim.log.levels.WARN)
    return
  end

  vim.api.nvim_set_current_line(new_line)
end, { desc = "Toggle markdown checkbox" })
