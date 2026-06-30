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

--- Return the lines (header + body) of the single diff hunk (vs `base`) whose
--- new-side range contains `lnum`, or nil if none / git failed / empty diff.
--- @param path string   root-relative file path
--- @param base string   review base SHA
--- @param lnum number    1-based anchor line (new side)
--- @param root string|nil  optional repo root (defaults to M.get_root())
--- @return string[]|nil
function M.diff_hunk(path, base, lnum, root)
  root = root or M.get_root()
  if not root then
    return nil
  end

  local stdout, code = M.git_command({ "diff", base, "--", path }, { cwd = root })
  if code ~= 0 or stdout == "" then
    return nil
  end

  local lines = vim.split(stdout, "\n")
  local current_hunk = nil
  local current_start = nil
  local current_end = nil  -- exclusive: c + d

  for _, line in ipairs(lines) do
    local c_str, d_str = line:match("^@@ %-%d+,?%d* %+(%d+),?(%d*) @@")
    if c_str then
      -- Check if previous hunk matched
      if current_hunk and current_start <= lnum and lnum < current_end then
        return current_hunk
      end
      -- Start new hunk
      local c = tonumber(c_str)
      local d = (d_str ~= nil and d_str ~= "") and tonumber(d_str) or 1
      current_hunk = { line }
      current_start = c
      current_end = c + d
    elseif current_hunk then
      local first = line:sub(1, 1)
      if first == " " or first == "+" or first == "-" or first == "\\" then
        table.insert(current_hunk, line)
      else
        -- Non-body line outside a hunk header — check match and reset
        if current_start <= lnum and lnum < current_end then
          return current_hunk
        end
        current_hunk = nil
        current_start = nil
        current_end = nil
      end
    end
  end

  -- Check last hunk after EOF
  if current_hunk and current_start <= lnum and lnum < current_end then
    return current_hunk
  end

  return nil
end

return M
