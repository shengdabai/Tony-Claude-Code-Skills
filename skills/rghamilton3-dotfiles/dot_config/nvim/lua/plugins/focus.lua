return {
  {
    "folke/zen-mode.nvim",
    cmd = "ZenMode",
    keys = {
      { "<leader>z", "<cmd>ZenMode<cr>", desc = "Zen Mode" },
    },
    opts = {
      window = {
        backdrop = 0.95,
        width = 100,
        height = 1,
        options = {
          number = false,
          relativenumber = false,
          signcolumn = "no",
          cursorline = false,
          foldcolumn = "0",
        },
      },
      plugins = {
        options = {
          enabled = true,
          ruler = false,
          showcmd = false,
          laststatus = 0,
        },
        twilight = { enabled = true },
        gitsigns = { enabled = false },
        tmux = { enabled = false },
      },
      on_open = function()
        vim.diagnostic.config({ virtual_text = false })
      end,
      on_close = function()
        vim.diagnostic.config({ virtual_text = true })
      end,
    },
  },

  {
    "folke/twilight.nvim",
    opts = {
      dimming = {
        alpha = 0.25,
        inactive = true,
      },
      context = 15,
    },
  },

  -- Pomodoro timer for time-boxing
  {
    "epwalsh/pomo.nvim",
    cmd = { "TimerStart", "TimerRepeat" },
    keys = {
      { "<leader>tp", "<cmd>TimerStart 25m<cr>", desc = "Start Pomodoro" },
      { "<leader>tb", "<cmd>TimerStart 5m<cr>", desc = "Start Break" },
    },
    opts = {
      notifiers = {
        { name = "Default" },
        { name = "System" },
      },
    },
  },

  -- Centered buffer for reduced distraction
  {
    "shortcuts/no-neck-pain.nvim",
    cmd = "NoNeckPain",
    keys = {
      { "<leader>zn", "<cmd>NoNeckPain<cr>", desc = "No Neck Pain" },
    },
    opts = {
      width = 100,
      autocmds = {
        enableOnVimEnter = false,
        enableOnTabEnter = false,
      },
    },
  },
}
