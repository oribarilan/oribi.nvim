-- Generic interface for pull request management across different platforms
-- This defines the standard data structures and API that backends should implement

local M = {}

-- Standard data structures that all backends should return

-- Pull Request structure
M.PullRequest = {
  id = nil,              -- string|number: Unique identifier for the PR
  number = nil,          -- number: PR number (for display)
  title = nil,           -- string: PR title
  description = nil,     -- string: PR description/body
  author = {
    name = nil,          -- string: Author display name
    email = nil,         -- string: Author email
    avatar_url = nil,    -- string: Author avatar URL
  },
  source_branch = nil,   -- string: Source branch name
  target_branch = nil,   -- string: Target branch name
  status = nil,          -- string: "open", "closed", "merged", "draft"
  created_at = nil,      -- string: ISO date string
  updated_at = nil,      -- string: ISO date string
  url = nil,             -- string: Web URL to the PR
  repository = {
    name = nil,          -- string: Repository name
    organization = nil,  -- string: Organization/owner name
    project = nil,       -- string: Project name (for Azure DevOps)
  }
}

-- Discussion/Thread structure
M.Discussion = {
  id = nil,              -- string|number: Unique identifier
  status = nil,          -- string: "active", "resolved", "closed"
  created_at = nil,      -- string: ISO date string
  updated_at = nil,      -- string: ISO date string
  comments = {},         -- array of Comment structures
  context = nil,         -- Context structure or nil for general discussions
}

-- Comment structure
M.Comment = {
  id = nil,              -- string|number: Unique identifier
  content = nil,         -- string: Comment content/body
  author = {
    name = nil,          -- string: Author display name
    email = nil,         -- string: Author email
    avatar_url = nil,    -- string: Author avatar URL
  },
  created_at = nil,      -- string: ISO date string
  updated_at = nil,      -- string: ISO date string
}

-- Context structure (for code comments)
M.Context = {
  file_path = nil,       -- string: Path to the file
  line_number = nil,     -- number: Line number in the file
  side = nil,            -- string: "left", "right" (for diff contexts)
  start_line = nil,      -- number: Start line for multi-line comments (optional)
  end_line = nil,        -- number: End line for multi-line comments (optional)
}

-- Standard API response structure
M.ApiResponse = {
  success = false,       -- boolean: Whether the operation succeeded
  data = nil,            -- any: The actual response data
  error = nil,           -- string: Error message if success is false
  message = nil,         -- string: Optional success message
}

-- Required methods that all backends must implement

-- Authentication
function M.auth()
  -- Returns: ApiResponse with authentication status
  error("auth() must be implemented by backend")
end

function M.get_auth_status()
  -- Returns: table with authentication status information
  error("get_auth_status() must be implemented by backend")
end

function M.logout()
  -- Returns: ApiResponse with logout status
  error("logout() must be implemented by backend")
end

-- Pull Request operations
function M.list_prs()
  -- Returns: ApiResponse with array of PullRequest structures
  error("list_prs() must be implemented by backend")
end

function M.get_pr(pr_id)
  -- Args: pr_id (string|number)
  -- Returns: ApiResponse with single PullRequest structure
  error("get_pr() must be implemented by backend")
end

-- Discussion operations
function M.fetch_discussions(pr_id)
  -- Args: pr_id (string|number)
  -- Returns: ApiResponse with array of Discussion structures
  error("fetch_discussions() must be implemented by backend")
end

function M.fetch_file_discussions(pr_id, file_path, line_number)
  -- Args: pr_id (string|number), file_path (string), line_number (number, optional)
  -- Returns: ApiResponse with array of Discussion structures for the specified file/line
  error("fetch_file_discussions() must be implemented by backend")
end

-- Optional methods that backends may implement

function M.create_discussion(pr_id, content, context)
  -- Args: pr_id (string|number), content (string), context (Context, optional)
  -- Returns: ApiResponse with created Discussion structure
  return { success = false, error = "create_discussion() not implemented" }
end

function M.reply_to_discussion(discussion_id, content)
  -- Args: discussion_id (string|number), content (string)
  -- Returns: ApiResponse with created Comment structure
  return { success = false, error = "reply_to_discussion() not implemented" }
end

function M.resolve_discussion(discussion_id)
  -- Args: discussion_id (string|number)
  -- Returns: ApiResponse with success status
  return { success = false, error = "resolve_discussion() not implemented" }
end

-- Helper functions for data transformation

-- Transform platform-specific data to standard PullRequest structure
function M.normalize_pull_request(platform_pr, platform)
  -- This should be implemented by each backend to transform their
  -- platform-specific PR data to the standard PullRequest structure
  error("normalize_pull_request() must be implemented by backend")
end

-- Transform platform-specific data to standard Discussion structure
function M.normalize_discussion(platform_discussion, platform)
  -- This should be implemented by each backend to transform their
  -- platform-specific discussion data to the standard Discussion structure
  error("normalize_discussion() must be implemented by backend")
end

return M