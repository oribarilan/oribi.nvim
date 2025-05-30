local M = {}

-- Token cache
local cached_token = nil
local token_expiry = nil

-- Azure info cache
local cached_azure_info = nil

-- PR list cache
local cached_prs = nil
local prs_cache_expiry = nil
local PR_CACHE_DURATION = 60 -- Cache PRs for 60 seconds

-- Local state for authentication
local auth_state = {
  authenticated = false,
  organization = nil,
  project = nil,
  repo = nil,
}

-- Helper function to execute shell commands
local function execute_command(cmd)
  local handle = io.popen(cmd .. ' 2>&1')
  if not handle then
    return nil, 'Failed to execute command'
  end

  local result = handle:read '*a'
  local success = handle:close()

  if not success then
    return nil, 'Command failed: ' .. (result or 'unknown error')
  end

  return result:gsub('%s+$', ''), nil -- trim trailing whitespace
end

-- Get Azure DevOps token using Azure CLI
local function get_azure_token()
  local cmd = 'az account get-access-token --resource https://microsoft.visualstudio.com/ --query accessToken --output tsv'
  local handle = io.popen(cmd)
  if not handle then
    return nil, 'Failed to execute az cli command'
  end

  local token = handle:read('*a'):gsub('%s+', '') -- Remove whitespace/newlines
  handle:close()

  if token and token ~= '' and not token:match('ERROR') then
    cached_token = token
    -- Set expiry to 55 minutes from now (tokens usually valid for 1 hour)
    token_expiry = os.time() + (55 * 60)
    return token, nil
  end

  return nil, 'Failed to get valid token'
end

-- Ensure we have a valid token
local function ensure_token()
  if not cached_token or not token_expiry or os.time() > token_expiry then
    return get_azure_token()
  end
  return cached_token, nil
end

-- Get organization and project from git remote
local function get_azure_info()
  -- Return cached info if available
  if cached_azure_info then
    return cached_azure_info.org, cached_azure_info.project, cached_azure_info.repo, nil
  end
  
  local handle = io.popen('git remote get-url origin')
  if not handle then
    return nil, nil, nil, 'Failed to execute git remote command'
  end
  
  local url = handle:read('*a')
  handle:close()
  
  if not url then
    return nil, nil, nil, 'No URL returned from git remote'
  end
  
  -- Try different URL formats
  local org, project, repo
  
  -- First, get the repository name which is common across all formats
  repo = url:match('/_git/([^/\n]+)')
  if not repo then
    return nil, nil, nil, 'Failed to extract repository name from URL'
  end
  repo = repo:gsub('\n', '') -- Remove any trailing newline
  
  -- Format: https://dev.azure.com/microsoft/WDATP/_git/Port.Runner
  org = url:match('dev%.azure%.com/([^/]+)/')
  if org then
    project = url:match('dev%.azure%.com/[^/]+/([^/]+)/_git/')
    if project then
      -- Cache the result
      cached_azure_info = {org = org, project = project, repo = repo}
      return org, project, repo, nil
    end
  end

  -- Format: https://microsoft.visualstudio.com/DefaultCollection/WDATP/_git/Port.Runner
  org = url:match('visualstudio%.com/DefaultCollection/([^/]+)/')
  if org then
    -- Cache the result
    cached_azure_info = {org = "microsoft", project = org, repo = repo}
    return "microsoft", org, repo, nil
  end

  -- Format: https://microsoft.visualstudio.com/WDATP/_git/Port.Runner
  org = url:match('visualstudio%.com/([^/]+)/_git/')
  if org then
    -- Cache the result
    cached_azure_info = {org = "microsoft", project = org, repo = repo}
    return "microsoft", org, repo, nil
  end
  
  return nil, nil, nil, 'Could not parse Azure DevOps organization and project from remote URL: ' .. url
end

-- Check if current authentication is still valid
local function is_auth_valid()
  if not auth_state.authenticated then
    return false
  end

  if token_expiry and os.time() >= token_expiry then
    return false
  end

  return true
