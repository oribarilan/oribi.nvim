-- debug.lua
--
-- Shows how to use the DAP plugin to debug your code.
--
-- Primarily focused on configuring the debugger for Go, but can
-- be extended to other languages as well. That's why it's called
-- kickstart.nvim and not kitchen-sink.nvim ;)

return {
  'mfussenegger/nvim-dap',
  dependencies = {
    -- Creates a beautiful debugger UI
    'rcarriga/nvim-dap-ui',

    -- Required dependency for nvim-dap-ui
    'nvim-neotest/nvim-nio',

    -- Installs the debug adapters for you
    'williamboman/mason.nvim',
    'jay-babu/mason-nvim-dap.nvim',

    -- Add your own debuggers here
    'mfussenegger/nvim-dap-python',
    
    -- .NET Core debugger for macOS ARM64
    {
      "Cliffback/netcoredbg-macOS-arm64.nvim",
      dependencies = { "mfussenegger/nvim-dap" }
    },
  },
  keys = {
    -- Basic debugging keymaps, feel free to change to your liking!
    {
      '<M-d>',
      function()
        require('dap').continue()
      end,
      desc = 'Debug: Start/Continue',
    },
    {
      '<M-l>',
      function()
        require('dap').step_into()
      end,
      desc = 'Debug: Step Into',
    },
    {
      '<M-j>',
      function()
        require('dap').step_over()
      end,
      desc = 'Debug: Step Over',
    },
    {
      '<M-h>',
      function()
        require('dap').step_out()
      end,
      desc = 'Debug: Step Out',
    },
    {
      '<M-b>',
      function()
        require('dap').toggle_breakpoint()
      end,
      desc = 'Debug: Toggle Breakpoint',
    },
    {
      '<M-B>',
      function()
        require('dap').set_breakpoint(vim.fn.input('Breakpoint condition: '))
      end,
      desc = 'Debug: Set Conditional Breakpoint',
    },
    -- Toggle to see last session result. Without this, you can't see session output in case of unhandled exception.
    {
      '<M-o>',
      function()
        require('dapui').toggle()
      end,
      desc = 'Debug: See last session result.',
    },
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
  },
  config = function()
    local dap = require 'dap'
    local dapui = require 'dapui'

    require('mason-nvim-dap').setup {
      -- Makes a best effort to setup the various debuggers with
      -- reasonable debug configurations
      automatic_installation = true,

      -- You can provide additional configuration to the handlers,
      -- see mason-nvim-dap README for more information
      handlers = {},

      -- You'll need to check that you have the required things installed
      -- online, please don't ask me how to install them :)
      ensure_installed = {
        -- Update this to ensure that you have the debuggers for the langs you want
        'python',
        'netcoredbg',
      },
    }

    -- Dap UI setup
    -- For more information, see |:help nvim-dap-ui|
    dapui.setup {
      -- Set icons to characters that are more likely to work in every terminal.
      --    Feel free to remove or use ones that you like more! :)
      --    Don't feel like these are good choices.
      icons = { expanded = '▾', collapsed = '▸', current_frame = '*' },
      controls = {
        icons = {
          pause = '⏸',
          play = '▶',
          step_into = '⏎',
          step_over = '⏭',
          step_out = '⏮',
          step_back = 'b',
          run_last = '▶▶',
          terminate = '⏹',
          disconnect = '⏏',
        },
      },
    }

    -- Configure breakpoint icons and highlights
    vim.api.nvim_set_hl(0, 'DapBreak', { fg = '#e51400' })
    vim.api.nvim_set_hl(0, 'DapStop', { fg = '#ffcc00' })
    vim.api.nvim_set_hl(0, 'DapBreakpointRejected', { fg = '#888888' })
    
    local breakpoint_icons = vim.g.have_nerd_font
        and { Breakpoint = '', BreakpointCondition = '', BreakpointRejected = '', LogPoint = '', Stopped = '' }
      or { Breakpoint = '●', BreakpointCondition = '⊜', BreakpointRejected = '⊘', LogPoint = '◆', Stopped = '⭔' }
    
    for type, icon in pairs(breakpoint_icons) do
      local tp = 'Dap' .. type
      local hl = (type == 'Stopped') and 'DapStop' or (type == 'BreakpointRejected') and 'DapBreakpointRejected' or 'DapBreak'
      vim.fn.sign_define(tp, { text = icon, texthl = hl, numhl = hl })
    end

    -- Additional DAP configuration to ensure proper breakpoint handling
    dap.defaults.fallback.external_terminal = {
      command = '/usr/bin/open',
      args = {'-a', 'Terminal'},
    }
    
    -- Ensure breakpoints are properly set and validated
    dap.listeners.after.event_breakpoint['dap_breakpoint'] = function(session, body)
      vim.notify('Breakpoint validated: ' .. vim.inspect(body), vim.log.levels.DEBUG)
    end

    dap.listeners.after.event_initialized['dapui_config'] = dapui.open
    dap.listeners.before.event_terminated['dapui_config'] = dapui.close
    dap.listeners.before.event_exited['dapui_config'] = dapui.close

    require('dap-python').setup()
    
    -- Setup .NET Core debugger for macOS ARM64
    require('netcoredbg-macOS-arm64').setup(require('dap'))
    
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
  end,
}
