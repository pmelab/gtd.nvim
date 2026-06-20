local M = {}

-- Cache: git_root -> count
local _count_cache = {}

-- Diagnostic namespace
local _ns = nil
local function ns()
  if not _ns then
    _ns = vim.api.nvim_create_namespace("gtd_open_questions")
  end
  return _ns
end

--- Parse open questions from lines of TODO.md.
--- Returns items only from the `## Open Questions` section (stops at next `## `).
--- @param lines string[]
--- @return { title: string, line: integer, answered: boolean, recommendation: string|nil }[]
function M.parse_open_questions(lines)
  local items = {}
  local in_section = false
  local current = nil

  for i, line in ipairs(lines) do
    if line:match("^## ") then
      -- Save any in-progress item
      if current then
        table.insert(items, current)
        current = nil
      end
      if line:match("^## Open Questions") then
        in_section = true
      else
        in_section = false
      end
    elseif in_section and line:match("^### ") then
      if current then
        table.insert(items, current)
      end
      current = {
        title = line:sub(5),
        line = i,
        answered = true, -- default; flipped below if placeholder found
        recommendation = nil,
      }
    elseif current then
      -- Check for unanswered placeholder
      if line:match("<!%-%-%s*user answers here%s*%-%->") then
        current.answered = false
      end
      -- Capture first recommendation
      if not current.recommendation then
        local rec = line:match("%*%*Recommendation:%*%*%s*(.+)")
        if rec then
          -- truncate to 60 chars
          if #rec > 60 then
            rec = rec:sub(1, 57) .. "..."
          end
          current.recommendation = rec
        end
      end
    end
  end

  if current then
    table.insert(items, current)
  end

  return items
end

--- Open a picker over unanswered open questions and jump to the selected one.
function M.pick_open_questions()
  local git = require("gtd.git")
  local todo_path = git.get_todo_path()
  if not todo_path then
    vim.notify("gtd: no TODO.md found (not in a git repo)", vim.log.levels.WARN)
    return
  end

  -- Read the file
  local f = io.open(todo_path, "r")
  if not f then
    vim.notify("gtd: cannot open " .. todo_path, vim.log.levels.WARN)
    return
  end
  local content = f:read("*a")
  f:close()

  local lines = vim.split(content, "\n")
  local questions = M.parse_open_questions(lines)

  -- Filter to unanswered only
  local unanswered = vim.tbl_filter(function(q)
    return not q.answered
  end, questions)

  if #unanswered == 0 then
    vim.notify("gtd: no open questions", vim.log.levels.INFO)
    return
  end

  vim.ui.select(unanswered, {
    prompt = "Open questions",
    format_item = function(q)
      local label = q.title
      if q.recommendation then
        label = label .. "  [" .. q.recommendation .. "]"
      end
      return label
    end,
  }, function(choice)
    if not choice then
      return
    end
    -- Open TODO.md buffer if needed and jump to line
    local buf = vim.fn.bufnr(todo_path, true)
    vim.fn.bufload(buf)
    local win = vim.fn.bufwinid(buf)
    if win == -1 then
      vim.cmd("edit " .. vim.fn.fnameescape(todo_path))
      win = vim.api.nvim_get_current_win()
    else
      vim.api.nvim_set_current_win(win)
    end
    vim.api.nvim_win_set_cursor(win, { choice.line, 0 })
  end)
end

--- Count unanswered open questions in a TODO.md file.
--- Only counts `<!-- user answers here -->` within `## Open Questions` section.
--- Result is cached by git root.
--- @param root string|nil git root (defaults to current repo root)
--- @return integer
function M.count_open_questions(root)
  local git = require("gtd.git")
  root = root or git.get_root()
  if not root then
    _count_cache[root or ""] = 0
    return 0
  end

  local todo_path = git.get_todo_path(root)
  if not todo_path then
    _count_cache[root] = 0
    return 0
  end

  local f = io.open(todo_path, "r")
  if not f then
    _count_cache[root] = 0
    return 0
  end
  local content = f:read("*a")
  f:close()

  local lines = vim.split(content, "\n")
  local questions = M.parse_open_questions(lines)
  local count = 0
  for _, q in ipairs(questions) do
    if not q.answered then
      count = count + 1
    end
  end

  _count_cache[root] = count
  return count
end

--- Recompute and cache the count, then refresh diagnostics for any open TODO.md buffers.
--- Safe to call from autocmds/timers.
--- @param root string|nil git root (defaults to current repo root)
function M.refresh_count(root)
  local git = require("gtd.git")
  root = root or git.get_root()
  if not root then
    return
  end

  M.count_open_questions(root)

  -- Refresh diagnostics for any loaded TODO.md buffer
  local todo_path = git.get_todo_path(root)
  if todo_path then
    local bufnr = vim.fn.bufnr(todo_path)
    if bufnr ~= -1 and vim.api.nvim_buf_is_loaded(bufnr) then
      M.publish_diagnostics(bufnr)
    end
  end
end

--- Publish WARN diagnostics for unanswered questions onto a TODO.md buffer.
--- One diagnostic per unanswered question, on its `### ` heading line.
--- @param bufnr integer buffer number of the TODO.md buffer
function M.publish_diagnostics(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local questions = M.parse_open_questions(lines)

  local diags = {}
  for _, q in ipairs(questions) do
    if not q.answered then
      table.insert(diags, {
        bufnr = bufnr,
        lnum = q.line - 1, -- 0-indexed
        col = 0,
        severity = vim.diagnostic.severity.WARN,
        message = "Unanswered question: " .. q.title,
        source = "gtd",
      })
    end
  end

  vim.diagnostic.set(ns(), bufnr, diags, {})
end

return M
