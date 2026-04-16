-- Sagan Code LSP Configuration for SAT Project
-- Place this in your Neovim config or source it from init.lua

local configs = require('lspconfig.configs')
local util = require('lspconfig.util')

if not configs.sagan_code then
  configs.sagan_code = {
    default_config = {
      cmd = { 'lsp-ai', '--config', vim.fn.expand('~/workspace/sat/.sagan-code.json') },
      filetypes = { 'c', 'cpp', 'h', 'hpp' },
      root_dir = util.root_pattern('.sagan-code.json', '.git', 'Makefile', 'CMakeLists.txt'),
      settings = {},
    },
  }
end

require('lspconfig').sagan_code.setup({
  on_attach = function(client, bufnr)
    local opts = { buffer = bufnr, noremap = true, silent = true }

    -- Custom keybindings for cFS development
    vim.keymap.set('n', '<leader>ce', function()
      vim.lsp.buf.code_action({
        filter = function(action)
          return action.title:match("Explain")
        end,
        apply = true,
      })
    end, { buffer = bufnr, desc = "Explain C Code" })

    vim.keymap.set('n', '<leader>cr', function()
      vim.lsp.buf.code_action({
        filter = function(action)
          return action.title:match("Review")
        end,
        apply = true,
      })
    end, { buffer = bufnr, desc = "Review Embedded Code" })

    vim.keymap.set('n', '<leader>cd', function()
      vim.lsp.buf.code_action({
        filter = function(action)
          return action.title:match("Debug")
        end,
        apply = true,
      })
    end, { buffer = bufnr, desc = "Debug Flight Software" })

    vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action,
      { buffer = bufnr, desc = "All code actions" })

    -- Hover for quick documentation
    vim.keymap.set('n', 'K', vim.lsp.buf.hover,
      { buffer = bufnr, desc = "Hover documentation" })

    -- Status message
    vim.notify("🚀 Sagan Code LSP ready for SAT cFS project!", vim.log.levels.INFO)
  end,

  -- Custom handlers for better UI
  handlers = {
    ["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, {
      border = "rounded",
      max_width = 80,
    }),
    ["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, {
      border = "rounded",
    }),
  },
})