end

-- Authenticate against Azure CLI and get project info
function M.auth()
  -- Check if already authenticated and valid
  if is_auth_valid() then
    return {
      success = true,
      message = 'Already authenticated',
      organization = auth_state.organization,
      project = auth_state.project,
      repo = auth_state.repo,
    }
  end

  -- Get repository information
  local organization, project, repo, err = get_azure_info()
  if err then
    return {
      success = false,
      error = err,
    }
  end

  -- Check if Azure CLI is installed and logged in
  local token, err = get_azure_token()
  if err then
    return {
      success = false,
      error = 'Azure CLI authentication failed: ' .. err .. '. Please run "az login" first.',
    }
  end

  -- Update auth state
  auth_state.authenticated = true
  auth_state.organization = organization
  auth_state.project = project
  auth_state.repo = repo

  return {
    success = true,
    message = 'Successfully authenticated with Azure DevOps',
    organization = organization,
    project = project,
    repo = repo,
  }
end

-- List all open pull requests from the current repository
function M.list_prs()
  -- Ensure we're authenticated
  if not is_auth_valid() then
    local auth_result = M.auth()
    if not auth_result.success then
      return {
        success = false,
        error = 'Authentication failed: ' .. (auth_result.error or 'unknown error'),
      }
    end
  end

  -- Check if we have cached PRs that are still valid
  if cached_prs and prs_cache_expiry and os.time() < prs_cache_expiry then
    return {
      success = true,
      prs = vim.json.encode(cached_prs),
      organization = auth_state.organization,
      project = auth_state.project,
      repository = auth_state.repo,
    }
  end
  
  local token, err = ensure_token()
  if err then
    return {
      success = false,
      error = 'Failed to get Azure token: ' .. err,
    }
  end

  local organization, project, repo = auth_state.organization, auth_state.project, auth_state.repo
  
  local api_version = '7.1-preview.1'
  local url = string.format('https://dev.azure.com/%s/%s/_apis/git/repositories/%s/pullrequests?api-version=%s',
    organization, project, repo, api_version)
    
  local cmd = string.format('curl -s -H "Authorization: Bearer %s" "%s"', token, url)
  local handle = io.popen(cmd)
  
  if not handle then
    return {
      success = false,
      error = 'Failed to execute curl command',
    }
  end

  local response = handle:read('*a')
  handle:close()

  -- Try to clean any BOM or whitespace
  response = response:gsub("^%s*", ""):gsub("^%z+", "")

  -- Parse JSON response
  local ok, parsed = pcall(vim.json.decode, response)
  if not ok then
    return {
      success = false,
      error = 'JSON parse error: ' .. tostring(parsed),
    }
  end
  
  if not parsed.value then
    return {
      success = false,
      error = 'API response missing value field',
    }
  end

  -- Cache the result
  cached_prs = parsed.value
  prs_cache_expiry = os.time() + PR_CACHE_DURATION

  return {
    success = true,
    prs = vim.json.encode(parsed.value),
    organization = organization,
    project = project,
    repository = repo,
  }
end

-- Get current authentication status
function M.get_auth_status()
  return {
    authenticated = is_auth_valid(),
    organization = auth_state.organization,
    project = auth_state.project,
    repo = auth_state.repo,
    expires_at = token_expiry,
  }
end

-- Clear authentication state (logout)
function M.logout()
  auth_state.authenticated = false
  auth_state.organization = nil
  auth_state.project = nil
  auth_state.repo = nil
  cached_token = nil
  token_expiry = nil
  cached_azure_info = nil
  cached_prs = nil
  prs_cache_expiry = nil

  return {
    success = true,
    message = 'Logged out successfully',
  }
end

