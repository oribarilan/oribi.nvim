-- Token cache
local cached_token = nil
local token_expiry = nil

-- Get Azure DevOps token using Azure CLI
local function get_azure_token()
  local cmd = 'az account get-access-token --resource https://microsoft.visualstudio.com/ --query accessToken --output tsv'
  local handle = io.popen(cmd)
  if not handle then
    error 'Failed to execute az cli command'
    return nil
  end

  local token = handle:read('*a'):gsub('%s+', '') -- Remove whitespace/newlines
  handle:close()

  if token and token ~= '' then
    cached_token = token
    -- Set expiry to 55 minutes from now (tokens usually valid for 1 hour)
    token_expiry = os.time() + (55 * 60)
    return token
  end

  return nil
end

-- Ensure we have a valid token
local function ensure_token()
  if not cached_token or not token_expiry or os.time() > token_expiry then
    return get_azure_token()
  end
  return cached_token
end

-- Get organization and project from git remote
local function get_azure_info()
  local handle = io.popen('git remote get-url origin')
  if not handle then
    vim.notify('Failed to execute git remote command', vim.log.levels.ERROR)
    return nil
  end
  
  local url = handle:read('*a')
  handle:close()
  
  if not url then
    vim.notify('No URL returned from git remote', vim.log.levels.ERROR)
    return nil
  end
  
  vim.notify('Git Remote URL: ' .. url, vim.log.levels.INFO)
  
  -- Try different URL formats
  local org, project, repo
  
  -- First, get the repository name which is common across all formats
  repo = url:match('/_git/([^/\n]+)')
  if not repo then
    vim.notify('Failed to extract repository name from URL', vim.log.levels.ERROR)
    return nil
  end
  repo = repo:gsub('\n', '') -- Remove any trailing newline
  
  -- Format: https://dev.azure.com/microsoft/WDATP/_git/Port.Runner
  org = url:match('dev%.azure%.com/([^/]+)/')
  if org then
    project = url:match('dev%.azure%.com/[^/]+/([^/]+)/_git/')
    if project then
      vim.notify(string.format('Matched dev.azure.com format - Org: %s, Project: %s, Repo: %s', org, project, repo), vim.log.levels.INFO)
      return org, project, repo
    end
  end

  -- Format: https://microsoft.visualstudio.com/DefaultCollection/WDATP/_git/Port.Runner
  org = url:match('visualstudio%.com/DefaultCollection/([^/]+)/')
  if org then
    vim.notify(string.format('Matched visualstudio.com/DefaultCollection format - Org: microsoft, Project: %s, Repo: %s', org, repo), vim.log.levels.INFO)
    return "microsoft", org, repo
  end

  -- Format: https://microsoft.visualstudio.com/WDATP/_git/Port.Runner
  org = url:match('visualstudio%.com/([^/]+)/_git/')
  if org then
    vim.notify(string.format('Matched visualstudio.com format - Org: microsoft, Project: %s, Repo: %s', org, repo), vim.log.levels.INFO)
    return "microsoft", org, repo
  end

  vim.notify('Failed to match any known URL format: ' .. url, vim.log.levels.ERROR)
  
  -- Remove any trailing newline and return
  if repo then repo = repo:gsub('\n', '') end
  return org, project, repo
end

-- Fetch PRs from Azure DevOps API
local function fetch_prs()
  local token = ensure_token()
  if not token then
    vim.notify('Failed to get Azure token. Is az cli logged in?', vim.log.levels.ERROR)
    return nil
  end

  local organization, project, repo = get_azure_info()
  if not organization or not project or not repo then
    vim.notify('Failed to extract organization/project/repo from git remote URL', vim.log.levels.ERROR)
    return nil
  end
  
  vim.notify(string.format('Organization: %s, Project: %s, Repo: %s', organization, project, repo), vim.log.levels.INFO)

  local api_version = '7.1-preview.1'
  local url = string.format('https://dev.azure.com/%s/%s/_apis/git/repositories/%s/pullrequests?api-version=%s',
    organization, project, repo, api_version)
    
  local cmd = string.format('curl -s -H "Authorization: Bearer %s" "%s"', token, url)
  local handle = io.popen(cmd)
  
  if not handle then
    vim.notify('Failed to execute curl command', vim.log.levels.ERROR)
    return nil
  end

  local response = handle:read('*a')
  handle:close()

  vim.notify('PR List Raw Response: ' .. response, vim.log.levels.DEBUG)

  if response == '' then
    vim.notify('Empty response from Azure DevOps API', vim.log.levels.ERROR)
    return nil
  end

  -- Try to clean any BOM or whitespace
  response = response:gsub("^%s*", ""):gsub("^%z+", "")

  -- Parse JSON response
  local ok, parsed = pcall(vim.json.decode, response)
  if not ok then
    vim.notify('JSON parse error: ' .. tostring(parsed), vim.log.levels.ERROR)
    return nil
  end
  
  if not parsed.value then
    vim.notify('API response missing value field: ' .. vim.inspect(parsed), vim.log.levels.ERROR)
    return nil
  end

  if #parsed.value == 0 then
    vim.notify('No open pull requests', vim.log.levels.INFO)
    return nil
  end

  return parsed.value
end

-- Helper function to format author name
local function format_author(name)
  if #name > 15 then
    return name:sub(1, 12) .. "..."
  end
  return name
