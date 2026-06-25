local M = {}

local git = require("gtd.git")

--- Parse a single checkbox hunk line.
--- @param line string
--- @return { path: string, lnum: number, done: boolean }|nil
function M.parse_hunk_line(line)
  -- matches: - [ ] ./path/to/file#42  or  - [x] ./path/to/file#42
  local checked, raw_path, lnum_str = line:match("^%- %[([x ])%] (%./.-)#(%d+)%s*$")
  if not checked then
    return nil
  end
  -- strip leading ./
  local path = raw_path:gsub("^%./", "")
  return {
    path = path,
    lnum = tonumber(lnum_str),
    done = checked == "x",
  }
end

--- Parse REVIEW.md lines into a list of chunks.
--- @param lines string[]
--- @return { title: string, line: number, hunks: table[] }[]
function M.parse_chunks(lines)
  local chunks = {}
  local current = nil

  for i, line in ipairs(lines) do
    local title = line:match("^## (.+)$")
    if title then
      -- start a new chunk
      current = { title = title, line = i, hunks = {} }
      table.insert(chunks, current)
    elseif current then
      local hunk = M.parse_hunk_line(line)
      if hunk then
        hunk.line = i
        table.insert(current.hunks, hunk)
      end
    end
  end

  return chunks
end

--- Open a vim.ui.select over all chunks in REVIEW.md.
--- On selection, open REVIEW.md and jump to the chunk heading line.
function M.pick_chunks()
  local path = git.get_review_path()
  if not path then
    vim.notify("gtd: not in a git repo", vim.log.levels.ERROR)
    return
  end

  local f = io.open(path, "r")
  if not f then
    vim.notify("gtd: REVIEW.md not found at " .. path, vim.log.levels.WARN)
    return
  end
  local content = f:read("*a")
  f:close()

  local lines = vim.split(content, "\n")
  local chunks = M.parse_chunks(lines)

  if #chunks == 0 then
    vim.notify("gtd: no chunks found in REVIEW.md", vim.log.levels.INFO)
    return
  end

  local items = {}
  for _, chunk in ipairs(chunks) do
    table.insert(items, chunk)
  end

  vim.ui.select(items, {
    prompt = "Review chunks",
    format_item = function(chunk)
      return chunk.title .. " (" .. #chunk.hunks .. " hunks)"
    end,
  }, function(choice)
    if not choice then
      return
    end
    vim.cmd("edit " .. vim.fn.fnameescape(path))
    vim.api.nvim_win_set_cursor(0, { choice.line, 0 })
  end)
end

--- Open a file at the hunk's line, setting gitsigns base to `base`.
--- @param hunk { path: string, lnum: number, done: boolean }
--- @param base string  review base SHA
function M.open_file_diff(hunk, base)
  local root = git.get_root()
  if not root then
    vim.notify("gtd: not in a git repo", vim.log.levels.ERROR)
    return
  end

  -- Set gitsigns base before opening the file so it's in place when gitsigns attaches.
  local ok, gs = pcall(require, "gitsigns")
  if ok and gs.change_base then
    gs.change_base(base, true)
  end

  local abs_path = root .. "/" .. hunk.path
  vim.cmd("edit " .. vim.fn.fnameescape(abs_path))

  -- position cursor (best-effort; ignore out-of-range)
  local line_count = vim.api.nvim_buf_line_count(0)
  local lnum = math.min(hunk.lnum, line_count)
  if lnum >= 1 then
    pcall(vim.api.nvim_win_set_cursor, 0, { lnum, 0 })
  end
end

--- Toggle the checkbox on a hunk line in bufnr at lnum (1-based), then write.
--- No-op with a gentle notify if the line is not a hunk line.
--- @param bufnr? number  buffer handle (default: current buffer)
--- @param lnum?  number  1-based line number (default: cursor line)
function M.toggle_done(bufnr, lnum)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  lnum = lnum or vim.api.nvim_win_get_cursor(0)[1]

  local line = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1]
  if not line then
    vim.notify("gtd: line out of range", vim.log.levels.WARN)
    return
  end

  local hunk = M.parse_hunk_line(line)
  if not hunk then
    vim.notify("gtd: no hunk on current line", vim.log.levels.WARN)
    return
  end

  local toggled
  if hunk.done then
    toggled = line:gsub("%- %[x%]", "- [ ]", 1)
  else
    toggled = line:gsub("%- %[ %]", "- [x]", 1)
  end

  vim.api.nvim_buf_set_lines(bufnr, lnum - 1, lnum, false, { toggled })
  vim.api.nvim_buf_call(bufnr, function()
    vim.cmd("write")
  end)
end

--- From an arbitrary source buffer, locate all hunk lines in REVIEW.md whose
--- path matches the current file's root-relative path and check them off
--- (write-through). Best-effort: silently returns if the path cannot be
--- determined or no matching hunks are found.
function M.toggle_done_for_current_file()
  local root = git.get_root()
  if not root then
    vim.notify("gtd: not in a git repo", vim.log.levels.ERROR)
    return
  end

  local abs_path = vim.api.nvim_buf_get_name(0)
  if abs_path == "" then
    vim.notify("gtd: current buffer has no file name", vim.log.levels.WARN)
    return
  end

  -- Resolve symlinks so paths can be compared reliably (macOS /var → /private/var).
  local uv = vim.uv or vim.loop
  local real_abs = uv.fs_realpath(abs_path) or abs_path
  local real_root = uv.fs_realpath(root) or root

  -- Derive root-relative path (strip root + separator).
  local rel_path = real_abs:gsub("^" .. vim.pesc(real_root) .. "/", "")
  if rel_path == real_abs then
    -- File is not under the git root — nothing to match.
    return
  end

  local review_path = git.get_review_path()
  if not review_path then
    vim.notify("gtd: REVIEW.md not found", vim.log.levels.WARN)
    return
  end

  -- Load (or reuse) the REVIEW.md buffer.
  local review_buf = vim.fn.bufadd(review_path)
  vim.fn.bufload(review_buf)

  local lines = vim.api.nvim_buf_get_lines(review_buf, 0, -1, false)
  local changed = false

  for i, line in ipairs(lines) do
    local hunk = M.parse_hunk_line(line)
    if hunk and hunk.path == rel_path and not hunk.done then
      local toggled = line:gsub("%- %[ %]", "- [x]", 1)
      vim.api.nvim_buf_set_lines(review_buf, i - 1, i, false, { toggled })
      changed = true
    end
  end

  if changed then
    vim.api.nvim_buf_call(review_buf, function()
      vim.cmd("write")
    end)
  end
end

--- From a REVIEW.md buffer, parse the hunk under the cursor and open it.
function M.jump_to_hunk_under_cursor()
  local buf = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1]
  local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1]

  local hunk = M.parse_hunk_line(line)
  if not hunk then
    vim.notify("gtd: no hunk on current line", vim.log.levels.WARN)
    return
  end

  local review_path = git.get_review_path()
  local base = review_path and git.get_base(review_path)
  if not base then
    vim.notify("gtd: could not resolve review base", vim.log.levels.ERROR)
    return
  end

  M.open_file_diff(hunk, base)
end

return M
