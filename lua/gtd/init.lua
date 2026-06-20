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

--- Returns a statusline string (placeholder).
--- @return string
function M.statusline()
  return ""
end

--- Returns the number of open questions (placeholder).
--- @return number
function M.open_questions_count()
  return 0
end

return M
