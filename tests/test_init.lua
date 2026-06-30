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

T["defaults: open_todo and open_review keys after setup({})"] = function()
  local gtd = require("gtd")
  gtd.setup({})
  MiniTest.expect.equality(gtd.config.keys.open_todo, "<leader>gt")
  MiniTest.expect.equality(gtd.config.keys.open_review, "<leader>gr")
end

T["functions callable: open_or_refresh_todo and open_or_refresh_review"] = function()
  local gtd = require("gtd")
  gtd.setup({})
  MiniTest.expect.equality(type(gtd.open_or_refresh_todo), "function")
  MiniTest.expect.equality(type(gtd.open_or_refresh_review), "function")
end

T["open_or_refresh_todo opens TODO.md in temp git repo"] = function()
  local gtd = require("gtd")
  gtd.setup({})

  -- Create temp git repo with TODO.md and REVIEW.md
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  vim.fn.system({ "git", "init", dir })
  local todo_path = dir .. "/TODO.md"
  local review_path = dir .. "/REVIEW.md"
  vim.fn.writefile({ "# TODO" }, todo_path)
  vim.fn.writefile({ "# REVIEW" }, review_path)

  local orig_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. dir)

  -- Open TODO.md
  gtd.open_or_refresh_todo()
  local buf_name = vim.fn.resolve(vim.api.nvim_buf_get_name(0))
  MiniTest.expect.equality(buf_name, vim.fn.resolve(todo_path))

  -- Cleanup todo buffer
  local todo_bufnr = vim.fn.bufnr(todo_path)
  if todo_bufnr ~= -1 then
    vim.api.nvim_buf_delete(todo_bufnr, { force = true })
  end

  -- Open REVIEW.md
  gtd.open_or_refresh_review()
  buf_name = vim.fn.resolve(vim.api.nvim_buf_get_name(0))
  MiniTest.expect.equality(buf_name, vim.fn.resolve(review_path))

  -- Cleanup review buffer
  local review_bufnr = vim.fn.bufnr(review_path)
  if review_bufnr ~= -1 then
    vim.api.nvim_buf_delete(review_bufnr, { force = true })
  end

  -- Restore cwd and remove temp dir
  vim.cmd("cd " .. orig_cwd)
  vim.fn.delete(dir, "rf")
end

T["open_or_refresh_todo notifies WARN when file missing"] = function()
  local gtd = require("gtd")
  gtd.setup({})

  -- Create temp git repo WITHOUT TODO.md or REVIEW.md
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  vim.fn.system({ "git", "init", dir })

  local orig_cwd = vim.fn.getcwd()
  vim.cmd("cd " .. dir)

  -- Stub vim.notify
  local orig_notify = vim.notify
  local captured = {}
  vim.notify = function(msg, level, ...)
    table.insert(captured, { msg = msg, level = level })
  end

  -- Test open_or_refresh_todo with missing file
  gtd.open_or_refresh_todo()

  MiniTest.expect.equality(#captured >= 1, true)
  MiniTest.expect.equality(captured[1].level, vim.log.levels.WARN)
  -- Must NOT have switched to a TODO.md buffer
  local buf_name = vim.api.nvim_buf_get_name(0)
  MiniTest.expect.equality(buf_name:match("TODO%.md") == nil, true)

  -- Reset captures
  captured = {}

  -- Test open_or_refresh_review with missing file
  gtd.open_or_refresh_review()

  MiniTest.expect.equality(#captured >= 1, true)
  MiniTest.expect.equality(captured[1].level, vim.log.levels.WARN)
  buf_name = vim.api.nvim_buf_get_name(0)
  MiniTest.expect.equality(buf_name:match("REVIEW%.md") == nil, true)

  -- Restore vim.notify, cwd, and temp dir
  vim.notify = orig_notify
  vim.cmd("cd " .. orig_cwd)
  vim.fn.delete(dir, "rf")
end

return T