-- Vim command functions
function M.setup_commands()
  -- Command to login/authenticate with Azure DevOps
  vim.api.nvim_create_user_command('EzprLogin', function()
    print 'Logging in to Azure DevOps...'
    local result = M.auth()

    if result.success then
      print('✓ ' .. result.message)
      if result.organization and result.project then
        print('  Organization: ' .. result.organization)
        print('  Project: ' .. result.project)
        if result.repo then
          print('  Repository: ' .. result.repo)
        end
      end
    else
      print('✗ Login failed: ' .. (result.error or 'unknown error'))
    end
  end, {
    desc = 'Login to Azure DevOps',
  })

  -- Command to list pull requests
  vim.api.nvim_create_user_command('EzprListPRs', function()
    print 'Fetching open pull requests...'
    local result = M.list_prs()

    if result.success then
      if result.message then
        print('ℹ ' .. result.message)
      else
        print('✓ Pull requests from ' .. result.organization .. '/' .. result.project .. '/' .. result.repository .. ':')

        -- Parse and display PR information
        local ok, prs_data = pcall(vim.json.decode, result.prs)
        if ok and prs_data then
          if #prs_data == 0 then
            print '  No open pull requests found'
          else
            print('  Found ' .. #prs_data .. ' open pull request(s):')
            for i, pr in ipairs(prs_data) do
              if i <= 5 then  -- Show only first 5 PRs
                local author = pr.createdBy and pr.createdBy.displayName or "Unknown"
                print(string.format('  %d. #%d - %s (by %s)', i, pr.pullRequestId, pr.title, author))
              end
            end
            if #prs_data > 5 then
              print('  ... and ' .. (#prs_data - 5) .. ' more')
            end
          end
        else
          print('  Error parsing PR data')
        end
      end
    else
      print('✗ Failed to list pull requests: ' .. (result.error or 'unknown error'))
    end
  end, {
    desc = 'List open pull requests from current repository (auto-login if needed)',
  })

  -- Command to check authentication status
  vim.api.nvim_create_user_command('EzprStatus', function()
    local status = M.get_auth_status()

    if status.authenticated then
      print '✓ Authenticated with Azure DevOps'
      print('  Organization: ' .. (status.organization or 'unknown'))
      print('  Project: ' .. (status.project or 'unknown'))
      print('  Repository: ' .. (status.repo or 'unknown'))
      if status.expires_at then
        local remaining = status.expires_at - os.time()
        if remaining > 0 then
          print('  Token expires in: ' .. math.floor(remaining / 60) .. ' minutes')
        else
          print '  Token has expired'
        end
      end
    else
      print '✗ Not authenticated with Azure DevOps'
      print '  Run :EzprLogin to authenticate'
    end
  end, {
    desc = 'Check Azure DevOps authentication status',
  })

  -- Command to logout
  vim.api.nvim_create_user_command('EzprLogout', function()
    local result = M.logout()
    print('✓ ' .. result.message)
  end, {
    desc = 'Logout from Azure DevOps',
  })

  -- Command to fetch discussions for a PR
  vim.api.nvim_create_user_command('EzprDiscussions', function(opts)
    local pr_id = tonumber(opts.args)
    if not pr_id then
      print('✗ Please provide a PR ID: :EzprDiscussions <pr_id>')
      return
    end
    
    print('Fetching discussions for PR #' .. pr_id .. '...')
    local result = M.fetch_discussions(pr_id)
    
    if result.success then
      if #result.discussions == 0 then
        print('ℹ No discussions found for PR #' .. pr_id)
      else
        print('✓ Found ' .. result.total_count .. ' discussion(s) for PR #' .. pr_id .. ':')
        
        for i, discussion in ipairs(result.discussions) do
          local context_info = ""
          if discussion.context then
            local file_name = discussion.context.file_path:match("([^/]+)$") or discussion.context.file_path
            context_info = string.format(" (%s:%d)", file_name, discussion.context.line_number)
          end
          
          local author = discussion.comments[1].author.name
          local comment_count = #discussion.comments
          print(string.format('  %d. %s%s - %d comment%s by @%s',
            i,
            discussion.status,
            context_info,
            comment_count,
            comment_count > 1 and "s" or "",
            author
          ))
        end
      end
    else
      print('✗ Failed to fetch discussions: ' .. (result.error or 'unknown error'))
    end
  end, {
    nargs = 1,
    desc = 'Fetch discussions for a pull request by ID',
  })

  -- Commands registered silently
end

-- Fetch all discussions/threads for a given pull request
function M.fetch_discussions(pr_id)
  -- Ensure we're authenticated
  if not is_auth_valid() then
    local auth_result = M.auth()
    if not auth_result.success then
      return {
        success = false,
        error = 'Authentication failed: ' .. (auth_result.error or 'unknown error'),
      }
    end
  end

  local token, err = ensure_token()
  if err then
    return {
      success = false,
      error = 'Failed to get Azure token: ' .. err,
    }
  end

  local organization, project, repo = auth_state.organization, auth_state.project, auth_state.repo
  
  local url = string.format(
    'https://dev.azure.com/%s/%s/_apis/git/repositories/%s/pullRequests/%d/threads?api-version=7.1',
    organization, project, repo, pr_id
  )
  
  local cmd = string.format('curl -s -H "Authorization: Bearer %s" "%s"', token, url)
  local handle = io.popen(cmd)
  
  if not handle then
    return {
      success = false,
      error = 'Failed to execute curl command',
    }
  end

  local response = handle:read('*a')
  handle:close()

  -- Try to clean any BOM or whitespace
  response = response:gsub("^%s*", ""):gsub("^%z+", "")

  -- Parse JSON response
  local ok, parsed = pcall(vim.json.decode, response)
  if not ok then
    return {
      success = false,
      error = 'JSON parse error: ' .. tostring(parsed),
    }
  end
  
  if not parsed.value then
    return {
      success = true,
      discussions = {},
      message = 'No discussions found',
    }
  end

  -- Transform Azure DevOps threads to generic discussion format
  local discussions = {}
  for _, thread in ipairs(parsed.value) do
    if not thread.isDeleted and thread.comments and #thread.comments > 0 then
      local discussion = {
        id = thread.id,
        status = thread.status or "active",
        created_at = thread.comments[1].createdDate,
        updated_at = thread.comments[#thread.comments].lastUpdatedDate or thread.comments[#thread.comments].createdDate,
        comments = {},
        context = nil, -- Will be set if this is a code comment
      }
      
      -- Add context information if this is a code comment
      if thread.threadContext and
         type(thread.threadContext) == "table" and
         thread.threadContext.rightFileStart then
        discussion.context = {
          file_path = thread.threadContext.filePath,
          line_number = thread.threadContext.rightFileStart.line,
          side = "right", -- Azure DevOps context
        }
      end
      
      -- Transform comments to generic format
      for _, comment in ipairs(thread.comments) do
        if not comment.isDeleted then
          table.insert(discussion.comments, {
            id = comment.id,
            content = comment.content or "",
            author = {
              name = comment.author and comment.author.displayName or "Unknown",
              email = comment.author and comment.author.uniqueName or "",
              avatar_url = comment.author and comment.author.imageUrl or "",
            },
            created_at = comment.createdDate,
            updated_at = comment.lastUpdatedDate or comment.createdDate,
          })
        end
      end
      
      -- Only add discussions that have non-deleted comments
      if #discussion.comments > 0 then
        table.insert(discussions, discussion)
      end
    end
  end

  return {
    success = true,
    discussions = discussions,
    total_count = #discussions,
  }
end

-- Get discussions for a specific file and line (code comments only)
function M.fetch_file_discussions(pr_id, file_path, line_number)
  local result = M.fetch_discussions(pr_id)
  if not result.success then
    return result
  end
  
  local file_discussions = {}
  for _, discussion in ipairs(result.discussions) do
    if discussion.context and
       discussion.context.file_path == file_path and
       (not line_number or discussion.context.line_number == line_number) then
      table.insert(file_discussions, discussion)
    end
  end
  
  return {
    success = true,
    discussions = file_discussions,
    total_count = #file_discussions,
    file_path = file_path,
    line_number = line_number,
  }
end

return M
