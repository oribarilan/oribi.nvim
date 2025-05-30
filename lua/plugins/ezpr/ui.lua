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
  
  -- Resize windows to make right panels about 20% width
  local total_width = vim.o.columns
  local right_panel_width = math.floor(total_width * 0.2)
  
  -- Resize the right panel windows to 20% width
  if M.state.discussions_win and vim.api.nvim_win_is_valid(M.state.discussions_win) then
    vim.api.nvim_win_set_width(M.state.discussions_win, right_panel_width)
  end
  if M.state.files_win and vim.api.nvim_win_is_valid(M.state.files_win) then
    vim.api.nvim_win_set_width(M.state.files_win, right_panel_width)
  end
  
  -- Setup only Enter key mappings for selection
  M.setup_buffer_keymaps()
end

-- Close the layout and clean up
function M.close_layout()
  -- Clean up diff buffers first
  M.cleanup_existing_diff()
  
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
  M.state.original_buf = nil
  M.state.pr_buf = nil
  M.state.temp_files = nil
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
  if not M.state.files_data or #M.state.files_data == 0 then
    vim.notify("No files available", vim.log.levels.WARN)
    return
  end
  
  local cursor_line = vim.api.nvim_win_get_cursor(M.state.files_win)[1]
  local file_index = cursor_line
  
  if file_index < 1 or file_index > #M.state.files_data then
    vim.notify("Invalid file selection", vim.log.levels.WARN)
    return
  end
  
  local selected_file = M.state.files_data[file_index]
  M.state.current_file = selected_file
  
  -- Load file content
  M.load_selected_file_content(selected_file)
  
  -- Load discussions for this file
  M.load_file_discussions_for_file(selected_file)
end

-- Load content for the selected file
function M.load_selected_file_content(file)
  if not M.state.pr_data then
    vim.notify("No PR data available", vim.log.levels.ERROR)
    return
  end
  
  -- Get the ADO backend
  local ado_backend = require("plugins.ezpr.ezpr_be_ado")
  
  -- Fetch PR file content (new version)
  local pr_response = ado_backend.fetch_pr_file_content(M.state.pr_data.pullRequestId, file.path)
  
  if not pr_response.success then
    vim.notify("Failed to fetch PR file content: " .. (pr_response.error or "Unknown error"), vim.log.levels.ERROR)
    return
  end
  
  local pr_content = pr_response.content or ""
  
  -- Get target branch content for comparison
  local target_ref = M.state.pr_data.targetRefName and M.state.pr_data.targetRefName:gsub('^refs/heads/', '') or 'main'
  
  -- Try to get the original file content from target branch
  local original_content = ""
  local git_cmd = string.format("git show %s:%s 2>/dev/null", target_ref, file.path:gsub("^/", ""))
  local handle = io.popen(git_cmd)
  if handle then
    original_content = handle:read("*a") or ""
    handle:close()
  end
  
  -- If file doesn't exist in target branch, it's a new file
  if original_content == "" and file.changeType == "add" then
    -- For new files, just show the PR content without diff
    M.create_single_file_view(pr_content, file)
  else
    -- Create side-by-side diff view
    M.create_side_by_side_diff(original_content, pr_content, file)
  end
end

-- Create side-by-side diff view in the main window area
function M.create_side_by_side_diff(original_content, pr_content, file)
  -- Clean up existing diff buffers and temp files first
  M.cleanup_existing_diff()
  
  -- Re-check main window validity after cleanup
  if not M.state.main_win or not vim.api.nvim_win_is_valid(M.state.main_win) then
    vim.notify("Main window is not valid, cannot create diff view", vim.log.levels.ERROR)
    return
  end
  
  -- Focus the main window
  local success = pcall(vim.api.nvim_set_current_win, M.state.main_win)
  if not success then
    vim.notify("Failed to focus main window", vim.log.levels.ERROR)
    return
  end
  
  -- Create temporary files for the diff
  local tmp_original = os.tmpname()
  local tmp_pr = os.tmpname()
  
  -- Write content to temp files
  local f = io.open(tmp_original, 'w')
  if f then
    f:write(original_content)
    f:close()
  end
  
  f = io.open(tmp_pr, 'w')
  if f then
    f:write(pr_content)
    f:close()
  end
  
  -- Get filename for display
  local filename = file.path:match("([^/]+)$") or file.path
  local extension = filename:match("%.([^%.]+)$") or ""
  
  -- Create the diff view
  -- First, load the original file in the current window
  vim.cmd('edit ' .. tmp_original)
  local original_buf = vim.api.nvim_get_current_buf()
  
  -- Set buffer name and options for original
  vim.api.nvim_buf_set_name(original_buf, '[EZPR] ' .. filename .. ' (original)')
  if extension ~= "" then
    vim.api.nvim_buf_set_option(original_buf, 'filetype', extension)
  end
  vim.api.nvim_buf_set_option(original_buf, 'modifiable', false)
  
  -- Create vertical split and load PR version
  vim.cmd('vertical diffsplit ' .. tmp_pr)
  local pr_buf = vim.api.nvim_get_current_buf()
  
  -- Set buffer name and options for PR version
  vim.api.nvim_buf_set_name(pr_buf, '[EZPR] ' .. filename .. ' (PR)')
  if extension ~= "" then
    vim.api.nvim_buf_set_option(pr_buf, 'filetype', extension)
  end
  vim.api.nvim_buf_set_option(pr_buf, 'modifiable', false)
  
  -- Update state to track both buffers
  M.state.main_buf = pr_buf  -- Keep PR buffer as the primary one for discussions
  M.state.original_buf = original_buf
  M.state.pr_buf = pr_buf
  
  -- Store temp files for cleanup
  M.state.temp_files = {tmp_original, tmp_pr}
  
  -- Clean up temp files when buffers are closed
  vim.api.nvim_create_autocmd('BufUnload', {
    pattern = {tmp_original, tmp_pr},
    callback = function()
      if M.state.temp_files then
        for _, tmp_file in ipairs(M.state.temp_files) do
          os.remove(tmp_file)
        end
        M.state.temp_files = nil
      end
    end,
    once = true
  })
  
  -- File loaded successfully (no notification for normal operation)
