local T = MiniTest.new_set()

local review = require("gtd.review")
local git = require("gtd.git")

local FIXTURES = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h") .. "/fixtures"

-- ── helpers ────────────────────────────────────────────────────────────────

--- Stub a nested module function; returns a restore fn.
local function stub(mod, key, replacement)
  local original = mod[key]
  mod[key] = replacement
  return function()
    mod[key] = original
  end
end

--- Minimal fake git module for open_file_diff tests (avoids real git calls).
local function with_fake_root(root_val, fn)
  local restore = stub(git, "get_root", function()
    return root_val
  end)
  local ok, err = pcall(fn)
  restore()
  if not ok then
    error(err, 2)
  end
end

-- ── parse_hunk_line → open_file_diff target computation ────────────────────

T["parse_hunk_line feeds correct path and lnum to open_file_diff"] = function()
  local hunk = review.parse_hunk_line("- [ ] ./lua/gtd/init.lua#42")
  MiniTest.expect.no_equality(hunk, nil)
  MiniTest.expect.equality(hunk.path, "lua/gtd/init.lua")
  MiniTest.expect.equality(hunk.lnum, 42)
end

-- ── open_file_diff: file open + cursor ─────────────────────────────────────

T["open_file_diff opens the file relative to git root"] = function()
  -- Use a real file that exists: the fixture REVIEW.md (known path).
  local root = FIXTURES
  local opened = nil
  local orig_cmd = vim.cmd

  -- We intercept vim.cmd to capture the edit command without side effects.
  vim.cmd = function(cmd_str)
    opened = cmd_str
  end

  -- Stub nvim APIs so we don't crash without a real buffer/window.
  local orig_buf_line_count = vim.api.nvim_buf_line_count
  local orig_win_set_cursor = vim.api.nvim_win_set_cursor
  vim.api.nvim_buf_line_count = function(_) return 100 end
  vim.api.nvim_win_set_cursor = function(_, _) end

  with_fake_root(root, function()
    review.open_file_diff({ path = "REVIEW.md", lnum = 3, done = false }, "deadbeef")
  end)

  vim.cmd = orig_cmd
  vim.api.nvim_buf_line_count = orig_buf_line_count
  vim.api.nvim_win_set_cursor = orig_win_set_cursor

  -- Should have issued an edit command containing the expected path.
  MiniTest.expect.no_equality(opened, nil)
  assert(opened:find("REVIEW.md", 1, true), "edit command should reference REVIEW.md, got: " .. tostring(opened))
  assert(opened:find(root, 1, true), "edit command should be rooted at fixture dir, got: " .. tostring(opened))
end

T["open_file_diff positions cursor at hunk lnum"] = function()
  local root = FIXTURES
  local cursor_pos = nil

  local orig_cmd = vim.cmd
  vim.cmd = function(_) end

  local orig_buf_line_count = vim.api.nvim_buf_line_count
  local orig_win_set_cursor = vim.api.nvim_win_set_cursor
  vim.api.nvim_buf_line_count = function(_) return 100 end
  vim.api.nvim_win_set_cursor = function(_, pos) cursor_pos = pos end

  with_fake_root(root, function()
    review.open_file_diff({ path = "REVIEW.md", lnum = 7, done = false }, "deadbeef")
  end)

  vim.cmd = orig_cmd
  vim.api.nvim_buf_line_count = orig_buf_line_count
  vim.api.nvim_win_set_cursor = orig_win_set_cursor

  MiniTest.expect.no_equality(cursor_pos, nil)
  MiniTest.expect.equality(cursor_pos[1], 7)
end

T["open_file_diff clamps out-of-range lnum to line_count"] = function()
  local root = FIXTURES
  local cursor_pos = nil

  local orig_cmd = vim.cmd
  vim.cmd = function(_) end

  local orig_buf_line_count = vim.api.nvim_buf_line_count
  local orig_win_set_cursor = vim.api.nvim_win_set_cursor
  vim.api.nvim_buf_line_count = function(_) return 5 end
  vim.api.nvim_win_set_cursor = function(_, pos) cursor_pos = pos end

  with_fake_root(root, function()
    review.open_file_diff({ path = "REVIEW.md", lnum = 999, done = false }, "deadbeef")
  end)

  vim.cmd = orig_cmd
  vim.api.nvim_buf_line_count = orig_buf_line_count
  vim.api.nvim_win_set_cursor = orig_win_set_cursor

  MiniTest.expect.no_equality(cursor_pos, nil)
  MiniTest.expect.equality(cursor_pos[1], 5)
end

-- ── open_file_diff: gitsigns integration ───────────────────────────────────

