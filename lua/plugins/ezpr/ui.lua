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
  
  vim.notify("Loaded side-by-side diff: " .. filename, vim.log.levels.INFO)
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
  
  vim.notify("Loaded new file: " .. filename, vim.log.levels.INFO)
end

-- Clean up existing diff buffers and temporary files
function M.cleanup_existing_diff()
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
    vim.notify("Jumped to line " .. line_num, vim.log.levels.INFO)
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
  
  -- Update the state
  M.state.pr_data = pr
  
  -- Load actual files from the PR
  M.load_pr_files(pr)
  
  vim.notify("PR loaded: " .. pr.title, vim.log.levels.INFO)
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