-- ezpr UI Layout Manager
-- Handles the three-panel layout: main window (left), discussions (top-right), files (bottom-right)

local M = {}

-- State management
M.state = {
  main_win = nil,           -- Main window (left panel)
  discussions_win = nil,    -- Discussions window (top-right)
  files_win = nil,          -- Files window (bottom-right)
  main_buf = nil,           -- Main buffer
  discussions_buf = nil,    -- Discussions buffer
  files_buf = nil,          -- Files buffer
  current_focus = 'main',   -- 'main', 'discussions', 'files'
  current_file = nil,       -- Currently selected file
  pr_data = nil,           -- Current PR data
  discussions_data = {},   -- Discussions for current file
  files_data = {},         -- List of files in PR
}

-- Create the three-panel layout
function M.create_layout()
  -- Close any existing layout
  M.close_layout()
  
  -- Create main buffer for diff/content (left panel)
  M.state.main_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(M.state.main_buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(M.state.main_buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_name(M.state.main_buf, '[EZPR] Main')
  
  -- Create discussions buffer (top-right panel)
  M.state.discussions_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(M.state.discussions_buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(M.state.discussions_buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_name(M.state.discussions_buf, '[EZPR] Discussions')
  
  -- Create files buffer (bottom-right panel)
  M.state.files_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(M.state.files_buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(M.state.files_buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_name(M.state.files_buf, '[EZPR] Files')
  
  -- Start with a clean slate - use current window as main
  local current_win = vim.api.nvim_get_current_win()
  
  -- Temporarily disable winfixbuf if it's enabled
  local winfixbuf = vim.api.nvim_win_get_option(current_win, 'winfixbuf')
  if winfixbuf then
    vim.api.nvim_win_set_option(current_win, 'winfixbuf', false)
  end
  
  vim.api.nvim_win_set_buf(current_win, M.state.main_buf)
  M.state.main_win = current_win
  
  -- Restore winfixbuf if it was enabled
  if winfixbuf then
    vim.api.nvim_win_set_option(current_win, 'winfixbuf', true)
  end
  
  -- Create vertical split for the right side panels
  vim.cmd('vsplit')
  local right_win = vim.api.nvim_get_current_win()
  
  -- Split the right window horizontally for discussions (top) and files (bottom)
  -- Handle winfixbuf for discussions window
  local right_winfixbuf = vim.api.nvim_win_get_option(right_win, 'winfixbuf')
  if right_winfixbuf then
    vim.api.nvim_win_set_option(right_win, 'winfixbuf', false)
  end
  
  vim.api.nvim_win_set_buf(right_win, M.state.discussions_buf)
  M.state.discussions_win = right_win
  
  if right_winfixbuf then
    vim.api.nvim_win_set_option(right_win, 'winfixbuf', true)
  end
  
  vim.cmd('split')
  local files_win = vim.api.nvim_get_current_win()
  
  -- Handle winfixbuf for files window
  local files_winfixbuf = vim.api.nvim_win_get_option(files_win, 'winfixbuf')
  if files_winfixbuf then
    vim.api.nvim_win_set_option(files_win, 'winfixbuf', false)
  end
  
  vim.api.nvim_win_set_buf(files_win, M.state.files_buf)
  M.state.files_win = files_win
  
  if files_winfixbuf then
    vim.api.nvim_win_set_option(files_win, 'winfixbuf', true)
  end
  
  -- Set initial focus to main window
  vim.api.nvim_set_current_win(M.state.main_win)
  M.state.current_focus = 'main'
  
  -- Setup only Enter key mappings for selection
  M.setup_buffer_keymaps()
end

-- Close the layout and clean up
function M.close_layout()
  -- Close windows if they exist and are valid
  if M.state.discussions_win and vim.api.nvim_win_is_valid(M.state.discussions_win) then
    vim.api.nvim_win_close(M.state.discussions_win, true)
  end
  if M.state.files_win and vim.api.nvim_win_is_valid(M.state.files_win) then
    vim.api.nvim_win_close(M.state.files_win, true)
  end
  
  -- Delete buffers if they exist and are valid
  if M.state.main_buf and vim.api.nvim_buf_is_valid(M.state.main_buf) then
    vim.api.nvim_buf_delete(M.state.main_buf, { force = true })
  end
  if M.state.discussions_buf and vim.api.nvim_buf_is_valid(M.state.discussions_buf) then
    vim.api.nvim_buf_delete(M.state.discussions_buf, { force = true })
  end
  if M.state.files_buf and vim.api.nvim_buf_is_valid(M.state.files_buf) then
    vim.api.nvim_buf_delete(M.state.files_buf, { force = true })
  end
  
  -- Reset state
  M.state.main_win = nil
  M.state.discussions_win = nil
  M.state.files_win = nil
  M.state.main_buf = nil
  M.state.discussions_buf = nil
  M.state.files_buf = nil
  M.state.current_focus = 'main'
end

-- Setup buffer-specific keymaps for Enter key selection only
function M.setup_buffer_keymaps()
  -- Files panel - only Enter key for selection
  if M.state.files_buf then
    vim.api.nvim_buf_set_keymap(M.state.files_buf, 'n', '<CR>',
      '<cmd>lua require("plugins.ezpr.ui").select_file()<CR>',
      { silent = true, noremap = true })
  end
  
  -- Discussions panel - only Enter key for selection
  if M.state.discussions_buf then
    vim.api.nvim_buf_set_keymap(M.state.discussions_buf, 'n', '<CR>',
      '<cmd>lua require("plugins.ezpr.ui").select_discussion()<CR>',
      { silent = true, noremap = true })
  end
end

-- Setup buffer-specific actions after keymap setup

-- Select a file from the files panel
function M.select_file()
  local line = vim.api.nvim_win_get_cursor(M.state.files_win)[1]
  -- For now, just show placeholder content
  -- This will be enhanced to load actual file content and discussions
  M.load_file_content("Selected file at line " .. line)
  M.load_file_discussions("File " .. line .. " discussions")
end

-- Select a discussion from the discussions panel
function M.select_discussion()
  local line = vim.api.nvim_win_get_cursor(M.state.discussions_win)[1]
  -- This will be enhanced to jump to the relevant line in the main window
  M.jump_to_line_in_main(line)
end

-- Helper function to format author name
local function format_author(name)
  if #name > 15 then
    return name:sub(1, 12) .. "..."
  end
  return name
end

-- Format PR for display in picker
local function format_pr(pr)
  local author = format_author(pr.createdBy and pr.createdBy.displayName or "Unknown")
  return string.format('[%s]\t\t\t%s', author, pr.title or "No title")
end

-- Show PR picker using vim.ui.select
function M.show_pr_picker()
  -- Get the ADO backend directly
  local ado_backend = require("plugins.ezpr.ezpr_be_ado")
  
  -- Try to get PRs from backend
  local response = ado_backend.list_prs()
  
  if not response.success then
    vim.notify("Failed to fetch PRs: " .. (response.error or "Unknown error"), vim.log.levels.ERROR)
    return
  end
  
  -- Parse the JSON response
  local prs_json = response.prs
  if not prs_json then
    vim.notify("No pull request data received", vim.log.levels.INFO)
    return
  end
  
  local success, prs = pcall(vim.json.decode, prs_json)
  if not success or not prs or #prs == 0 then
    vim.notify("No pull requests found", vim.log.levels.INFO)
    return
  end

  local items = {}
  local display_to_pr = {}

  for _, pr in ipairs(prs) do
    local display = format_pr(pr)
    table.insert(items, display)
    display_to_pr[display] = pr
  end

  -- Configure the picker
  vim.ui.select(items, {
    prompt = 'Select PR:',
    format_item = function(display) return display end
  }, function(choice)
    if choice then
      local selected_pr = display_to_pr[choice]
      
      -- Show more detailed information about the selected PR
      local details = string.format(
        '\nPR #%s: %s\nAuthor: %s\nCreated: %s\nSource: %s → %s\nURL: %s',
        selected_pr.pullRequestId or selected_pr.id,
        selected_pr.title,
        selected_pr.createdBy and selected_pr.createdBy.displayName or "Unknown",
        selected_pr.creationDate and selected_pr.creationDate:sub(1, 10) or "Unknown",
        selected_pr.sourceRefName and selected_pr.sourceRefName:gsub('refs/heads/', '') or "Unknown",
        selected_pr.targetRefName and selected_pr.targetRefName:gsub('refs/heads/', '') or "Unknown",
        selected_pr.url or "No URL"
      )
      print(details)
      
      -- Store current PR for use in the layout
      M.state.pr_data = selected_pr
      
      -- Open the layout if not already open
      if not M.is_layout_open() then
        M.create_layout()
      end
      
      -- Load PR data into the layout
      M.load_pr_data(selected_pr)
    end
  end)
end

-- Load PR data into the layout
function M.load_pr_data(pr)
  if not M.is_layout_open() then
    return
  end
  
  -- This will be enhanced to load actual PR data
  -- For now, just update the state
  M.state.pr_data = pr
  
  -- TODO: Load actual files and discussions from the PR
  -- M.state.files_data = get_pr_files(pr)
  -- M.state.discussions_data = get_pr_discussions(pr)
  
  vim.notify("PR loaded: " .. pr.title, vim.log.levels.INFO)
end

-- Load file content into main panel
function M.load_file_content(content)
  if not M.state.main_buf or not vim.api.nvim_buf_is_valid(M.state.main_buf) then
    return
  end
  
  local lines = vim.split(content, '\n')
  vim.api.nvim_buf_set_lines(M.state.main_buf, 0, -1, false, lines)
end

-- Load discussions for current file
function M.load_file_discussions(discussions)
  if not M.state.discussions_buf or not vim.api.nvim_buf_is_valid(M.state.discussions_buf) then
    return
  end
  
  local lines = vim.split(discussions, '\n')
  vim.api.nvim_buf_set_lines(M.state.discussions_buf, 0, -1, false, lines)
end

-- Jump to specific line in main window
function M.jump_to_line_in_main(line_num)
  if M.state.main_win and vim.api.nvim_win_is_valid(M.state.main_win) then
    vim.api.nvim_set_current_win(M.state.main_win)
    vim.api.nvim_win_set_cursor(M.state.main_win, {line_num, 0})
    M.state.current_focus = 'main'
  end
end


-- Public API functions
function M.toggle_layout()
  if M.state.main_win and vim.api.nvim_win_is_valid(M.state.main_win) then
    M.close_layout()
  else
    M.create_layout()
  end
end

function M.is_layout_open()
  return M.state.main_win and vim.api.nvim_win_is_valid(M.state.main_win)
end

-- Get current state (for debugging/external access)
function M.get_state()
  return M.state
end

return M