T["open_file_diff calls gitsigns.change_base with the supplied base SHA"] = function()
  local root = FIXTURES
  local gs_base_called_with = nil

  -- Inject a fake gitsigns into package.loaded so pcall(require,"gitsigns") succeeds.
  package.loaded["gitsigns"] = {
    change_base = function(base, global)
      gs_base_called_with = { base = base, global = global }
    end,
  }

  local orig_cmd = vim.cmd
  vim.cmd = function(_) end
  local orig_buf_line_count = vim.api.nvim_buf_line_count
  local orig_win_set_cursor = vim.api.nvim_win_set_cursor
  vim.api.nvim_buf_line_count = function(_) return 100 end
  vim.api.nvim_win_set_cursor = function(_, _) end

  with_fake_root(root, function()
    review.open_file_diff({ path = "REVIEW.md", lnum = 1, done = false }, "abc123")
  end)

  vim.cmd = orig_cmd
  vim.api.nvim_buf_line_count = orig_buf_line_count
  vim.api.nvim_win_set_cursor = orig_win_set_cursor
  package.loaded["gitsigns"] = nil

  MiniTest.expect.no_equality(gs_base_called_with, nil)
  MiniTest.expect.equality(gs_base_called_with.base, "abc123")
  MiniTest.expect.equality(gs_base_called_with.global, true)
end

T["open_file_diff does not crash when gitsigns is absent"] = function()
  local root = FIXTURES
  package.loaded["gitsigns"] = nil

  local orig_cmd = vim.cmd
  vim.cmd = function(_) end
  local orig_buf_line_count = vim.api.nvim_buf_line_count
  local orig_win_set_cursor = vim.api.nvim_win_set_cursor
  vim.api.nvim_buf_line_count = function(_) return 100 end
  vim.api.nvim_win_set_cursor = function(_, _) end

  local ok, err = pcall(function()
    with_fake_root(root, function()
      review.open_file_diff({ path = "REVIEW.md", lnum = 1, done = false }, "abc123")
    end)
  end)

  vim.cmd = orig_cmd
  vim.api.nvim_buf_line_count = orig_buf_line_count
  vim.api.nvim_win_set_cursor = orig_win_set_cursor

  assert(ok, "open_file_diff should not crash without gitsigns: " .. tostring(err))
end

-- ── jump_to_hunk_under_cursor: base resolution wiring ──────────────────────

T["jump_to_hunk_under_cursor resolves base from fixture REVIEW.md"] = function()
  -- Verify that get_base reads the correct SHA from the fixture file.
  local base = git.get_base(FIXTURES .. "/REVIEW.md")
  MiniTest.expect.equality(base, "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2")
end

T["jump_to_hunk_under_cursor wires hunk line → open_file_diff"] = function()
  -- Simulate a REVIEW.md buffer with cursor on a hunk line.
  local buf = vim.api.nvim_create_buf(false, true)
  local lines = {
    "# Review: a1b2c3d",
    "",
    "<!-- base: a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2 -->",
    "",
    "## chunk",
    "",
    "- [ ] ./lua/gtd/init.lua#12",
  }
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = 80,
    height = 10,
    row = 0,
    col = 0,
  })
  vim.api.nvim_win_set_cursor(win, { 7, 0 })

  -- Capture what open_file_diff receives.
  local captured = nil
  local orig_open = review.open_file_diff
  review.open_file_diff = function(hunk, base)
    captured = { hunk = hunk, base = base }
  end

  -- Stub get_review_path + get_base so they point at our fixture.
  local orig_get_review_path = git.get_review_path
  local orig_get_base = git.get_base
  git.get_review_path = function() return FIXTURES .. "/REVIEW.md" end
  git.get_base = function(_) return "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2" end

  review.jump_to_hunk_under_cursor()

  -- restore
  review.open_file_diff = orig_open
  git.get_review_path = orig_get_review_path
  git.get_base = orig_get_base
  vim.api.nvim_win_close(win, true)
  vim.api.nvim_buf_delete(buf, { force = true })

  MiniTest.expect.no_equality(captured, nil)
  MiniTest.expect.equality(captured.hunk.path, "lua/gtd/init.lua")
  MiniTest.expect.equality(captured.hunk.lnum, 12)
  MiniTest.expect.equality(captured.base, "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2")
end

T["jump_to_hunk_under_cursor warns when cursor is not on a hunk line"] = function()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "## just a heading" })

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor", width = 80, height = 5, row = 0, col = 0,
  })
  vim.api.nvim_win_set_cursor(win, { 1, 0 })

  local notified = nil
  local orig_notify = vim.notify
  vim.notify = function(msg, _) notified = msg end

  review.jump_to_hunk_under_cursor()

  vim.notify = orig_notify
  vim.api.nvim_win_close(win, true)
  vim.api.nvim_buf_delete(buf, { force = true })

  MiniTest.expect.no_equality(notified, nil)
  assert(notified:find("no hunk", 1, true), "expected 'no hunk' warning, got: " .. tostring(notified))
end

return T
