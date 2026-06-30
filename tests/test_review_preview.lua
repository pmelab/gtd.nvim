local T = MiniTest.new_set()

local review = require("gtd.review")
local git = require("gtd.git")

-- ── helpers ────────────────────────────────────────────────────────────────

--- Stub a nested module function; returns a restore fn.
local function stub(mod, key, replacement)
  local original = mod[key]
  mod[key] = replacement
  return function()
    mod[key] = original
  end
end

--- Create a scratch REVIEW.md buffer with standard lines, open in a window.
--- Returns { buf, win }.
local function make_review_win(lines)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = 80,
    height = 10,
    row = 0,
    col = 0,
  })
  return buf, win
end

--- Find a float window anchored to cursor or win among current windows,
--- excluding windows in the provided set. Returns window id or nil.
--- NOTE: In headless Neovim, relative="cursor" is reported as relative="win",
--- so we match on any non-empty relative (i.e. any float) that is not a
--- pre-existing window.
local function find_new_float_win(existing_set)
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if not existing_set[w] then
      local cfg = vim.api.nvim_win_get_config(w)
      if cfg.relative ~= "" then
        return w
      end
    end
  end
  return nil
end

-- ── 1. Happy path: float opens, stays in REVIEW.md ────────────────────────

T["preview_hunk_under_cursor opens a cursor-relative float with diff content"] = function()
  local lines = {
    "# Review: a1b2c3d",
    "<!-- base: a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2 -->",
    "",
    "## chunk",
    "",
    "- [ ] ./lua/gtd/init.lua#12",
  }

  local buf, review_win = make_review_win(lines)
  vim.api.nvim_win_set_cursor(review_win, { 6, 0 })

  local fake_diff = { "@@ -1,1 +1,2 @@", " ctx", "+added" }

  local r1 = stub(git, "get_review_path", function() return "/fake/REVIEW.md" end)
  local r2 = stub(git, "get_base", function(_) return "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2" end)
  local r3 = stub(git, "diff_hunk", function(_, _, _) return fake_diff end)

  local wins_before = vim.api.nvim_list_wins()
  local wins_before_set = {}
  for _, w in ipairs(wins_before) do wins_before_set[w] = true end

  local ok, err = pcall(function()
    review.preview_hunk_under_cursor()
  end)

  -- find the new float window (the diff preview)
  local float_win = find_new_float_win(wins_before_set)
  local float_buf = float_win and vim.api.nvim_win_get_buf(float_win)
  local float_lines = float_buf and vim.api.nvim_buf_get_lines(float_buf, 0, -1, false)
  local float_ft = float_buf and vim.bo[float_buf].filetype
  local current_win_after = vim.api.nvim_get_current_win()

  -- cleanup: close ALL new windows opened since wins_before (handles bordered
  -- floats that create an extra window), then close review_win
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if not wins_before_set[w] and vim.api.nvim_win_is_valid(w) then
      pcall(vim.api.nvim_win_close, w, true)
    end
  end
  vim.api.nvim_win_close(review_win, true)
  vim.api.nvim_buf_delete(buf, { force = true })
  r1(); r2(); r3()

  assert(ok, "preview_hunk_under_cursor should not error: " .. tostring(err))

  -- all new windows closed, plus review_win: net change is -1 from wins_before
  MiniTest.expect.equality(#vim.api.nvim_list_wins(), #wins_before - 1) -- float(s) closed, review closed

  MiniTest.expect.no_equality(float_win, nil)
  MiniTest.expect.no_equality(float_lines, nil)
  MiniTest.expect.equality(float_lines, fake_diff)
  MiniTest.expect.equality(float_ft, "diff")
  MiniTest.expect.equality(current_win_after, review_win)
end

-- ── 2. Heading no-op + notify ──────────────────────────────────────────────

T["preview_hunk_under_cursor notifies 'no hunk' on heading line, no float"] = function()
  local buf, win = make_review_win({ "## just a heading" })
  vim.api.nvim_win_set_cursor(win, { 1, 0 })

  local notified = nil
  local r_notify = stub(vim, "notify", function(msg, _) notified = msg end)

  local wins_before = #vim.api.nvim_list_wins()

  local ok, err = pcall(function()
    review.preview_hunk_under_cursor()
  end)

  local wins_after = #vim.api.nvim_list_wins()

  -- cleanup
  vim.api.nvim_win_close(win, true)
  vim.api.nvim_buf_delete(buf, { force = true })
  r_notify()

  assert(ok, "preview_hunk_under_cursor should not error: " .. tostring(err))
  MiniTest.expect.no_equality(notified, nil)
  assert(
    notified:find("no hunk", 1, true),
    "expected 'no hunk' in notify message, got: " .. tostring(notified)
  )
  MiniTest.expect.equality(wins_after, wins_before)
end

-- ── 3. nil diff → notify + no float ───────────────────────────────────────

T["preview_hunk_under_cursor notifies 'no changes' when diff_hunk returns nil"] = function()
  local lines = {
    "# Review: a1b2c3d",
    "<!-- base: a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2 -->",
    "",
    "## chunk",
    "",
    "- [ ] ./lua/gtd/init.lua#12",
  }

  local buf, review_win = make_review_win(lines)
  vim.api.nvim_win_set_cursor(review_win, { 6, 0 })

  local r1 = stub(git, "get_review_path", function() return "/fake/REVIEW.md" end)
  local r2 = stub(git, "get_base", function(_) return "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2" end)
  local r3 = stub(git, "diff_hunk", function(_, _, _) return nil end)

  local notified = nil
  local r_notify = stub(vim, "notify", function(msg, _) notified = msg end)

  local wins_before = #vim.api.nvim_list_wins()

  local ok, err = pcall(function()
    review.preview_hunk_under_cursor()
  end)

  local wins_after = #vim.api.nvim_list_wins()

  -- cleanup
  vim.api.nvim_win_close(review_win, true)
  vim.api.nvim_buf_delete(buf, { force = true })
  r1(); r2(); r3(); r_notify()

  assert(ok, "preview_hunk_under_cursor should not error: " .. tostring(err))
  MiniTest.expect.no_equality(notified, nil)
  assert(
    notified:find("no changes", 1, true),
    "expected 'no changes' in notify message, got: " .. tostring(notified)
  )
  MiniTest.expect.equality(wins_after, wins_before)
end

return T
