return {
  -- Local plugin specification for ezpr (Azure DevOps pull request manager)
  dir = vim.fn.stdpath("config") .. "/lua/plugins/ezpr",
  name = "ezpr",
  lazy = false,  -- Load immediately
  config = function()
    -- Load the Azure DevOps backend module
    local ezpr_be_ado = require("plugins.ezpr.ezpr_be_ado")
    
    -- Set up the commands
    ezpr_be_ado.setup_commands()
    
    -- Optional: Store the module globally for easier access
    _G.ezpr = {
      ado = ezpr_be_ado
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
    "EzprLogout"
  },
}