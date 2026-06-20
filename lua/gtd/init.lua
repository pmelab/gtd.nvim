local M = {}

local defaults = {
  keys = {},
}

M.config = {}

--- Deep-merge src into dst (in-place).
local function deep_merge(dst, src)
  for k, v in pairs(src) do
    if type(v) == "table" and type(dst[k]) == "table" then
      deep_merge(dst[k], v)
    else
      dst[k] = v
    end
  end
end

--- Setup the plugin.
--- @param opts table|nil User options merged over defaults.
function M.setup(opts)
  M.config = vim.deepcopy(defaults)
  if opts then
    deep_merge(M.config, opts)
  end
end

--- Returns a statusline string: "? N" for N>0, "" for N==0 or no TODO.md.
--- Reads the cache — cheap to call on every redraw.
--- @return string
function M.statusline()
  local count = M.open_questions_count()
  if count == 0 then
    return ""
  end
  return "? " .. count
end

--- Returns the cached count of unanswered open questions (recomputes if not cached).
--- @return integer
function M.open_questions_count()
  local todo = require("gtd.todo")
  return todo.count_open_questions()
end

return M