end

-- Create single file view for new files
function M.create_single_file_view(content, file)
  -- Clean up existing diff buffers and temp files first
  M.cleanup_existing_diff()
  
  -- Re-check main window validity after cleanup
  if not M.state.main_win or not vim.api.nvim_win_is_valid(M.state.main_win) then
    vim.notify("Main window is not valid, cannot create file view", vim.log.levels.ERROR)
    return
  end
  
  -- Focus the main window
  local success = pcall(vim.api.nvim_set_current_win, M.state.main_win)
  if not success then
    vim.notify("Failed to focus main window", vim.log.levels.ERROR)
    return
  end
  
  -- Create a temporary file for the content
  local tmp_file = os.tmpname()
  
  -- Write content to temp file
  local f = io.open(tmp_file, 'w')
  if f then
    f:write(content)
    f:close()
  end
  
  -- Get filename for display
  local filename = file.path:match("([^/]+)$") or file.path
  local extension = filename:match("%.([^%.]+)$") or ""
  
  -- Load the file in the main window
  vim.cmd('edit ' .. tmp_file)
  local file_buf = vim.api.nvim_get_current_buf()
  
  -- Set buffer name and options
  vim.api.nvim_buf_set_name(file_buf, '[EZPR] ' .. filename .. ' (new file)')
  if extension ~= "" then
    vim.api.nvim_buf_set_option(file_buf, 'filetype', extension)
  end
  vim.api.nvim_buf_set_option(file_buf, 'modifiable', false)
  
  -- Update state
  M.state.main_buf = file_buf
  M.state.temp_files = {tmp_file}
  
  -- Clean up temp file when buffer is closed
  vim.api.nvim_create_autocmd('BufUnload', {
    pattern = tmp_file,
    callback = function()
      if M.state.temp_files then
        for _, tmp in ipairs(M.state.temp_files) do
          os.remove(tmp)
        end
        M.state.temp_files = nil
      end
    end,
    once = true
  })
  
  -- New file loaded successfully (no notification for normal operation)
end

-- Clean up existing diff buffers and temporary files
function M.cleanup_existing_diff()
  -- Clear discussion indicators first
  M.clear_discussion_indicators()
  
  -- Clean up previous temp files
  if M.state.temp_files then
    for _, tmp_file in ipairs(M.state.temp_files) do
      pcall(os.remove, tmp_file)
    end
    M.state.temp_files = nil
  end
  
  -- Reset diff mode if main window is valid
  if M.state.main_win and vim.api.nvim_win_is_valid(M.state.main_win) then
    pcall(vim.api.nvim_set_current_win, M.state.main_win)
    if pcall(vim.api.nvim_win_get_option, M.state.main_win, 'diff') then
      pcall(vim.cmd, 'diffoff!')
    end
  end
  
  -- Close any additional split windows that might have been created for diff
  local current_tabpage = vim.api.nvim_get_current_tabpage()
  local all_windows = vim.api.nvim_tabpage_list_wins(current_tabpage)
  
  for _, win in ipairs(all_windows) do
    -- Only close windows that are not part of our main layout
    if win ~= M.state.main_win and
       win ~= M.state.discussions_win and
       win ~= M.state.files_win and
       vim.api.nvim_win_is_valid(win) then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end
  
  -- Delete previous diff buffers if they exist and are still valid
  if M.state.original_buf and vim.api.nvim_buf_is_valid(M.state.original_buf) then
    pcall(vim.api.nvim_buf_delete, M.state.original_buf, { force = true })
  end
  if M.state.pr_buf and vim.api.nvim_buf_is_valid(M.state.pr_buf) and M.state.pr_buf ~= M.state.main_buf then
    pcall(vim.api.nvim_buf_delete, M.state.pr_buf, { force = true })
  end
  
  -- Clear diff buffer references
  M.state.original_buf = nil
  M.state.pr_buf = nil
end


