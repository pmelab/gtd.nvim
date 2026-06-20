local T = MiniTest.new_set()

local review = require("gtd.review")
local git = require("gtd.git")

local FIXTURES = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h") .. "/fixtures"

-- ── helpers ────────────────────────────────────────────────────────────────

local function stub(mod, key, replacement)
  local original = mod[key]
  mod[key] = replacement
  return function()
    mod[key] = original
  end
end

--- Create a scratch buffer pre-loaded with lines; returns bufnr.
local function make_buf(lines)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  return buf
end

--- Make a real temp file with lines, load it into a buffer, return bufnr + path.
local function make_file_buf(lines)
  local path = vim.fn.tempname() .. ".md"
  local f = io.open(path, "w")
  for _, l in ipairs(lines) do
    f:write(l .. "\n")
  end
  f:close()
  local buf = vim.fn.bufadd(path)
  vim.fn.bufload(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  return buf, path
end

--- Read all lines from a file on disk.
local function read_file(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local content = f:read("*a")
  f:close()
  local lines = vim.split(content, "\n")
  -- strip trailing empty line from trailing newline
  if lines[#lines] == "" then table.remove(lines) end
  return lines
end

-- ── toggle_done: basic flip ─────────────────────────────────────────────────

T["toggle_done flips unchecked to checked"] = function()
  local lines = {
    "## chunk",
    "- [ ] ./lua/gtd/init.lua#10",
  }
  local buf, path = make_file_buf(lines)

  review.toggle_done(buf, 2)

  local result = vim.api.nvim_buf_get_lines(buf, 1, 2, false)[1]
  MiniTest.expect.equality(result, "- [x] ./lua/gtd/init.lua#10")

  -- also written to disk
  local disk = read_file(path)
  MiniTest.expect.equality(disk[2], "- [x] ./lua/gtd/init.lua#10")

  vim.api.nvim_buf_delete(buf, { force = true })
  os.remove(path)
end

T["toggle_done flips checked to unchecked"] = function()
  local lines = {
    "## chunk",
    "- [x] ./lua/gtd/init.lua#10",
  }
  local buf, path = make_file_buf(lines)

  review.toggle_done(buf, 2)

  local result = vim.api.nvim_buf_get_lines(buf, 1, 2, false)[1]
  MiniTest.expect.equality(result, "- [ ] ./lua/gtd/init.lua#10")

  local disk = read_file(path)
  MiniTest.expect.equality(disk[2], "- [ ] ./lua/gtd/init.lua#10")

  vim.api.nvim_buf_delete(buf, { force = true })
  os.remove(path)
end

-- ── toggle_done: preserves rest of line ────────────────────────────────────

T["toggle_done preserves path and line number"] = function()
  local lines = { "- [ ] ./some/deep/path.lua#999" }
  local buf, path = make_file_buf(lines)

  review.toggle_done(buf, 1)

  local result = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
  MiniTest.expect.equality(result, "- [x] ./some/deep/path.lua#999")

  vim.api.nvim_buf_delete(buf, { force = true })
  os.remove(path)
end

-- ── toggle_done: double toggle is idempotent per pair ──────────────────────

T["toggle_done round-trips back to original state"] = function()
  local lines = { "- [ ] ./lua/gtd/init.lua#1" }
  local buf, path = make_file_buf(lines)

  review.toggle_done(buf, 1)
  review.toggle_done(buf, 1)

  local result = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
  MiniTest.expect.equality(result, "- [ ] ./lua/gtd/init.lua#1")

  vim.api.nvim_buf_delete(buf, { force = true })
  os.remove(path)
end

-- ── toggle_done: no-op on non-hunk lines ───────────────────────────────────

T["toggle_done is a no-op on a heading line"] = function()
  local lines = { "## just a heading" }
  local buf = make_buf(lines)

  local notified = nil
  local orig_notify = vim.notify
  vim.notify = function(msg, _) notified = msg end

  review.toggle_done(buf, 1)

  vim.notify = orig_notify
  vim.api.nvim_buf_delete(buf, { force = true })

  MiniTest.expect.no_equality(notified, nil)
  assert(notified:find("no hunk", 1, true), "expected 'no hunk' warn, got: " .. tostring(notified))
end

T["toggle_done is a no-op on a blank line"] = function()
  local lines = { "" }
  local buf = make_buf(lines)

  local notified = nil
  local orig_notify = vim.notify
  vim.notify = function(msg, _) notified = msg end

  review.toggle_done(buf, 1)

  vim.notify = orig_notify
  vim.api.nvim_buf_delete(buf, { force = true })

  MiniTest.expect.no_equality(notified, nil)
end

-- ── toggle_done_for_current_file ───────────────────────────────────────────

T["toggle_done_for_current_file checks off matching hunks in REVIEW.md"] = function()
  -- Write a temp REVIEW.md with one unchecked hunk for a known relative path.
  local rel = "lua/gtd/init.lua"
  local review_lines = {
    "# Review: abc",
    "",
    "<!-- base: abc123 -->",
    "",
    "## chunk",
    "",
    "- [ ] ./" .. rel .. "#5",
    "- [x] ./" .. rel .. "#10",
    "- [ ] ./other/file.lua#1",
  }
  local review_buf, review_path = make_file_buf(review_lines)

  -- Create a fake "source" file under a temp root.
  local root = vim.fn.tempname()
  vim.fn.mkdir(root .. "/lua/gtd", "p")
  local src_path = root .. "/" .. rel
  local sf = io.open(src_path, "w")
  sf:write("-- placeholder\n")
  sf:close()
  local src_buf = vim.fn.bufadd(src_path)
  vim.fn.bufload(src_buf)

  -- Make src_buf the "current" buffer via a floating win.
  local win = vim.api.nvim_open_win(src_buf, true, {
    relative = "editor", width = 40, height = 5, row = 0, col = 0,
  })

  -- Stub git helpers.
  local restore_root = stub(git, "get_root", function() return root end)
  local restore_review = stub(git, "get_review_path", function() return review_path end)

  -- Stub bufadd/bufload so toggle_done_for_current_file reuses our review_buf.
  local orig_bufadd = vim.fn.bufadd
  local orig_bufload = vim.fn.bufload
  vim.fn.bufadd = function(p)
    if p == review_path then return review_buf end
    return orig_bufadd(p)
  end
  vim.fn.bufload = function(b) return orig_bufload(b) end

  review.toggle_done_for_current_file()

  -- restore
  restore_root()
  restore_review()
  vim.fn.bufadd = orig_bufadd
  vim.fn.bufload = orig_bufload
  vim.api.nvim_win_close(win, true)
  vim.api.nvim_buf_delete(src_buf, { force = true })

  -- line 7 (index 6) was "- [ ]" for our file → should now be "- [x]"
  local toggled = vim.api.nvim_buf_get_lines(review_buf, 6, 7, false)[1]
  MiniTest.expect.equality(toggled, "- [x] ./" .. rel .. "#5")

  -- line 8 (index 7) was already "[x]" → unchanged
  local already = vim.api.nvim_buf_get_lines(review_buf, 7, 8, false)[1]
  MiniTest.expect.equality(already, "- [x] ./" .. rel .. "#10")

  -- line 9 (index 8) is a different file → unchanged
  local other = vim.api.nvim_buf_get_lines(review_buf, 8, 9, false)[1]
  MiniTest.expect.equality(other, "- [ ] ./other/file.lua#1")

  -- also written to disk
  local disk = read_file(review_path)
  MiniTest.expect.equality(disk[7], "- [x] ./" .. rel .. "#5")
  MiniTest.expect.equality(disk[9], "- [ ] ./other/file.lua#1")

  vim.api.nvim_buf_delete(review_buf, { force = true })
  os.remove(review_path)
  os.remove(src_path)
end

T["toggle_done_for_current_file is a no-op when no hunks match"] = function()
  local review_lines = {
    "# Review: abc",
    "",
    "## chunk",
    "",
    "- [ ] ./other/file.lua#1",
  }
  local review_buf, review_path = make_file_buf(review_lines)

  local root = vim.fn.tempname()
  vim.fn.mkdir(root .. "/lua/gtd", "p")
  local src_path = root .. "/lua/gtd/review.lua"
  local sf = io.open(src_path, "w")
  sf:write("-- placeholder\n")
  sf:close()
  local src_buf = vim.fn.bufadd(src_path)
  vim.fn.bufload(src_buf)

  local win = vim.api.nvim_open_win(src_buf, true, {
    relative = "editor", width = 40, height = 5, row = 0, col = 0,
  })

  local restore_root = stub(git, "get_root", function() return root end)
  local restore_review = stub(git, "get_review_path", function() return review_path end)

  local orig_bufadd = vim.fn.bufadd
  local orig_bufload = vim.fn.bufload
  vim.fn.bufadd = function(p)
    if p == review_path then return review_buf end
    return orig_bufadd(p)
  end
  vim.fn.bufload = function(b) return orig_bufload(b) end

  -- Should not throw; no hunks match "lua/gtd/review.lua".
  local ok, err = pcall(review.toggle_done_for_current_file)

  restore_root()
  restore_review()
  vim.fn.bufadd = orig_bufadd
  vim.fn.bufload = orig_bufload
  vim.api.nvim_win_close(win, true)
  vim.api.nvim_buf_delete(src_buf, { force = true })

  assert(ok, "toggle_done_for_current_file should not throw: " .. tostring(err))

  -- REVIEW.md lines unchanged
  local line = vim.api.nvim_buf_get_lines(review_buf, 4, 5, false)[1]
  MiniTest.expect.equality(line, "- [ ] ./other/file.lua#1")

  vim.api.nvim_buf_delete(review_buf, { force = true })
  os.remove(review_path)
  os.remove(src_path)
end

return T
