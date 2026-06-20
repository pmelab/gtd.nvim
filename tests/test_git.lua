local T = MiniTest.new_set()

local git = require("gtd.git")

local FIXTURES = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h") .. "/fixtures"

-- get_base: present
T["get_base returns hash from lines"] = function()
  local lines = {
    "# Review",
    "",
    "<!-- base: a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2 -->",
    "",
  }
  MiniTest.expect.equality(
    git.get_base(lines),
    "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2"
  )
end

-- get_base: absent
T["get_base returns nil when marker missing"] = function()
  local lines = { "# Review", "", "No marker here." }
  MiniTest.expect.equality(git.get_base(lines), nil)
end

-- get_base: from fixture file path
T["get_base reads hash from REVIEW.md fixture"] = function()
  local path = FIXTURES .. "/REVIEW.md"
  MiniTest.expect.equality(
    git.get_base(path),
    "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2"
  )
end

-- get_base: missing file returns nil
T["get_base returns nil for missing file"] = function()
  MiniTest.expect.equality(git.get_base("/nonexistent/REVIEW.md"), nil)
end

-- get_root: inside a repo
T["get_root returns toplevel for path inside repo"] = function()
  -- The plugin repo itself is a git repo
  local repo = vim.fn.fnamemodify(FIXTURES, ":h:h")
  local root = git.get_root(repo)
  MiniTest.expect.equality(type(root), "string")
  -- root should end without a slash and exist
  MiniTest.expect.equality(vim.fn.isdirectory(root), 1)
end

-- get_root: outside a repo
T["get_root returns nil outside a repo"] = function()
  MiniTest.expect.equality(git.get_root("/tmp"), nil)
end

-- get_todo_path: resolves to root/TODO.md
T["get_todo_path resolves TODO.md under root"] = function()
  local root = git.get_root(FIXTURES)
  MiniTest.expect.equality(type(root), "string")
  MiniTest.expect.equality(git.get_todo_path(root), root .. "/TODO.md")
end

-- get_review_path: resolves to root/REVIEW.md
T["get_review_path resolves REVIEW.md under root"] = function()
  local root = git.get_root(FIXTURES)
  MiniTest.expect.equality(type(root), "string")
  MiniTest.expect.equality(git.get_review_path(root), root .. "/REVIEW.md")
end

-- get_todo_path: nil when root is nil
T["get_todo_path returns nil when not in a repo"] = function()
  -- pass a fake root: use the explicit-root variant to avoid cwd side effects
  -- We can test the nil-propagation by monkey-patching get_root temporarily
  local orig = git.get_root
  git.get_root = function() return nil end
  local result = git.get_todo_path()
  git.get_root = orig
  MiniTest.expect.equality(result, nil)
end

return T