end

-- Fetch file content using git commands
local function fetch_file_content(path, ref)
  -- First ensure we have latest changes
  local fetch_cmd = 'git fetch origin'
  local handle = io.popen(fetch_cmd)
  if not handle then
    vim.notify('Failed to fetch from origin', vim.log.levels.ERROR)
    return nil
  end
  handle:close()

  -- Strip leading slash and get file content from the ref
  local git_path = path:gsub("^/", "")
  local cmd = string.format('git show %s:%s 2>/dev/null', ref, git_path)
  vim.notify('Getting file content: ' .. cmd, vim.log.levels.DEBUG)
  
  handle = io.popen(cmd)
  if not handle then
    vim.notify('Failed to get file content', vim.log.levels.ERROR)
    return nil
  end
  
  local content = handle:read('*a')
  handle:close()

  if content == "" then
    vim.notify('No content found for ' .. path .. ' at ' .. ref, vim.log.levels.ERROR)
    return nil
  end

  return content
end

-- Get latest iteration ID for a PR
local function get_latest_iteration(organization, project, repo, pr_id)
  local token = ensure_token()
  if not token then return nil end

  local url = string.format(
    'https://dev.azure.com/%s/%s/_apis/git/repositories/%s/pullRequests/%d/iterations?api-version=7.1',
    organization, project, repo, pr_id
  )
  
  local cmd = string.format('curl -s -H "Authorization: Bearer %s" "%s"', token, url)
  local handle = io.popen(cmd)
  if not handle then return nil end
  
  local response = handle:read('*a')
  handle:close()

  vim.notify('Iterations API URL: ' .. url, vim.log.levels.INFO)
  vim.notify('Iterations Raw Response: ' .. response, vim.log.levels.DEBUG)

  -- Try to clean any BOM or whitespace
  response = response:gsub("^%s*", ""):gsub("^%z+", "")
  
  local ok, parsed = pcall(vim.json.decode, response)
  if not ok then
    vim.notify('Failed to parse iterations response: ' .. tostring(parsed), vim.log.levels.ERROR)
    return nil
  end

  if not parsed.value or #parsed.value == 0 then
    vim.notify('No iterations found', vim.log.levels.ERROR)
    return nil
  end

  -- Get the last iteration
  return parsed.value[#parsed.value].id
end

-- Fetch first change info from PR
local function fetch_first_change(organization, project, repo, pr_id)
  local token = ensure_token()
  if not token then return nil end

  -- First get the latest iteration
  local iteration_id = get_latest_iteration(organization, project, repo, pr_id)
  if not iteration_id then return nil end

  local url = string.format(
    'https://dev.azure.com/%s/%s/_apis/git/repositories/%s/pullRequests/%d/iterations/%d/changes?api-version=7.1',
    organization, project, repo, pr_id, iteration_id
  )
  
  local cmd = string.format('curl -s -H "Authorization: Bearer %s" "%s"', token, url)
  local handle = io.popen(cmd)
  if not handle then return nil end
  
  local response = handle:read('*a')
  handle:close()

  vim.notify('Changes API URL: ' .. url, vim.log.levels.INFO)
  vim.notify('Changes Raw Response: ' .. response, vim.log.levels.DEBUG)

  -- Try to clean any BOM or whitespace
  response = response:gsub("^%s*", ""):gsub("^%z+", "")
  
  local ok, parsed = pcall(vim.json.decode, response)
  if not ok then
    vim.notify('Failed to parse changes response: ' .. tostring(parsed), vim.log.levels.ERROR)
    return nil
  end

  if not parsed.changeEntries or #parsed.changeEntries == 0 then
    vim.notify('No changes found', vim.log.levels.ERROR)
    return nil
  end

  local first_change = parsed.changeEntries[1]
  return {
    path = first_change.item.path,
    new_id = string.lower(first_change.item.objectId),
    old_id = string.lower(first_change.item.originalObjectId)
  }
end

-- Show diff for first changed file
local function show_pr_diff(pr)
  -- Get repo info
  local organization, project, repo = get_azure_info()
  if not organization or not project or not repo then
    vim.notify('Failed to get repo info', vim.log.levels.ERROR)
    return
  end
  
  -- Debug PR info
  vim.notify(string.format(
    'PR Info:\nID: %d\nOrg: %s\nProject: %s\nRepo: %s\nSource: %s\nTarget: %s',
    pr.pullRequestId,
    organization,
    project,
    repo,
    pr.sourceRefName,
    pr.targetRefName
  ), vim.log.levels.DEBUG)

  local file_path = fetch_first_change(
    organization,
    project,
    repo,
    pr.pullRequestId
  )
  
  if not file_path then return end

  -- First fetch latest changes
  vim.notify('Fetching latest changes from origin', vim.log.levels.INFO)
  local fetch_cmd = 'git fetch origin'
  local handle = io.popen(fetch_cmd)
  if not handle then
    vim.notify('Failed to fetch from origin', vim.log.levels.ERROR)
    return
  end
  handle:close()
  
  -- Get source branch content
  local source_ref = string.format('origin/%s', pr.sourceRefName:gsub('^refs/heads/', ''))
  local pr_content = fetch_file_content(file_path.path, source_ref)
  
  -- Get main branch content
  local main_content = fetch_file_content(file_path.path, 'origin/main')
  
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
  local prs = fetch_prs()
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
