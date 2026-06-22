local T = MiniTest.new_set()

T["setup loads without error"] = function()
  local ok, gtd = pcall(require, "gtd")
  MiniTest.expect.equality(ok, true)
  gtd.setup({})
end

T["statusline returns empty string"] = function()
  local gtd = require("gtd")
  gtd.setup({})
  MiniTest.expect.equality(gtd.statusline(), "")
end

T["open_questions_count returns 0"] = function()
  local gtd = require("gtd")
  gtd.setup({})
  MiniTest.expect.equality(gtd.open_questions_count(), 0)
end

T["setup merges opts over defaults"] = function()
  local gtd = require("gtd")
  gtd.setup({ custom = true })
  MiniTest.expect.equality(gtd.config.custom, true)
  MiniTest.expect.equality(type(gtd.config.keys), "table")
end

T["copy_location returns path:line for a named buffer"] = function()
  local gtd = require("gtd")
  gtd.setup({})
  -- Create a scratch buffer with a known absolute name
  local tmpfile = vim.fn.tempname() .. ".lua"
  local bufnr = vim.api.nvim_create_buf(false, false)
  vim.api.nvim_buf_set_name(bufnr, tmpfile)
  vim.api.nvim_set_current_buf(bufnr)
  -- Move cursor to line 1 (scratch buffer has no lines, so just check line 1)
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  local result = gtd.copy_location()
  local expected_path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":.")
  MiniTest.expect.equality(result, expected_path .. ":1")
  MiniTest.expect.equality(vim.fn.getreg("+"), result)
  -- Cleanup
  vim.api.nvim_buf_delete(bufnr, { force = true })
end

T["copy_location returns nil for a no-name buffer"] = function()
  local gtd = require("gtd")
  gtd.setup({})
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(bufnr)
  local result = gtd.copy_location()
  MiniTest.expect.equality(result, nil)
  vim.api.nvim_buf_delete(bufnr, { force = true })
end

return T
