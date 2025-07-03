-- dotnet.lua
-- .NET Core debugging configuration

local M = {}

function M.setup(dap)
  -- Setup .NET Core debugger for macOS ARM64
  require('netcoredbg-macOS-arm64').setup(dap)
  
  -- .NET debug configurations
  dap.configurations.cs = {
    {
      type = "coreclr",
      name = "launch - netcoredbg (auto build)",
      request = "launch",
      preLaunchTask = function()
        -- Build the project first
        vim.fn.system('dotnet build --configuration Debug')
      end,
      program = function()
        local cwd = vim.fn.getcwd()
        local project_name = vim.fn.fnamemodify(cwd, ':t')
        
        -- Try to find the built executable automatically
        local possible_paths = {
          cwd .. '/bin/Debug/net8.0/' .. project_name .. '.dll',
          cwd .. '/bin/Debug/net6.0/' .. project_name .. '.dll',
          cwd .. '/bin/Debug/net5.0/' .. project_name .. '.dll',
        }
        
        for _, path in ipairs(possible_paths) do
          if vim.fn.filereadable(path) == 1 then
            return path
          end
        end
        
        -- Use Telescope to pick DLL file
        return coroutine.create(function(dap_run_co)
          require('telescope.builtin').find_files({
            prompt_title = 'Select DLL to debug',
            cwd = cwd .. '/bin',
            find_command = { 'find', '.', '-name', '*.dll', '-type', 'f' },
            previewer = false,  -- Disable preview for DLL selection
            layout_config = {
              height = 0.4,  -- Smaller height since no preview
              width = 0.6,
            },
            attach_mappings = function(prompt_bufnr, map)
              local actions = require('telescope.actions')
              local action_state = require('telescope.actions.state')
              
              actions.select_default:replace(function()
                local selection = action_state.get_selected_entry()
                actions.close(prompt_bufnr)
                if selection then
                  coroutine.resume(dap_run_co, cwd .. '/bin/' .. selection.value)
                else
                  coroutine.resume(dap_run_co, nil)
                end
              end)
              
              return true
            end,
          })
        end)
      end,
      cwd = vim.fn.getcwd(),
      stopAtEntry = false,
      console = 'integratedTerminal',
      env = {},
      args = {},
    },
    {
      type = "coreclr",
      name = "launch - netcoredbg (manual dll)",
      request = "launch",
      program = function()
        local cwd = vim.fn.getcwd()
        
        -- Use Telescope to pick DLL file
        return coroutine.create(function(dap_run_co)
          require('telescope.builtin').find_files({
            prompt_title = 'Select DLL to debug',
            cwd = cwd,
            find_command = { 'find', '.', '-name', '*.dll', '-type', 'f' },
            previewer = false,  -- Disable preview for DLL selection
            layout_config = {
              height = 0.4,  -- Smaller height since no preview
              width = 0.6,
            },
            attach_mappings = function(prompt_bufnr, map)
              local actions = require('telescope.actions')
              local action_state = require('telescope.actions.state')
              
              actions.select_default:replace(function()
                local selection = action_state.get_selected_entry()
                actions.close(prompt_bufnr)
                if selection then
                  coroutine.resume(dap_run_co, cwd .. '/' .. selection.value)
                else
                  coroutine.resume(dap_run_co, nil)
                end
              end)
              
              return true
            end,
          })
        end)
      end,
      cwd = vim.fn.getcwd(),
      stopAtEntry = false,
      console = 'integratedTerminal',
      env = {},
      args = {},
    },
    {
      type = "coreclr",
      name = "attach - netcoredbg",
      request = "attach",
      processId = function()
        return require('dap.utils').pick_process()
      end,
      cwd = vim.fn.getcwd(),
    }
  }
end

-- .NET specific keymaps
function M.get_keymaps()
  return {
    {
      '<M-r>',
      function()
        local cwd = vim.fn.getcwd()
        vim.notify('Building .NET project...', vim.log.levels.INFO)
        vim.fn.jobstart({'dotnet', 'build', '--configuration', 'Debug'}, {
          cwd = cwd,
          on_exit = function(_, exit_code)
            if exit_code == 0 then
              vim.notify('Build successful!', vim.log.levels.INFO)
            else
              vim.notify('Build failed!', vim.log.levels.ERROR)
            end
          end,
          on_stdout = function(_, data)
            if data and #data > 0 then
              for _, line in ipairs(data) do
                if line ~= '' then
                  print(line)
                end
              end
            end
          end,
        })
      end,
      desc = 'Debug: Build .NET project',
    },
  }
end

-- Dependencies specific to .NET debugging
function M.get_dependencies()
  return {
    {
      "Cliffback/netcoredbg-macOS-arm64.nvim",
      dependencies = { "mfussenegger/nvim-dap" }
    },
  }
end

-- Mason ensure_installed entries
function M.get_mason_ensure_installed()
  return { 'netcoredbg' }
end

return M