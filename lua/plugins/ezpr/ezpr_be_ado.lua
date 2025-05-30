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

  -- Command to create a comment on the current PR using highlighted text
  vim.api.nvim_create_user_command('EzprCommentSelected', function(opts)
    -- This command will be handled by the UI module
    local ezpr_ui = require("plugins.ezpr.ui")
    
    if ezpr_ui.create_comment_with_selection then
      ezpr_ui.create_comment_with_selection()
    else
      vim.notify("create_comment_with_selection function not found", vim.log.levels.ERROR)
    end
  end, {
    desc = 'Create a comment on the current PR using highlighted text',
  })

  -- Command to reply to an existing discussion
  vim.api.nvim_create_user_command('EzprReplyToDiscussion', function(opts)
    local args = vim.split(opts.args, ' ', { trimempty = true })
    local pr_id = tonumber(args[1])
    local thread_id = tonumber(args[2])
    local reply_content = table.concat(args, ' ', 3)  -- Rest is the reply content
    
    if not pr_id or not thread_id or not reply_content or reply_content == '' then
      print('✗ Usage: :EzprReplyToDiscussion <pr_id> <thread_id> <reply_content>')
      print('  Example: :EzprReplyToDiscussion 123 456 "I agree with this suggestion"')
      return
    end
    
    print('Replying to discussion ' .. thread_id .. ' on PR #' .. pr_id .. '...')
    local result = M.reply_to_discussion(pr_id, thread_id, reply_content)
    
    if result.success then
      print('✓ ' .. result.message)
      if result.comment_id then
        print('  Comment ID: ' .. result.comment_id)
      end
    else
      print('✗ Failed to create reply: ' .. (result.error or 'unknown error'))
      if result.raw_response then
        print('  Raw response: ' .. result.raw_response:sub(1, 200) .. '...')
      end
    end
  end, {
    nargs = '+',
    desc = 'Reply to an existing discussion thread',
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
      if thread.threadContext and type(thread.threadContext) == "table" then
        local context = thread.threadContext
        local discussion_context = {
          file_path = context.filePath,
          thread_type = context.threadType or "text",
        }
        
        -- Handle right file context (modified/new lines)
        if context.rightFileStart then
          discussion_context.right_file = {
            start_line = context.rightFileStart.line,
            start_column = context.rightFileStart.offset,
            end_line = context.rightFileEnd and context.rightFileEnd.line or context.rightFileStart.line,
            end_column = context.rightFileEnd and context.rightFileEnd.offset,
          }
          -- Set primary position from right file (for new/modified content)
          discussion_context.start_line = context.rightFileStart.line
          discussion_context.start_column = context.rightFileStart.offset
          discussion_context.end_line = context.rightFileEnd and context.rightFileEnd.line or context.rightFileStart.line
          discussion_context.end_column = context.rightFileEnd and context.rightFileEnd.offset
          discussion_context.side = "right"
        end
        
        -- Handle left file context (original/deleted lines)
        if context.leftFileStart then
          discussion_context.left_file = {
            start_line = context.leftFileStart.line,
            start_column = context.leftFileStart.offset,
            end_line = context.leftFileEnd and context.leftFileEnd.line or context.leftFileStart.line,
            end_column = context.leftFileEnd and context.leftFileEnd.offset,
          }
          -- If no right file context, use left file as primary (for deleted content)
          if not context.rightFileStart then
            discussion_context.start_line = context.leftFileStart.line
            discussion_context.start_column = context.leftFileStart.offset
            discussion_context.end_line = context.leftFileEnd and context.leftFileEnd.line or context.leftFileStart.line
            discussion_context.end_column = context.leftFileEnd and context.leftFileEnd.offset
            discussion_context.side = "left"
          end
        end
        
        -- Add iteration and tracking context if available
        if thread.pullRequestThreadContext then
          local prContext = thread.pullRequestThreadContext
          discussion_context.iteration_context = prContext.iterationContext
          discussion_context.tracking_criteria = prContext.trackingCriteria
          discussion_context.change_tracking_id = prContext.changeTrackingId
        end
        
        -- Determine comment state
        discussion_context.is_outdated = thread.isDeleted or false
        if thread.status then
          discussion_context.status = thread.status -- 1=Active, 4=Fixed, etc.
        end
        
        -- Keep line_number for backward compatibility
        discussion_context.line_number = discussion_context.start_line
        
        discussion.context = discussion_context
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

-- Fetch all files changed in a pull request
function M.fetch_pr_files(pr_id)
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
  
  -- API endpoint for getting PR files/iterations
  local api_url = string.format(
    'https://dev.azure.com/%s/%s/_apis/git/repositories/%s/pullRequests/%s/iterations?api-version=7.0',
    organization, project, repo, pr_id
  )

  local curl_cmd = string.format(
    "curl -s -H 'Authorization: Bearer %s' -H 'Content-Type: application/json' '%s'",
    token, api_url
  )

  local result, curl_err = execute_command(curl_cmd)
  if curl_err then
    return {
      success = false,
      error = 'Failed to fetch PR iterations: ' .. curl_err,
    }
  end

  local success, iterations_data = pcall(vim.json.decode, result)
  if not success then
    return {
      success = false,
      error = 'Failed to parse iterations response: ' .. (iterations_data or 'unknown'),
    }
  end

  if not iterations_data.value or #iterations_data.value == 0 then
    return {
      success = true,
      files = {},
    }
  end

  -- Get the latest iteration
  local latest_iteration = iterations_data.value[#iterations_data.value]
  local iteration_id = latest_iteration.id

  -- Get files for this iteration
  local files_url = string.format(
    'https://dev.azure.com/%s/%s/_apis/git/repositories/%s/pullRequests/%s/iterations/%s/changes?api-version=7.0',
    organization, project, repo, pr_id, iteration_id
  )

  local files_cmd = string.format(
    "curl -s -H 'Authorization: Bearer %s' -H 'Content-Type: application/json' '%s'",
    token, files_url
  )

  local files_result, files_err = execute_command(files_cmd)
  if files_err then
    return {
      success = false,
      error = 'Failed to fetch PR files: ' .. files_err,
    }
  end

  local files_success, files_data = pcall(vim.json.decode, files_result)
  if not files_success then
    return {
      success = false,
      error = 'Failed to parse files response: ' .. (files_data or 'unknown'),
    }
  end

  local pr_files = {}
  if files_data.changeEntries then
    for _, change in ipairs(files_data.changeEntries) do
      if change.item and change.item.path then
        local file_info = {
          path = change.item.path,
          changeType = change.changeType or "unknown",
          isFolder = change.item.isFolder or false,
        }
        
        -- Only include files, not folders
        if not file_info.isFolder then
          table.insert(pr_files, file_info)
        end
      end
    end
  end

  return {
    success = true,
    files = pr_files,
    pr_id = pr_id,
    iteration_id = iteration_id,
  }
end

-- Fetch content of a specific file in a PR
function M.fetch_pr_file_content(pr_id, file_path)
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
  
  -- Get PR details to find source branch
  local pr_url = string.format(
    'https://dev.azure.com/%s/%s/_apis/git/repositories/%s/pullRequests/%s?api-version=7.0',
    organization, project, repo, pr_id
  )

  local pr_cmd = string.format(
    "curl -s -H 'Authorization: Bearer %s' -H 'Content-Type: application/json' '%s'",
    token, pr_url
  )

  local pr_result, pr_err = execute_command(pr_cmd)
  if pr_err then
    return {
      success = false,
      error = 'Failed to fetch PR details: ' .. pr_err,
    }
  end

  local pr_success, pr_data = pcall(vim.json.decode, pr_result)
  if not pr_success or not pr_data.sourceRefName then
    return {
      success = false,
      error = 'Failed to get PR source branch',
    }
  end

  local source_ref = pr_data.sourceRefName:gsub('^refs/heads/', '')
  
  -- Get file content from source branch
  local file_url = string.format(
    'https://dev.azure.com/%s/%s/_apis/git/repositories/%s/items?path=%s&version=%s&api-version=7.0',
    organization, project, repo, file_path, source_ref
  )

  local file_cmd = string.format(
    "curl -s -H 'Authorization: Bearer %s' '%s'",
    token, file_url
  )

  local file_result, file_err = execute_command(file_cmd)
  if file_err then
    return {
      success = false,
      error = 'Failed to fetch file content: ' .. file_err,
    }
  end

  return {
    success = true,
    content = file_result,
    file_path = file_path,
    branch = source_ref,
  }
end
-- Create a new comment/discussion on a pull request
function M.create_pr_comment(pr_id, comment_content, file_path, start_line, end_line, start_column, end_column)
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
  
  -- Build the thread creation payload
  local thread_payload = {
    comments = {
      {
        parentCommentId = 0,
        content = comment_content,
        commentType = 1  -- Text comment
      }
    },
    status = 1,  -- Active status
  }
  
  -- Add thread context if file path and line information is provided
  if file_path and start_line then
    -- Azure DevOps API expects 1-based line numbers, but we might be getting 0-based
    -- Ensure line numbers are at least 1
    local adj_start_line = math.max(1, start_line)
    local adj_end_line = math.max(1, end_line or start_line)
    local adj_start_column = math.max(1, start_column or 1)
    local adj_end_column = math.max(1, end_column or (start_column and start_column + 1 or 2))
    
    thread_payload.threadContext = {
      filePath = file_path,
      rightFileStart = {
        line = adj_start_line,
        offset = adj_start_column
      },
      rightFileEnd = {
        line = adj_end_line,
        offset = adj_end_column
      }
    }
  end
  
  local api_version = '7.1'
  local url = string.format(
    'https://dev.azure.com/%s/%s/_apis/git/repositories/%s/pullRequests/%d/threads?api-version=%s',
    organization, project, repo, pr_id, api_version
  )
  
  -- Convert payload to JSON
  local json_payload = vim.json.encode(thread_payload)
  
  -- Create curl command to post the comment
  local cmd = string.format(
    'curl -s -X POST -H "Authorization: Bearer %s" -H "Content-Type: application/json" -d %s "%s"',
    token,
    vim.fn.shellescape(json_payload),
    url
  )
  
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
      raw_response = response
    }
  end
  
  -- Check for API errors
  if parsed.message and parsed.message:match('[Ee]rror') then
    return {
      success = false,
      error = 'API error: ' .. parsed.message,
      raw_response = response
    }
  end
  
  -- Check if we got a valid thread response
  if not parsed.id then
    return {
      success = false,
      error = 'Invalid response: missing thread ID',
      raw_response = response
    }
  end

  return {
    success = true,
    thread_id = parsed.id,
    comment_id = parsed.comments and parsed.comments[1] and parsed.comments[1].id or nil,
    message = 'Comment created successfully'
  }
end

-- Create a reply to an existing discussion thread
function M.reply_to_discussion(pr_id, thread_id, reply_content)
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
  
  -- Build the comment payload
  local comment_payload = {
    content = reply_content,
    parentCommentId = 0,  -- 0 means it's a root-level reply to the thread
    commentType = 1  -- Text comment
  }
  
  local api_version = '7.1'
  local url = string.format(
    'https://dev.azure.com/%s/%s/_apis/git/repositories/%s/pullRequests/%d/threads/%d/comments?api-version=%s',
    organization, project, repo, pr_id, thread_id, api_version
  )
  
  -- Convert payload to JSON
  local json_payload = vim.json.encode(comment_payload)
  
  -- Create curl command to post the reply
  local cmd = string.format(
    'curl -s -X POST -H "Authorization: Bearer %s" -H "Content-Type: application/json" -d %s "%s"',
    token,
    vim.fn.shellescape(json_payload),
    url
  )
  
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
      raw_response = response
    }
  end
  
  -- Check for API errors
  if parsed.message and parsed.message:match('[Ee]rror') then
    return {
      success = false,
      error = 'API error: ' .. parsed.message,
      raw_response = response
    }
  end
  
  -- Check if we got a valid comment response
  if not parsed.id then
    return {
      success = false,
      error = 'Invalid response: missing comment ID',
      raw_response = response
    }
  end

  return {
    success = true,
    comment_id = parsed.id,
    message = 'Reply created successfully'
  }
end

-- Update discussion thread status
function M.update_discussion_status(pr_id, thread_id, new_status)
  -- Ensure we're authenticated
  if not auth_state.authenticated then
    local success, err = M.authenticate()
    if not success then
      return { success = false, error = err }
    end
  end

  local token, err = get_azure_token()
  if not token then
    return { success = false, error = 'Failed to get Azure token: ' .. (err or 'unknown error') }
  end

  -- Map status names to Azure DevOps status codes
  local status_codes = {
    active = 1,
    resolved = 2,  -- Maps to "Fixed" in Azure DevOps
    ["won't fix"] = 3,  -- Maps to "WontFix" in Azure DevOps
    closed = 4,  -- Maps to "Closed" in Azure DevOps
    pending = 6   -- Maps to "Pending" in Azure DevOps
  }
  
  local status_code = status_codes[new_status:lower()]
  if not status_code then
    return { success = false, error = 'Invalid status: ' .. new_status }
  end

  local url = string.format(
    'https://dev.azure.com/%s/%s/_apis/git/repositories/%s/pullRequests/%s/threads/%s?api-version=7.0',
    auth_state.organization, auth_state.project, auth_state.repo, pr_id, thread_id
  )

  local data = {
    status = status_code
  }

  local cmd = string.format(
    'curl -s -X PATCH "%s" ' ..
    '-H "Authorization: Bearer %s" ' ..
    '-H "Content-Type: application/json" ' ..
    '-d \'%s\'',
    url, token, vim.fn.json_encode(data)
  )

  local result, cmd_err = execute_command(cmd)
  if cmd_err then
    return { success = false, error = 'Failed to execute update command: ' .. cmd_err }
  end

  local success, response = pcall(vim.fn.json_decode, result)
  if not success then
    return { success = false, error = 'Failed to parse response: ' .. tostring(response) }
  end

  if response.errorCode then
    return { success = false, error = response.message or 'Unknown API error' }
  end

  return { success = true, thread = response }
end

return M
