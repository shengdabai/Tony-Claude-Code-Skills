-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
-- Auto-save (reduces cognitive load)
vim.opt.autowrite = true
vim.opt.autowriteall = true

-- Persistent undo (recover from mistakes)
vim.opt.undofile = true
vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir"

-- Smart case searching
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Better completion
vim.opt.completeopt = { "menu", "menuone", "noselect" }
vim.opt.pumheight = 10

-- Confirm instead of failing
vim.opt.confirm = true
vim.opt.autoread = true

-- Only use basedpyright
vim.g.lazyvim_python_lsp = "basedpyright"
