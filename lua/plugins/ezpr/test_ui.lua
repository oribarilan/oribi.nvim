-- Test script for ezpr UI layout
-- This can be used to quickly test the UI layout functionality

local M = {}

function M.run_ui_test()
  local ui = require("plugins.ezpr.ui")
  
  print("Testing ezpr UI layout...")
  
  -- Create the layout
  ui.create_layout()
  
  print("Layout created!")
  print("Three panels: Main (left), Discussions (top-right), Files (bottom-right)")
  print("Use your normal window navigation keymaps to move between panels")
  print("Enter key selects items in files/discussions panels")
  print("")
  print("Commands:")
  print("  :EzprUI - Toggle layout")
  print("  :EzprOpen - Open layout")
  print("  :EzprClose - Close layout")
end

function M.demo_selection()
  local ui = require("plugins.ezpr.ui")
  
  if not ui.is_layout_open() then
    print("Opening layout first...")
    ui.create_layout()
  end
  
  print("Layout is ready!")
  print("The buffers are empty and ready for content loading")
  print("Enter key will trigger selection actions when content is available")
end

-- Add test commands
vim.api.nvim_create_user_command("EzprTestUI", function()
  M.run_ui_test()
end, { desc = "Test ezpr UI layout" })

vim.api.nvim_create_user_command("EzprDemoSelection", function()
  M.demo_selection()
end, { desc = "Demo ezpr selection actions" })

return M