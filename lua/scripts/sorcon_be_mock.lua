local M = {}

-- Mock data
local mock_prs = {
  {
    pullRequestId = 1234,
    title = "Add new feature X",
    createdBy = { displayName = "John Doe" },
    creationDate = "2025-05-24T10:30:00Z",
    sourceRefName = "refs/heads/feature/X",
    targetRefName = "refs/heads/main",
    url = "https://dev.azure.com/mock/project/_git/repo/pullrequest/1234"
  },
  {
    pullRequestId = 1235,
    title = "Fix critical bug Y",
    createdBy = { displayName = "Jane Smith" },
    creationDate = "2025-05-24T11:00:00Z",
    sourceRefName = "refs/heads/bugfix/Y",
    targetRefName = "refs/heads/main",
    url = "https://dev.azure.com/mock/project/_git/repo/pullrequest/1235"
  }
}

local mock_changes = {
  path = "src/main.lua",
  new_id = "abc123",
  old_id = "def456"
}

local mock_file_content = [[
-- This is mock file content
function hello()
  print("Hello from mock!")
end

return {
  hello = hello
}
]]

function M.fetch_prs()
  return mock_prs
end

function M.fetch_first_change(_)
  return mock_changes
end

function M.get_latest_iteration(_)
  return 1
end

function M.fetch_file_content(_, _)
  return mock_file_content
end

return M