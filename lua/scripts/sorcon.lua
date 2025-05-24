-- Initialize backend (change to sorcon_be_mock for testing)
local backend = require('scripts.sorcon_be_mock')

-- Helper function to format author name
local function format_author(name)
  if #name > 15 then
    return name:sub(1, 12) .. "..."
  end
  return name
end

-- Show diff for first changed file
local function show_pr_diff(pr)
  local file_info = backend.fetch_first_change(pr)
  if not file_info then return end

  -- Get source branch content
  local source_ref = string.format('origin/%s', pr.sourceRefName:gsub('^refs/heads/', ''))
  local pr_content = backend.fetch_file_content(file_info.path, source_ref)
  
  -- Get main branch content
  local main_content = backend.fetch_file_content(file_info.path, 'origin/main')
  
  if not pr_content or not main_content then
    vim.notify('Failed to fetch file content', vim.log.levels.ERROR)
    return
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
  vim.cmd('vertical diffsplit ' .. tmp_pr)
  
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
vim.api.nvim_create_user_command('AzurePRs', function(_)
  pick_pr()
end, {})

vim.keymap.set('n', '<leader>pr', function()
  pick_pr()
end, { desc = 'List Azure PRs' })
