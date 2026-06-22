local M = {}

local defaults = {
  keys = {
    pick_open_questions = "<leader>gq",
    pick_chunks = "<leader>gp",
    jump_to_hunk = "gd",
    toggle_done = "<leader>gc",
    toggle_done_cr = "<cr>",
    copy_location = "<leader>gy",
  },
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

--- Register buffer-local keymaps for TODO.md or REVIEW.md.
--- @param bufnr integer
--- @param fname string  absolute file path
function M.setup_buffer_keymaps(bufnr, fname)
  local keys = M.config.keys
  if fname:match(".*/REVIEW%.md$") then
    local review = require("gtd.review")
    vim.keymap.set("n", keys.jump_to_hunk, function()
      review.jump_to_hunk_under_cursor()
    end, { buffer = bufnr, desc = "gtd: jump to hunk under cursor" })
    vim.keymap.set("n", keys.toggle_done, function()
      review.toggle_done()
    end, { buffer = bufnr, desc = "gtd: toggle hunk done" })
    if keys.toggle_done_cr then
      vim.keymap.set("n", keys.toggle_done_cr, function()
        review.toggle_done()
      end, { buffer = bufnr, desc = "gtd: toggle hunk done (<cr>)" })
    end
  end
  if fname:match(".*/TODO%.md$") then
    local todo = require("gtd.todo")
    todo.publish_diagnostics(bufnr)
  end
end

--- Register autocmds for refresh and buffer-local keymaps.
function M.setup_autocmds()
  local augroup = vim.api.nvim_create_augroup("GtdPlugin", { clear = true })

  -- Attach buffer-local keymaps + diagnostics on BufEnter
  vim.api.nvim_create_autocmd("BufEnter", {
    group = augroup,
    pattern = { "*/TODO.md", "*/REVIEW.md" },
    callback = function(ev)
      M.setup_buffer_keymaps(ev.buf, ev.file)
    end,
    desc = "gtd: attach buffer keymaps",
  })

  -- Refresh count + diagnostics when TODO.md is saved
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = augroup,
    pattern = "*/TODO.md",
    callback = function()
      local todo = require("gtd.todo")
      todo.refresh_count()
    end,
    desc = "gtd: refresh count on TODO.md write",
  })

  -- Refresh count when Neovim regains focus
  vim.api.nvim_create_autocmd("FocusGained", {
    group = augroup,
    callback = function()
      local todo = require("gtd.todo")
      todo.refresh_count()
    end,
    desc = "gtd: refresh count on focus",
  })

  -- Low-frequency timer fallback (5 minutes = 300000 ms)
  local timer = vim.uv and vim.uv.new_timer() or vim.loop.new_timer()
  if timer then
    timer:start(300000, 300000, vim.schedule_wrap(function()
      local todo = require("gtd.todo")
      todo.refresh_count()
    end))
  end
end

--- Copy current buffer path:line to the system clipboard.
--- Returns the copied string, or nil if the buffer has no file name.
function M.copy_location()
  local name = vim.api.nvim_buf_get_name(0)
  if name == "" then
    vim.notify("gtd: no file — nothing copied", vim.log.levels.WARN)
    return nil
  end
  local path = vim.fn.fnamemodify(name, ":.")
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local text = path .. ":" .. line
  vim.fn.setreg("+", text)
  vim.fn.setreg('"', text)
  vim.notify("gtd: copied " .. text)
  return text
end

--- Register optional icon/which-key integration.
function M.register_icons()
  -- mini.icons: register a custom icon for gtd group
  pcall(function()
    local MiniIcons = require("mini.icons")
    if MiniIcons.mock_icons then
      return
    end
    -- Register icons if the API supports it (gracefully no-op otherwise)
    if MiniIcons.add then
      MiniIcons.add("filetype", "gtd", { glyph = "?", hl = "MiniIconsYellow" })
    end
  end)

  -- which-key: register <leader>g group label
  pcall(function()
    local wk = require("which-key")
    if wk.add then
      wk.add({ { "<leader>g", group = "gtd" } })
    elseif wk.register then
      wk.register({ ["<leader>g"] = { name = "+gtd" } })
    end
  end)
end

--- Setup the plugin.
--- @param opts table|nil User options merged over defaults.
function M.setup(opts)
  M.config = vim.deepcopy(defaults)
  if opts then
    deep_merge(M.config, opts)
  end

  local keys = M.config.keys

  -- Global keymaps
  vim.keymap.set("n", keys.pick_open_questions, function()
    require("gtd.todo").pick_open_questions()
  end, { desc = "gtd: pick open questions" })

  vim.keymap.set("n", keys.pick_chunks, function()
    require("gtd.review").pick_chunks()
  end, { desc = "gtd: pick review chunks" })

  vim.keymap.set("n", keys.copy_location, function()
    M.copy_location()
  end, { desc = "gtd: copy file:line to clipboard" })

  -- Autocmds
  M.setup_autocmds()

  -- Optional integrations
  M.register_icons()

  -- Initial count refresh
  vim.schedule(function()
    local ok, todo = pcall(require, "gtd.todo")
    if ok then
      todo.refresh_count()
    end
  end)
end

--- Returns a lazy.nvim `keys` spec for global pickers.
--- @return table[]
function M.lazy_keys()
  local keys = vim.tbl_deep_extend("force", defaults.keys, M.config.keys or {})
  return {
    { keys.pick_open_questions, function() require("gtd.todo").pick_open_questions() end, desc = "gtd: pick open questions" },
    { keys.pick_chunks, function() require("gtd.review").pick_chunks() end, desc = "gtd: pick review chunks" },
    { keys.copy_location, function() require("gtd").copy_location() end, desc = "gtd: copy file:line to clipboard" },
  }
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
