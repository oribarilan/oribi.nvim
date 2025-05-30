return {
  -- Local plugin specification for ezpr (Azure DevOps pull request manager)
  dir = vim.fn.stdpath("config") .. "/lua/plugins/ezpr",
  name = "ezpr",
  lazy = false,  -- Load immediately
  config = function()
    -- Load the Azure DevOps backend module
    local ezpr_be_ado = require("plugins.ezpr.ezpr_be_ado")
    local ezpr_ui = require("plugins.ezpr.ui")
    local ezpr_test = require("plugins.ezpr.test_ui")
    
    -- Set up the commands
    ezpr_be_ado.setup_commands()
    
    -- Override EzprListPRs command to use the PR picker
    vim.api.nvim_create_user_command("EzprListPRs", function()
      ezpr_ui.show_pr_picker()
    end, { desc = "List and select pull requests" })
    
    -- Add command to open discussion at cursor
    vim.api.nvim_create_user_command("EzprOpenDiscussion", function()
      ezpr_ui.open_discussion_at_cursor()
    end, { desc = "Open discussion at current cursor position" })
    
    -- Set up UI commands
    vim.api.nvim_create_user_command("EzprUI", function()
      ezpr_ui.toggle_layout()
    end, { desc = "Toggle ezpr UI layout" })
    
    vim.api.nvim_create_user_command("EzprOpen", function()
      ezpr_ui.create_layout()
    end, { desc = "Open ezpr UI layout" })
    
    vim.api.nvim_create_user_command("EzprClose", function()
      ezpr_ui.close_layout()
    end, { desc = "Close ezpr UI layout" })
    
    -- Optional: Store the modules globally for easier access
    _G.ezpr = {
      ado = ezpr_be_ado,
      ui = ezpr_ui,
      test = ezpr_test
    }
    
    -- Plugin initialized silently
  end,
  -- Plugin dependencies (if any)
  dependencies = {},
  -- Plugin commands that will be available
  cmd = {
    "EzprLogin",
    "EzprListPRs",
    "EzprDiscussions",
    "EzprStatus",
    "EzprLogout",
    "EzprUI",
    "EzprOpen",
    "EzprClose",
    "EzprTestUI",
    "EzprDemoSelection"
  },
}