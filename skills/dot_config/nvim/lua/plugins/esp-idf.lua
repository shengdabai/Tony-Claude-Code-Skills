-- ESP-IDF Development Plugin for LazyVim
return {
  -- Ensure clangd is configured via neoconf
  {
    "folke/neoconf.nvim",
    opts = {},
  },

  -- ESP-IDF specific autocmds and keymaps
  {
    "LazyVim/LazyVim",
    opts = function(_, opts)
      -- Auto-detect ESP-IDF projects
      vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
        pattern = { "*.c", "*.cpp", "*.h", "*.hpp" },
        callback = function(ev)
          -- Check if we're in an ESP-IDF project (has sdkconfig or idf_component.yml)
          local root = vim.fs.dirname(vim.fs.find({ "sdkconfig", "idf_component.yml", "partitions.csv" }, {
            upward = true,
            path = ev.file,
          })[1])

          if root then
            vim.b.esp_idf_project = true
            vim.b.esp_idf_root = root

            -- Set buffer-local options
            vim.opt_local.tabstop = 4
            vim.opt_local.shiftwidth = 4
            vim.opt_local.expandtab = true
            vim.opt_local.textwidth = 120

            -- Set formatprg to clang-format
            vim.opt_local.formatprg = "clang-format"
          end
        end,
      })

      -- Add ESP-IDF specific keymaps
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "c", "cpp" },
        callback = function()
          if not vim.b.esp_idf_project then
            return
          end

          local root = vim.b.esp_idf_root or vim.fn.getcwd()

          -- Helper to run commands in firmware directory
          local function esp_cmd(cmd)
            -- Find firmware directory (either current or parent)
            local firmware_dir = root
            if not vim.fn.isdirectory(firmware_dir .. "/build") then
              firmware_dir = vim.fn.fnamemodify(root, ":h") .. "/firmware"
            end

            return string.format(":!cd %s && %s<CR>", vim.fn.shellescape(firmware_dir), cmd)
          end

          -- Build commands with <leader>B prefix (B for Build/Board)
          vim.keymap.set("n", "<leader>Bb", esp_cmd("idf.py build"), {
            buffer = true,
            desc = "ESP-IDF: Build",
          })

          vim.keymap.set("n", "<leader>Bf", esp_cmd("idf.py -p /dev/ttyUSB0 flash"), {
            buffer = true,
            desc = "ESP-IDF: Flash",
          })

          vim.keymap.set("n", "<leader>Bm", esp_cmd("idf.py -p /dev/ttyUSB0 monitor"), {
            buffer = true,
            desc = "ESP-IDF: Monitor",
          })

          vim.keymap.set("n", "<leader>BM", esp_cmd("idf.py -p /dev/ttyUSB0 flash monitor"), {
            buffer = true,
            desc = "ESP-IDF: Flash + Monitor",
          })

          vim.keymap.set("n", "<leader>Bc", esp_cmd("idf.py fullclean"), {
            buffer = true,
            desc = "ESP-IDF: Clean",
          })

          vim.keymap.set("n", "<leader>Br", esp_cmd("idf.py reconfigure"), {
            buffer = true,
            desc = "ESP-IDF: Reconfigure",
          })

          vim.keymap.set("n", "<leader>BC", esp_cmd("idf.py menuconfig"), {
            buffer = true,
            desc = "ESP-IDF: MenuConfig",
          })

          vim.keymap.set("n", "<leader>Be", esp_cmd("idf.py erase-flash"), {
            buffer = true,
            desc = "ESP-IDF: Erase Flash",
          })

          vim.keymap.set("n", "<leader>Bs", esp_cmd("idf.py size"), {
            buffer = true,
            desc = "ESP-IDF: Show Size",
          })
        end,
      })

      -- User commands (global, not buffer-local)
      vim.api.nvim_create_user_command("ESPRefreshCompileDB", function()
        local root = vim.b.esp_idf_root or vim.fn.getcwd()
        local firmware_dir = root
        if not vim.fn.isdirectory(firmware_dir .. "/build") then
          firmware_dir = vim.fn.fnamemodify(root, ":h") .. "/firmware"
        end

        vim.notify("Refreshing ESP-IDF compile_commands.json...", vim.log.levels.INFO)
        vim.fn.system(string.format("cd %s && idf.py reconfigure", vim.fn.shellescape(firmware_dir)))

        if vim.v.shell_error == 0 then
          vim.cmd("LspRestart")
          vim.notify("ESP-IDF compile_commands.json refreshed!", vim.log.levels.INFO)
        else
          vim.notify("Failed to refresh compile_commands.json", vim.log.levels.ERROR)
        end
      end, { desc = "Refresh ESP-IDF compilation database" })

      vim.api.nvim_create_user_command("ESPInfo", function()
        local info = {
          "ESP-IDF Toolchain Information:",
          "├─ Compiler: GCC 14.2.0",
          "├─ Target: ESP32-P4 (RISC-V)",
          "├─ Architecture: rv32imafc_zicsr_zifencei",
          "├─ ABI: ilp32f",
          "├─ Build Dir: firmware/build",
          "└─ Compile DB: firmware/build/compile_commands.json",
          "",
          "Quick Commands (in C/C++ buffers):",
          "├─ <leader>Bb - Build",
          "├─ <leader>Bf - Flash",
          "├─ <leader>Bm - Monitor",
          "├─ <leader>BM - Flash + Monitor",
          "├─ <leader>Bc - Clean",
          "├─ <leader>Br - Reconfigure",
          "├─ <leader>BC - MenuConfig",
          "├─ <leader>Be - Erase Flash",
          "└─ <leader>Bs - Show Size",
          "",
          "Global Commands:",
          "├─ :ESPInfo - Show this info",
          "└─ :ESPRefreshCompileDB - Refresh LSP",
        }
        vim.notify(table.concat(info, "\n"), vim.log.levels.INFO)
      end, { desc = "Show ESP-IDF toolchain info" })

      return opts
    end,
  },

  -- Optional: Add which-key descriptions for ESP-IDF keymaps
  {
    "folke/which-key.nvim",
    optional = true,
    opts = {
      spec = {
        { "<leader>B", group = "build/board", icon = "" },
      },
    },
  },
}