-- Load discussions for a specific file
function M.load_file_discussions_for_file(file)
  if not M.state.pr_data then
    return
  end
  
  -- Get the ADO backend
  local ado_backend = require("plugins.ezpr.ezpr_be_ado")
  
  -- Fetch discussions for this file
  local response = ado_backend.fetch_file_discussions(M.state.pr_data.pullRequestId, file.path)
  
  if not response.success then
    vim.notify("Failed to fetch discussions: " .. (response.error or "Unknown error"), vim.log.levels.WARN)
    return
  end
  
  local discussions = response.discussions or {}
  M.state.discussions_data = discussions
  
  -- Format discussions for display
  local discussion_lines = {}
  
  if #discussions == 0 then
    table.insert(discussion_lines, "No discussions for this file")
  else
    for i, discussion in ipairs(discussions) do
      local line_info = "?"
      if discussion.context and discussion.context.line_number then
        line_info = discussion.context.line_number
      end
      
      local comment_count = discussion.comments and #discussion.comments or 0
      local author = "Unknown"
      if discussion.comments and #discussion.comments > 0 and discussion.comments[1].author then
        local author_name = discussion.comments[1].author.name or "Unknown"
        -- Format author name (truncate if too long)
        if #author_name > 15 then
          author = author_name:sub(1, 12) .. "..."
        else
          author = author_name
        end
      end
      
      local line = string.format("%d. %s - %d comment%s by %s",
        i, line_info, comment_count, comment_count == 1 and "" or "s", author)
      table.insert(discussion_lines, line)
    end
  end
  
  -- Update the discussions buffer
  if M.state.discussions_buf and vim.api.nvim_buf_is_valid(M.state.discussions_buf) then
    vim.api.nvim_buf_set_option(M.state.discussions_buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(M.state.discussions_buf, 0, -1, false, discussion_lines)
    vim.api.nvim_buf_set_option(M.state.discussions_buf, 'modifiable', false)
  end
  
  -- Add virtual text indicators for discussions in the main buffer
  M.add_discussion_indicators(discussions)
end

-- Select a discussion from the discussions panel
function M.select_discussion()
  if not M.state.discussions_data or #M.state.discussions_data == 0 then
    vim.notify("No discussions available", vim.log.levels.WARN)
    return
  end
  
  local cursor_line = vim.api.nvim_win_get_cursor(M.state.discussions_win)[1]
  local discussion_index = cursor_line
  
  if discussion_index < 1 or discussion_index > #M.state.discussions_data then
    vim.notify("Invalid discussion selection", vim.log.levels.WARN)
    return
  end
  
  local selected_discussion = M.state.discussions_data[discussion_index]
  
  -- Jump to the line in the main window if we have line context
  if selected_discussion.context and selected_discussion.context.line_number then
    local line_num = selected_discussion.context.line_number
    M.jump_to_line_in_main(line_num)
    -- Line jump successful (no notification for normal operation)
  else
    vim.notify("No line information for this discussion", vim.log.levels.WARN)
  end
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
    vim.notify("No pull request data received", vim.log.levels.WARN)
    return
  end
  
  local success, prs = pcall(vim.json.decode, prs_json)
  if not success or not prs or #prs == 0 then
    vim.notify("No pull requests found", vim.log.levels.WARN)
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
      
      -- PR selected, no notification needed for normal operation
      
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
  
  -- Update the state
  M.state.pr_data = pr
  
  -- Load actual files from the PR
  M.load_pr_files(pr)
  
  -- PR loaded successfully (no notification for normal operation)
end

-- Load files for the current PR into the files panel
function M.load_pr_files(pr)
  if not M.state.files_buf or not vim.api.nvim_buf_is_valid(M.state.files_buf) then
    return
  end
  
  -- Get the ADO backend
  local ado_backend = require("plugins.ezpr.ezpr_be_ado")
  
  -- Fetch files for this PR
  local response = ado_backend.fetch_pr_files(pr.pullRequestId)
  
  if not response.success then
    vim.notify("Failed to fetch PR files: " .. (response.error or "Unknown error"), vim.log.levels.ERROR)
    return
  end
  
  local files = response.files or {}
  M.state.files_data = files
  
  -- Format files for display
  local file_lines = {}
  
  if #files == 0 then
    table.insert(file_lines, "No files found in this PR")
  else
    for i, file in ipairs(files) do
      local change_icon = "?"
      if file.changeType == "add" then
        change_icon = "+"
      elseif file.changeType == "edit" then
        change_icon = "~"
      elseif file.changeType == "delete" then
        change_icon = "-"
      end
      
      -- Get filename from path
      local filename = file.path:match("([^/]+)$") or file.path
      local line = string.format("%d. [%s] %s", i, change_icon, filename)
      table.insert(file_lines, line)
    end
  end
  
  -- Update the files buffer
  vim.api.nvim_buf_set_option(M.state.files_buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(M.state.files_buf, 0, -1, false, file_lines)
  vim.api.nvim_buf_set_option(M.state.files_buf, 'modifiable', false)
  
  -- Set focus to files window after PR is loaded
  if M.state.files_win and vim.api.nvim_win_is_valid(M.state.files_win) then
    vim.api.nvim_set_current_win(M.state.files_win)
    M.state.current_focus = 'files'
  end
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

-- Helper function to determine which side of diff to highlight based on context
local function get_discussion_position_for_side(discussion, side)
  local context = discussion.context
  if not context then return nil end
  
  -- For side-by-side diff views, use appropriate file context
  if side == "left" and context.left_file then
    return {
      start_line = context.left_file.start_line,
      end_line = context.left_file.end_line,
      start_column = context.left_file.start_column,
      end_column = context.left_file.end_column,
    }
  elseif side == "right" and context.right_file then
    return {
      start_line = context.right_file.start_line,
      end_line = context.right_file.end_line,
      start_column = context.right_file.start_column,
      end_column = context.right_file.end_column,
    }
  end
  
  -- Fallback to primary context (usually right side for new/modified content)
  return {
    start_line = context.start_line,
    end_line = context.end_line,
    start_column = context.start_column,
    end_column = context.end_column,
  }
end

-- Add virtual text indicators for discussions
function M.add_discussion_indicators(discussions)
  -- Clear any existing discussion indicators
  M.clear_discussion_indicators()
  
  -- Create namespace for discussion indicators
  M.state.discussion_ns = vim.api.nvim_create_namespace('ezpr_discussions')
  
  -- Create highlight groups with enhanced styling for different states
  vim.api.nvim_set_hl(0, 'EzprDiscussionIndicator', { fg = '#61afef', bold = true })
  vim.api.nvim_set_hl(0, 'EzprDiscussionAuthor', { fg = '#98c379', bold = true })
  vim.api.nvim_set_hl(0, 'EzprDiscussionHighlight', { bg = '#3e4451', fg = '#61afef' })
  vim.api.nvim_set_hl(0, 'EzprDiscussionHighlightOutdated', { bg = '#5c4037', italic = true })
  vim.api.nvim_set_hl(0, 'EzprDiscussionHighlightResolved', { bg = '#2e7d32', strikethrough = true })
  
  -- Store discussion data by line number for quick lookup
  M.state.discussions_by_line = {}
  
  -- Group discussions by their start line for virtual text placement
  -- Also group by all lines they span for highlighting
  local discussions_by_start_line = {}
  local discussions_by_line_temp = {}
  
  for _, discussion in ipairs(discussions) do
    if discussion.context and discussion.context.start_line then
      local start_line = discussion.context.start_line
      local end_line = discussion.context.end_line or start_line
      
      -- Group by start line for virtual text (only appears above topmost line)
      if not discussions_by_start_line[start_line] then
        discussions_by_start_line[start_line] = {}
      end
      table.insert(discussions_by_start_line[start_line], discussion)
      
      -- Add discussion to all lines it spans for highlighting
      for line_num = start_line, end_line do
        if not discussions_by_line_temp[line_num] then
          discussions_by_line_temp[line_num] = {}
        end
        table.insert(discussions_by_line_temp[line_num], discussion)
      end
    end
  end
  
  -- Add indicators for each line that has discussions
  local target_buf = M.state.pr_buf or M.state.main_buf
  if target_buf and vim.api.nvim_buf_is_valid(target_buf) then
    local buf_line_count = vim.api.nvim_buf_line_count(target_buf)
    
    for line_number, line_discussions in pairs(discussions_by_line_temp) do
      local line_num = line_number - 1  -- Convert to 0-based
      
      if line_num < buf_line_count then
        -- Get the actual line content
        local line_content = vim.api.nvim_buf_get_lines(target_buf, line_num, line_num + 1, false)[1] or ""
        local line_length = #line_content
        
        -- Add highlights for each discussion's text range
        for _, discussion in ipairs(line_discussions) do
          local context = discussion.context
          local start_line = context.start_line or context.line_number
          local end_line = context.end_line or start_line
          local start_col = context.start_column
          local end_col = context.end_column
          
          -- Determine highlight group based on discussion state
          local hl_group = "EzprDiscussionHighlight"
          if context.is_outdated then
            hl_group = "EzprDiscussionHighlightOutdated"
          elseif context.status == 4 then -- Fixed/Resolved in Azure DevOps
            hl_group = "EzprDiscussionHighlightResolved"
          end
          
          -- Skip if we don't have valid line information
          if not start_line or not end_line then
            goto continue
          end
          
          -- Convert Azure DevOps 1-based columns to Neovim 0-based columns
          local adjusted_start_col = start_col and math.max(0, start_col - 1) or nil
          local adjusted_end_col = end_col and math.max(0, end_col - 1) or nil
          
          -- Handle multi-line discussions
          if start_line == end_line and start_line == line_number then
            -- Single line discussion on current line
            if adjusted_start_col and adjusted_end_col and adjusted_start_col >= 0 and adjusted_end_col > adjusted_start_col then
              -- Validate and clamp column positions to line bounds
              local clamped_start = math.max(0, math.min(adjusted_start_col, line_length))
              local clamped_end = math.max(clamped_start + 1, math.min(adjusted_end_col, line_length))
              
              -- Only add highlights if we have a valid range within the line
              if clamped_start < line_length and clamped_end > clamped_start then
                vim.api.nvim_buf_set_extmark(target_buf, M.state.discussion_ns, line_num, clamped_start, {
                  end_col = clamped_end,
                  hl_group = hl_group
                })
              end
            elseif adjusted_start_col and adjusted_start_col >= 0 and not adjusted_end_col then
              -- Only start column provided, highlight from start to end of line
              local clamped_start = math.max(0, math.min(adjusted_start_col, line_length))
              if clamped_start < line_length then
                vim.api.nvim_buf_set_extmark(target_buf, M.state.discussion_ns, line_num, clamped_start, {
                  end_col = line_length,
                  hl_group = hl_group
                })
              end
            else
              -- Fallback: highlight entire line if column info is missing or invalid
              if line_length > 0 then
                vim.api.nvim_buf_set_extmark(target_buf, M.state.discussion_ns, line_num, 0, {
                  end_col = line_length,
                  hl_group = hl_group
                })
              end
            end
          elseif start_line < end_line and start_line <= line_number and line_number <= end_line then
            -- Multi-line discussion and current line is within range
            if line_number == start_line then
              -- First line: highlight from start_col to end of line
              local highlight_start = math.max(0, math.min(adjusted_start_col or 0, line_length))
              if highlight_start < line_length then
                vim.api.nvim_buf_set_extmark(target_buf, M.state.discussion_ns, line_num, highlight_start, {
                  end_col = line_length,
                  hl_group = hl_group
                })
              end
            elseif line_number == end_line then
              -- Last line: highlight from beginning to end_col
              local highlight_end = math.max(1, math.min(adjusted_end_col or line_length, line_length))
              if highlight_end > 0 then
                vim.api.nvim_buf_set_extmark(target_buf, M.state.discussion_ns, line_num, 0, {
                  end_col = highlight_end,
                  hl_group = hl_group
                })
              end
            else
              -- Middle line: highlight entire line
              if line_length > 0 then
                vim.api.nvim_buf_set_extmark(target_buf, M.state.discussion_ns, line_num, 0, {
                  end_col = line_length,
                  hl_group = hl_group
                })
              end
            end
          end
          
          ::continue::
        end
        
        -- Store discussion data for quick lookup by line (for highlighting purposes)
        M.state.discussions_by_line[line_number] = line_discussions
      end
    end
    
    -- Add virtual lines above the start line of discussions (only once per start line)
    for start_line_number, start_line_discussions in pairs(discussions_by_start_line) do
      local line_num = start_line_number - 1  -- Convert to 0-based
      
      if line_num >= 0 and line_num < buf_line_count then
        -- Calculate total comments, authors, and states for discussions starting at this line
        local total_comments = 0
        local authors = {}
        local state_counts = { active = 0, resolved = 0, outdated = 0 }
        
        for _, discussion in ipairs(start_line_discussions) do
          local comment_count = discussion.comments and #discussion.comments or 0
          total_comments = total_comments + comment_count
          
          -- Count discussion states
          if discussion.context.is_outdated then
            state_counts.outdated = state_counts.outdated + 1
          elseif discussion.context.status == 4 then
            state_counts.resolved = state_counts.resolved + 1
          else
            state_counts.active = state_counts.active + 1
          end
          
          -- Collect unique authors
          if discussion.comments and #discussion.comments > 0 and discussion.comments[1].author then
            local author_name = discussion.comments[1].author.name or "Unknown"
            authors[author_name] = true
          end
        end
        
        -- Format the virtual text with state indicators
        local author_list = {}
        for author, _ in pairs(authors) do
          local short_author = #author > 10 and author:sub(1, 7) .. "..." or author
          table.insert(author_list, short_author)
        end
        local author_text = table.concat(author_list, ", ")
        if #author_list > 2 then
          author_text = author_list[1] .. " and " .. (#author_list - 1) .. " others"
        end
        
        -- Create state indicator
        local state_parts = {}
        if state_counts.active > 0 then
          table.insert(state_parts, state_counts.active .. " active")
        end
        if state_counts.resolved > 0 then
          table.insert(state_parts, state_counts.resolved .. " resolved")
        end
        if state_counts.outdated > 0 then
          table.insert(state_parts, state_counts.outdated .. " outdated")
        end
        local state_text = #state_parts > 0 and " (" .. table.concat(state_parts, ", ") .. ")" or ""
        
        local virt_text = string.format("💬 %d comment%s by %s%s",
          total_comments, total_comments == 1 and "" or "s", author_text, state_text)
        
        -- Add virtual line ABOVE the start line of the discussion
        vim.api.nvim_buf_set_extmark(target_buf, M.state.discussion_ns, line_num, 0, {
          virt_lines = {{ { virt_text, "EzprDiscussionIndicator" } }},
          virt_lines_above = true
        })
      end
    end
  end
end

-- Clear existing discussion indicators
function M.clear_discussion_indicators()
  if M.state.discussion_ns then
    -- Clear from PR buffer if it exists
    if M.state.pr_buf and vim.api.nvim_buf_is_valid(M.state.pr_buf) then
      vim.api.nvim_buf_clear_namespace(M.state.pr_buf, M.state.discussion_ns, 0, -1)
    end
    -- Clear from main buffer if it exists
    if M.state.main_buf and vim.api.nvim_buf_is_valid(M.state.main_buf) then
      vim.api.nvim_buf_clear_namespace(M.state.main_buf, M.state.discussion_ns, 0, -1)
    end
  end
  M.state.discussions_by_line = {}
end

-- Open discussion at current cursor position
function M.open_discussion_at_cursor()
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local cursor_line = cursor_pos[1]  -- 1-based line number
  local cursor_col = cursor_pos[2]   -- 0-based column number
  
  local discussions_on_line = M.state.discussions_by_line and M.state.discussions_by_line[cursor_line]
  
  if not discussions_on_line or #discussions_on_line == 0 then
    vim.notify("No discussion found at current line", vim.log.levels.WARN)
    return
  end
  
  -- Filter discussions to those that actually contain the cursor position
  local relevant_discussions = {}
  for _, discussion in ipairs(discussions_on_line) do
    local start_line = discussion.context.start_line or discussion.context.line_number
    local end_line = discussion.context.end_line or start_line
    local start_col = discussion.context.start_column
    local end_col = discussion.context.end_column
    
    -- Skip if we don't have valid line information
    if not start_line or not end_line then
      goto continue_cursor
    end
    
    local cursor_in_discussion = false
    
    if start_line == end_line and start_line == cursor_line then
      -- Single line discussion
      if start_col and end_col and start_col >= 0 and end_col > start_col then
        cursor_in_discussion = cursor_col >= start_col and cursor_col < end_col
      elseif start_col and start_col >= 0 and not end_col then
        cursor_in_discussion = cursor_col >= start_col
      else
        cursor_in_discussion = true -- No valid column info, assume entire line
      end
    elseif start_line < end_line and start_line <= cursor_line and cursor_line <= end_line then
      -- Multi-line discussion
      if cursor_line == start_line then
        cursor_in_discussion = cursor_col >= (start_col or 0)
      elseif cursor_line == end_line then
        cursor_in_discussion = cursor_col < (end_col or math.huge)
      else
        cursor_in_discussion = true -- Middle line
      end
    end
    
    if cursor_in_discussion then
      table.insert(relevant_discussions, discussion)
    end
    
    ::continue_cursor::
  end
  
  if #relevant_discussions == 0 then
    -- Show all discussions on line if cursor isn't in specific range
    relevant_discussions = discussions_on_line
  end
  
  -- If there are multiple discussions, show a picker to select which one to open
  if #relevant_discussions > 1 then
    M.show_discussion_picker(relevant_discussions, cursor_line)
  elseif #relevant_discussions == 1 then
    -- Single discussion, open it directly
    M.show_single_discussion_popup(relevant_discussions[1], cursor_line)
  else
    vim.notify("No discussions found at current position", vim.log.levels.WARN)
  end
end

-- Show a picker to select which discussion to open when there are multiple
function M.show_discussion_picker(discussions, line_number)
  local items = {}
  local display_to_discussion = {}
  
  for i, discussion in ipairs(discussions) do
    local author = "Unknown"
    local preview = "No content"
    local comment_count = 0
    
    if discussion.comments and #discussion.comments > 0 then
      comment_count = #discussion.comments
      if discussion.comments[1].author then
        author = discussion.comments[1].author.name or "Unknown"
      end
      if discussion.comments[1].content then
        -- Get first line of content as preview
        preview = discussion.comments[1].content:match("([^\n]*)")
        if #preview > 50 then
          preview = preview:sub(1, 47) .. "..."
        end
      end
    end
    
    local display = string.format("[%s] %d comment%s: %s", 
      author, comment_count, comment_count == 1 and "" or "s", preview)
    
    table.insert(items, display)
    display_to_discussion[display] = discussion
  end
  
  vim.ui.select(items, {
    prompt = string.format('Select discussion on line %d:', line_number),
    format_item = function(display) return display end
  }, function(choice)
    if choice then
      local selected_discussion = display_to_discussion[choice]
      M.show_single_discussion_popup(selected_discussion, line_number)
    end
  end)
end

-- Show a single discussion in a popup window
function M.show_single_discussion_popup(discussion, line_number)
  local content = {}
  
  table.insert(content, string.format("=== Line %d Discussion ===", line_number))
  table.insert(content, "Press 'q' to close this window")
  table.insert(content, "")
  
  -- Show discussion context if available
  if discussion.context then
    local start_line = discussion.context.start_line or discussion.context.line_number
    local end_line = discussion.context.end_line or start_line
    local start_col = discussion.context.start_column
    local end_col = discussion.context.end_column
    
    if start_line == end_line then
      -- Single line
      if start_col and end_col then
        table.insert(content, string.format("Range: line %d, columns %d-%d", start_line, start_col, end_col))
      else
        table.insert(content, string.format("Range: line %d (entire line)", start_line))
      end
    else
      -- Multi-line
      if start_col and end_col then
        table.insert(content, string.format("Range: lines %d-%d, from col %d to col %d", start_line, end_line, start_col, end_col))
      else
        table.insert(content, string.format("Range: lines %d-%d", start_line, end_line))
      end
    end
  end
  table.insert(content, "")
  
  -- Format each comment in the discussion
  for _, comment in ipairs(discussion.comments or {}) do
    local author = comment.author and comment.author.name or "Unknown"
    local date = comment.created_at and comment.created_at:sub(1, 10) or "Unknown date"
    
    table.insert(content, string.format("@%s", author))
    table.insert(content, string.format("Posted on %s", date))
    table.insert(content, "")
    
    -- Add comment content, preserving line breaks and indenting
    local comment_text = comment.content or "No content"
    for _, line in ipairs(vim.split(comment_text, "\n", { plain = true })) do
      table.insert(content, line)
    end
    table.insert(content, "")
  end
  
  table.insert(content, "")
  table.insert(content, "Press 'q' to close")

  -- Show floating window with comments
  local popup_bufnr, winnr = vim.lsp.util.open_floating_preview(content, 'markdown', {
    border = 'rounded',
    max_width = 90,
    max_height = 25,
    focus = true
  })
  
  -- Ensure the floating window is focused and set cursor position
  if vim.api.nvim_win_is_valid(winnr) then
    -- Explicitly set focus to the floating window
    vim.api.nvim_set_current_win(winnr)
    
    -- Find the first line that contains actual comment content
    local target_line = 1
    for i, line in ipairs(content) do
      if line:match("^@") then
        target_line = i + 2  -- Move to comment content (skip @author and date lines)
        break
      end
    end
    
    -- Ensure target_line is within bounds
    target_line = math.min(target_line, #content)
    target_line = math.max(target_line, 1)
    
    vim.api.nvim_win_set_cursor(winnr, {target_line, 0})
  end
end

-- Create a comment on the current PR using highlighted text
function M.create_comment_with_selection()
  -- Check if we have an active PR
  if not M.state.pr_data or not M.state.pr_data.pullRequestId then
    vim.notify("No active PR found. Please open a PR first with :EzprListPRs", vim.log.levels.ERROR)
    return
  end
  
  -- Try to determine the current file
  local current_file = M.state.current_file
  if not current_file or not current_file.path then
    -- Try to match current buffer with PR files
    local current_buffer_path = vim.api.nvim_buf_get_name(0)
    if current_buffer_path and current_buffer_path ~= "" then
      -- Get relative path from current working directory
      local cwd = vim.fn.getcwd()
      local relative_path = current_buffer_path:gsub("^" .. vim.pesc(cwd .. "/"), "")
      
      -- Look for this file in the PR files
      if M.state.files_data then
        for _, file in ipairs(M.state.files_data) do
          if file.path == relative_path or file.path:match(vim.pesc(relative_path) .. "$") then
            current_file = file
            M.state.current_file = file  -- Update state
            break
          end
        end
      end
    end
    
    if not current_file or not current_file.path then
      vim.notify("Cannot determine current file. Please select a file from the PR first or ensure you're editing a file that's part of the PR", vim.log.levels.ERROR)
      return
    end
  end
  
  -- Get visual selection using the last visual selection marks
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  
  -- Validate that we have a meaningful selection
  if start_pos[2] == 0 or end_pos[2] == 0 then
    vim.notify("No text selected. Please highlight the code you want to comment on", vim.log.levels.WARN)
    return
  end
  
  -- Check if it's just a cursor position (no actual selection)
  if start_pos[2] == end_pos[2] and start_pos[3] == end_pos[3] then
    vim.notify("No text range selected. Please select a text range to comment on", vim.log.levels.WARN)
    return
  end
  
  local start_line = start_pos[2]
  local start_col = start_pos[3]
  local end_line = end_pos[2]
  local end_col = end_pos[3]
  
  -- Show comment input floating window
  M.show_comment_input_window(M.state.pr_data.pullRequestId, current_file.path, start_line, end_line, start_col, end_col)
end

-- Show floating window for comment input
function M.show_comment_input_window(pr_id, file_path, start_line, end_line, start_col, end_col)
  -- Create a new buffer for the comment input
  local input_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(input_buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(input_buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(input_buf, 'filetype', 'markdown')
  
  -- Set initial content with instructions
  local instructions = {
    "# Create Comment",
    "",
    string.format("File: %s", file_path),
    string.format("Lines: %d-%d, Columns: %d-%d", start_line, end_line, start_col, end_col),
    "",
    "Press <Ctrl-s> to submit comment, 'q' to cancel",
    "",
    "--- Write your comment below this line ---",
    "",
    ""  -- Empty line for user to start typing
  }
  
  vim.api.nvim_buf_set_lines(input_buf, 0, -1, false, instructions)
  
  -- Calculate window size and position
  local width = math.min(80, vim.o.columns - 10)
  local height = math.min(20, vim.o.lines - 10)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  
  -- Create floating window
  local win_opts = {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    border = 'rounded',
    title = ' New Comment ',
    title_pos = 'center',
    style = 'minimal'
  }
  
  local input_win = vim.api.nvim_open_win(input_buf, true, win_opts)
  
  -- Position cursor on the last line where user should type
  vim.api.nvim_win_set_cursor(input_win, {#instructions, 0})
  
  -- Set buffer-local keymaps
  local function submit_comment()
    -- Get all lines from the buffer
    local all_lines = vim.api.nvim_buf_get_lines(input_buf, 0, -1, false)
    
    -- Find the content after the separator line
    local comment_lines = {}
    local found_separator = false
    
    for _, line in ipairs(all_lines) do
      if line:match("^%-%-%-.*Write your comment") then
        found_separator = true
      elseif found_separator and line:match("^%s*$") == nil then
        table.insert(comment_lines, line)
      end
    end
    
    -- Join comment lines
    local comment_content = table.concat(comment_lines, "\n"):gsub("^%s+", ""):gsub("%s+$", "")
    
    if comment_content == "" then
      vim.notify("Comment cannot be empty", vim.log.levels.WARN)
      return
    end
    
    -- Close the input window
    if vim.api.nvim_win_is_valid(input_win) then
      vim.api.nvim_win_close(input_win, true)
    end
    
    -- Submit the comment
    M.submit_pr_comment(pr_id, file_path, start_line, end_line, start_col, end_col, comment_content)
  end
  
  local function cancel_comment()
    if vim.api.nvim_win_is_valid(input_win) then
      vim.api.nvim_win_close(input_win, true)
    end
  end
  
  -- Set up keymaps with proper options
  local keymap_opts = { buffer = input_buf, noremap = true, silent = true }
  
  vim.keymap.set('n', '<C-s>', submit_comment, vim.tbl_extend('force', keymap_opts, { desc = 'Submit comment' }))
  vim.keymap.set('i', '<C-s>', function()
    vim.cmd('stopinsert')
    submit_comment()
  end, vim.tbl_extend('force', keymap_opts, { desc = 'Submit comment' }))
  vim.keymap.set('n', 'q', cancel_comment, vim.tbl_extend('force', keymap_opts, { desc = 'Cancel comment' }))
  
  -- Enable insert mode
  vim.cmd('startinsert')
end

-- Submit the PR comment using the backend
function M.submit_pr_comment(pr_id, file_path, start_line, end_line, start_col, end_col, comment_content)
  vim.notify("Submitting comment...", vim.log.levels.INFO)
  
  -- Get the ADO backend
  local ado_backend = require("plugins.ezpr.ezpr_be_ado")
  
  -- Submit the comment
  local result = ado_backend.create_pr_comment(pr_id, comment_content, file_path, start_line, end_line, start_col, end_col)
  
  if result.success then
    vim.notify("✓ Comment created successfully!", vim.log.levels.INFO)
    
    -- Refresh discussions for the current file to show the new comment
    if M.state.current_file then
      M.load_file_discussions_for_file(M.state.current_file)
    end
  else
    vim.notify("✗ Failed to create comment: " .. (result.error or "Unknown error"), vim.log.levels.ERROR)
    if result.raw_response then
      vim.notify("Raw response: " .. result.raw_response:sub(1, 200) .. "...", vim.log.levels.DEBUG)
    end
  end
end

-- Show all discussions for a line in a popup window
function M.show_line_discussions_popup(discussions, line_number)
  local content = {}
  
  table.insert(content, string.format("=== Line %d Discussions ===", line_number))
  table.insert(content, "Press 'q' to close this window")
  table.insert(content, "")
  
  -- Format each discussion and its comments
  for i, discussion in ipairs(discussions) do
    table.insert(content, string.format("Discussion %d:", i))
    
    -- Show discussion context if available
    if discussion.context then
      local start_line = discussion.context.start_line or discussion.context.line_number
      local end_line = discussion.context.end_line or start_line
      local start_col = discussion.context.start_column
      local end_col = discussion.context.end_column
      
      if start_line == end_line then
        -- Single line
        if start_col and end_col then
          table.insert(content, string.format("  Range: line %d, columns %d-%d", start_line, start_col, end_col))
        else
          table.insert(content, string.format("  Range: line %d (entire line)", start_line))
        end
      else
        -- Multi-line
        if start_col and end_col then
          table.insert(content, string.format("  Range: lines %d-%d, from col %d to col %d", start_line, end_line, start_col, end_col))
        else
          table.insert(content, string.format("  Range: lines %d-%d", start_line, end_line))
        end
      end
    end
    table.insert(content, "")
    
    -- Format each comment in the discussion
    for _, comment in ipairs(discussion.comments or {}) do
      local author = comment.author and comment.author.name or "Unknown"
      local date = comment.created_at and comment.created_at:sub(1, 10) or "Unknown date"
      
      table.insert(content, string.format("  @%s", author))
      table.insert(content, string.format("  Posted on %s", date))
      table.insert(content, "")
      
      -- Add comment content, preserving line breaks and indenting
      local comment_text = comment.content or "No content"
      for _, line in ipairs(vim.split(comment_text, "\n", { plain = true })) do
        table.insert(content, "  " .. line)
      end
      table.insert(content, "")
    end
    
    if i < #discussions then
      table.insert(content, string.rep("─", 50))
      table.insert(content, "")
    end
  end
  
  table.insert(content, "")
  table.insert(content, "Press 'q' to close")

  -- Show floating window with comments
  local popup_bufnr, winnr = vim.lsp.util.open_floating_preview(content, 'markdown', {
    border = 'rounded',
    max_width = 90,
    max_height = 25,
    focus = true
  })
  
  -- Ensure the floating window is focused and set cursor position
  if vim.api.nvim_win_is_valid(winnr) then
    -- Explicitly set focus to the floating window
    vim.api.nvim_set_current_win(winnr)
    
    -- Find the first line that contains actual discussion content (skip headers and hint)
    local target_line = 1
    for i, line in ipairs(content) do
      if line:match("^Discussion %d+:") then
        -- Look for the first comment content after this discussion header
        for j = i + 1, #content do
          if content[j]:match("^  @") then
            target_line = j + 3  -- Move to comment content (skip @author and date lines)
            break
          end
        end
        break
      end
    end
    
    -- Ensure target_line is within bounds
    target_line = math.min(target_line, #content)
    target_line = math.max(target_line, 1)
    
    vim.api.nvim_win_set_cursor(winnr, {target_line, 0})
  end
  
  -- Add keybindings to close the floating window
  local function close_float()
    if vim.api.nvim_win_is_valid(winnr) then
      vim.api.nvim_win_close(winnr, true)
    end
  end
  
  vim.keymap.set('n', 'q', close_float, { buffer = popup_bufnr, desc = 'Close discussions' })

  -- Add highlights to the popup
  for i, line in ipairs(content) do
    if line:match("^=== .* ===$") then
      vim.api.nvim_buf_add_highlight(popup_bufnr, 0, 'Title', i-1, 0, -1)
    elseif line:match("^Press 'q'") then
      vim.api.nvim_buf_add_highlight(popup_bufnr, 0, 'WarningMsg', i-1, 0, -1)
    elseif line:match("^Discussion %d+:") then
      vim.api.nvim_buf_add_highlight(popup_bufnr, 0, 'EzprDiscussionIndicator', i-1, 0, -1)
    elseif line:match("^  @") then
      vim.api.nvim_buf_add_highlight(popup_bufnr, 0, 'EzprDiscussionAuthor', i-1, 0, -1)
    elseif line:match("^  Posted on") or line:match("^  Range:") then
      vim.api.nvim_buf_add_highlight(popup_bufnr, 0, 'Comment', i-1, 0, -1)
    end
  end
end

-- Show discussion in a popup window (kept for compatibility)
function M.show_discussion_popup(discussion)
  M.show_line_discussions_popup({discussion}, discussion.context and discussion.context.line_number or 1)
end

return M