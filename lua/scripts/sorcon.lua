local mock_prs = {
  { id = 1, title = 'Feature: Add new dashboard', author = 'John Doe', status = 'Active' },
  { id = 2, title = 'Fix: Memory leak in worker', author = 'Jane Smith', status = 'Active' },
  { id = 3, title = 'Docs: Update README', author = 'Bob Wilson', status = 'Active' },
}

-- Format PR for display
local function format_pr(pr)
  return string.format('#%d %s [%s]', pr.id, pr.title, pr.author)
end

-- Show PR picker
local function pick_pr()
  local items = {}
  local display_to_pr = {}

  for _, pr in ipairs(mock_prs) do
    local display = format_pr(pr)
    table.insert(items, display)
    display_to_pr[display] = pr
  end

  vim.ui.select(items, {
    prompt = 'Select PR:',
  }, function(choice)
    if choice then
      local selected_pr = display_to_pr[choice]
      print(string.format('Selected PR #%d: %s', selected_pr.id, selected_pr.title))
    end
  end)
end

vim.api.nvim_create_user_command('AzurePRs', function(_)
  pick_pr()
end, {})

vim.keymap.set('n', '<leader>pr', pick_pr, { desc = 'List Azure PRs' })
