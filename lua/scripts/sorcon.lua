-- Initialize backend (change to sorcon_be_mock for testing)
local backend = require('scripts.sorcon_be_ado')

-- Helper function to format author name
local function format_author(name)
  if #name > 15 then
    return name:sub(1, 12) .. "..."
  end
  return name
end

-- Show PR comments with virtual text
local function show_pr_comments(pr, bufnr)
  -- Check if get_threads function exists in backend
  if not backend.get_threads then
    -- Function not implemented yet, skip showing comments
    return
  end
  
  local threads = backend.get_threads(pr)
  if not threads or #threads == 0 then return end

  -- Create namespace for comment extmarks
  local ns_id = vim.api.nvim_create_namespace('sorcon_comments')

  -- Add highlight groups
  vim.api.nvim_set_hl(0, 'SorconCommentIndicator', { fg = '#61afef', bold = true })
  vim.api.nvim_set_hl(0, 'SorconCommentAuthor', { fg = '#98c379', bold = true })
  vim.api.nvim_set_hl(0, 'SorconCommentDate', { fg = '#888888', italic = true })
  vim.api.nvim_set_hl(0, 'SorconCommentState', { fg = '#d19a66', bold = true })

  -- Store thread data globally for access in toggle function
  _G.sorcon_thread_data = _G.sorcon_thread_data or {}
  _G.sorcon_thread_data[bufnr] = {}
  
  -- Store floating window state
  _G.sorcon_float_wins = _G.sorcon_float_wins or {}

  -- Add comment thread indicators and hover handlers
  for _, thread in ipairs(threads) do
    local line_num = thread.threadContext.rightFileStart.line - 1  -- Convert to 0-based
    
    -- Check if line number is valid for the current buffer
    local buf_line_count = vim.api.nvim_buf_line_count(bufnr)
    if line_num < 0 or line_num >= buf_line_count then
      -- Skip this thread if line number is out of range
      goto continue
    end
    
    -- Store thread data
    _G.sorcon_thread_data[bufnr][line_num] = thread
    
    -- Create the metadata line
    local comment_count = #thread.comments
    local latest_comment = thread.comments[#thread.comments]
    local metadata = string.format(
      "💬 %d message%s | Last: @%s | State: %s",
      comment_count,
      comment_count > 1 and "s" or "",
      format_author(latest_comment.author.displayName),
      thread.status or "Active"
    )
    
    -- Create extmark with metadata
    vim.api.nvim_buf_set_extmark(bufnr, ns_id, line_num, 0, {
      virt_text = {
        { metadata, "SorconCommentIndicator" }
      },
      virt_text_pos = "overlay",
      hl_mode = "combine"
    })
    
    ::continue::
  end

  -- Clean up when buffer is unloaded
  vim.api.nvim_create_autocmd('BufUnload', {
    buffer = bufnr,
    callback = function()
      vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
    end,
    once = true
  })
end

-- Show diff for first changed file
local function show_pr_diff(pr)
  local file_info = backend.fetch_first_change(pr)
  if not file_info then return end

  -- Get source branch content
  local source_ref = string.format('origin/%s', pr.sourceRefName:gsub('^refs/heads/', ''))
  local pr_content = backend.fetch_file_content(file_info.path, source_ref)
  
  if not pr_content then
    vim.notify('Failed to fetch PR file content', vim.log.levels.ERROR)
    return
  end
  
  -- Get main branch content (may be nil for new files)
  local main_content = backend.fetch_file_content(file_info.path, 'origin/main')
  
  -- If file doesn't exist in main branch, it's a new file - use empty content
  if not main_content then
    main_content = ""
    vim.notify(string.format('File %s is new (not in main branch)', file_info.path), vim.log.levels.INFO)
  end
  
  -- Create temporary files
  local tmp_pr = os.tmpname()
  local tmp_main = os.tmpname()
  
  local f = io.open(tmp_pr, 'w')
  f:write(pr_content)
  f:close()
  
  f = io.open(tmp_main, 'w')
  f:write(main_content)
  f:close()
  
  -- Open diff view
  vim.cmd('tabnew ' .. tmp_main)
  local main_bufnr = vim.api.nvim_get_current_buf()
  vim.cmd('vertical diffsplit ' .. tmp_pr)
  local pr_bufnr = vim.api.nvim_get_current_buf()
  
  -- Show comments on the PR buffer (right side) since that's where the content is
  show_pr_comments(pr, pr_bufnr)
  
  -- Clean up temp files when buffers are closed
  vim.api.nvim_create_autocmd('BufUnload', {
    pattern = {tmp_main, tmp_pr},
    callback = function()
      os.remove(tmp_main)
      os.remove(tmp_pr)
    end,
    once = true
  })
end

-- Format PR for display
local function format_pr(pr)
  local author = format_author(pr.createdBy.displayName)
  return string.format('[%s]\t\t\t%s', author, pr.title)
end

-- Show PR picker
local function pick_pr()
  local prs = backend.fetch_prs()
  if not prs then
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
        '\nPR #%d: %s\nAuthor: %s\nCreated: %s\nSource: %s → %s\nURL: %s',
        selected_pr.pullRequestId,
        selected_pr.title,
        selected_pr.createdBy.displayName,
        selected_pr.creationDate:sub(1, 10),
        selected_pr.sourceRefName:gsub('refs/heads/', ''),
        selected_pr.targetRefName:gsub('refs/heads/', ''),
        selected_pr.url
      )
      print(details)
      
      -- Show diff for first changed file
      show_pr_diff(selected_pr)
    end
  end)
