local T = MiniTest.new_set()

-- Helper: find a keymap by description in a list
local function find_by_desc(maps, desc)
  for _, m in ipairs(maps) do
    if m.desc == desc then
      return m
    end
  end
  return nil
end

-- Helper: find a keymap by lhs in a list
local function find_by_lhs(maps, lhs)
  for _, m in ipairs(maps) do
    if m.lhs == lhs then
      return m
    end
  end
  return nil
end

T["setup({}) does not error"] = function()
  local ok, err = pcall(function()
    require("gtd").setup({})
  end)
  MiniTest.expect.equality(ok, true, tostring(err))
end

T["setup registers pick_open_questions global keymap"] = function()
  require("gtd").setup({})
  local maps = vim.api.nvim_get_keymap("n")
  local m = find_by_desc(maps, "gtd: pick open questions")
  MiniTest.expect.no_equality(m, nil)
end

T["setup registers pick_chunks global keymap"] = function()
  require("gtd").setup({})
  local maps = vim.api.nvim_get_keymap("n")
  local m = find_by_desc(maps, "gtd: pick review chunks")
  MiniTest.expect.no_equality(m, nil)
end

T["keys override changes registered keymap lhs"] = function()
  require("gtd").setup({ keys = { pick_open_questions = "<leader>gz" } })
  -- Resolve <leader>gz to its actual lhs as Neovim stores it
  local resolved = vim.fn.keytrans(vim.api.nvim_replace_termcodes("<leader>gz", true, true, true))
  local maps = vim.api.nvim_get_keymap("n")
  local m = find_by_lhs(maps, resolved)
  MiniTest.expect.no_equality(m, nil)
end

T["config is accessible after setup"] = function()
  local gtd = require("gtd")
  gtd.setup({ custom = "value" })
  MiniTest.expect.equality(gtd.config.custom, "value")
  MiniTest.expect.equality(type(gtd.config.keys), "table")
end

T["lazy_keys returns a table with 2 entries"] = function()
  local gtd = require("gtd")
  gtd.setup({})
  local spec = gtd.lazy_keys()
  MiniTest.expect.equality(type(spec), "table")
  MiniTest.expect.equality(#spec, 2)
end

T["setup_buffer_keymaps attaches gd in REVIEW.md"] = function()
  local gtd = require("gtd")
  gtd.setup({})
  local buf = vim.api.nvim_create_buf(false, true)
  gtd.setup_buffer_keymaps(buf, "/some/repo/REVIEW.md")
  local maps = vim.api.nvim_buf_get_keymap(buf, "n")
  local gd = find_by_lhs(maps, "gd")
  MiniTest.expect.no_equality(gd, nil)
  vim.api.nvim_buf_delete(buf, { force = true })
end

T["setup_buffer_keymaps attaches toggle_done in REVIEW.md"] = function()
  local gtd = require("gtd")
  gtd.setup({})
  local buf = vim.api.nvim_create_buf(false, true)
  gtd.setup_buffer_keymaps(buf, "/some/repo/REVIEW.md")
  local maps = vim.api.nvim_buf_get_keymap(buf, "n")
  local gc = find_by_desc(maps, "gtd: toggle hunk done")
  MiniTest.expect.no_equality(gc, nil)
  vim.api.nvim_buf_delete(buf, { force = true })
end

T["setup_buffer_keymaps attaches <cr> toggle in REVIEW.md"] = function()
  local gtd = require("gtd")
  gtd.setup({})
  local buf = vim.api.nvim_create_buf(false, true)
  gtd.setup_buffer_keymaps(buf, "/some/repo/REVIEW.md")
  local maps = vim.api.nvim_buf_get_keymap(buf, "n")
  local cr = find_by_lhs(maps, "<CR>")
  MiniTest.expect.no_equality(cr, nil)
  vim.api.nvim_buf_delete(buf, { force = true })
end

return T
