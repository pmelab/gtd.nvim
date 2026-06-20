local M = {}

--- Run git with safety flags.
--- @param args string[] git arguments
--- @param opts table|nil optional: { cwd = string }
--- @return string stdout, number exit_code
function M.git_command(args, opts)
  opts = opts or {}
  local cmd = vim.list_extend(
    { "git", "-c", "core.hooksPath=", "-c", "gc.auto=0" },
    args
  )
  local result = vim.system(cmd, {
    text = true,
    cwd = opts.cwd or nil,
  }):wait()
  local stdout = result.stdout or ""
  -- trim trailing newline
  stdout = stdout:gsub("%s+$", "")
  return stdout, result.code
end

--- Return the git toplevel for path (or cwd), or nil if not in a repo.
--- @param path string|nil
--- @return string|nil
function M.get_root(path)
  local opts = {}
  if path then
    opts.cwd = path
  end
  local out, code = M.git_command({ "rev-parse", "--show-toplevel" }, opts)
  if code ~= 0 or out == "" then
    return nil
  end
  return out
end

--- Resolve TODO.md path relative to the git root.
--- @param root string|nil fallback to get_root()
--- @return string|nil
function M.get_todo_path(root)
  root = root or M.get_root()
  if not root then
    return nil
  end
  return root .. "/TODO.md"
end

--- Resolve REVIEW.md path relative to the git root.
--- @param root string|nil fallback to get_root()
--- @return string|nil
function M.get_review_path(root)
  root = root or M.get_root()
  if not root then
    return nil
  end
  return root .. "/REVIEW.md"
end

--- Extract the base SHA from <!-- base: <hash> --> in REVIEW.md content.
--- @param lines_or_path string|string[] file path or table of lines
--- @return string|nil hash or nil
function M.get_base(lines_or_path)
  local lines
  if type(lines_or_path) == "string" then
    -- treat as file path
    local f = io.open(lines_or_path, "r")
    if not f then
      return nil
    end
    local content = f:read("*a")
    f:close()
    lines = vim.split(content, "\n")
  else
    lines = lines_or_path
  end

  for _, line in ipairs(lines) do
    local hash = line:match("^%s*<!%-%-%s*base:%s*([0-9a-f]+)%s*%-%->%s*$")
    if hash then
      return hash
    end
  end
  return nil
end

return M