end

-- Define the command and mapping
-- Toggle comment thread display
local function toggle_thread()
  local bufnr = vim.api.nvim_get_current_buf()
  local line = vim.api.nvim_win_get_cursor(0)[1] - 1
  local thread = _G.sorcon_thread_data[bufnr] and _G.sorcon_thread_data[bufnr][line]
  
  if not thread then return end
  
  -- Close existing float window if it exists
  if _G.sorcon_float_wins[line] then
    local win_valid = vim.api.nvim_win_is_valid(_G.sorcon_float_wins[line])
    if win_valid then
      vim.api.nvim_win_close(_G.sorcon_float_wins[line], true)
      _G.sorcon_float_wins[line] = nil
      return
    end
  end

  local content = {}
  
  -- Format each comment in the thread
  for _, comment in ipairs(thread.comments) do
    local author = format_author(comment.author.displayName)
    local date = comment.createdDate:sub(1, 10)
    
    table.insert(content, string.format("@%s", author))
    table.insert(content, string.format("Posted on %s", date))
    table.insert(content, "")
    
    -- Add comment content, preserving line breaks
    for _, line in ipairs(vim.split(comment.content, "\n", { plain = true })) do
      table.insert(content, line)
    end
    table.insert(content, string.rep("─", 30))
  end
  
  -- Remove last separator
  if #content > 0 then
    table.remove(content)
  end

  -- Show floating window with comments
  local popup_bufnr, winnr = vim.lsp.util.open_floating_preview(content, 'markdown', {
    border = 'rounded',
    max_width = 80,
    max_height = 20,
    focus = false
  })

  _G.sorcon_float_wins[line] = winnr

  -- Add highlights to the popup
  for i, line in ipairs(content) do
    if line:match("^@") then
      vim.api.nvim_buf_add_highlight(popup_bufnr, 0, 'SorconCommentAuthor', i-1, 0, -1)
    elseif line:match("^Posted on") then
      vim.api.nvim_buf_add_highlight(popup_bufnr, 0, 'SorconCommentDate', i-1, 0, -1)
    end
  end
end

vim.api.nvim_create_user_command('AzurePRs', function(_)
  pick_pr()
end, {})

-- Key mappings
vim.keymap.set('n', '<leader>pr', function()
  pick_pr()
end, { desc = 'List Azure PRs' })

vim.keymap.set('n', '<leader>pc', function()
  toggle_thread()
end, { desc = 'Toggle PR comment thread' })
