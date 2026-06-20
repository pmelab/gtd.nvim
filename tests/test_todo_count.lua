local T = MiniTest.new_set()

local todo = require("gtd.todo")

local FIXTURES = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h") .. "/fixtures"

-- Helper: lines from fixture TODO.md
local function fixture_lines()
  local path = FIXTURES .. "/TODO.md"
  local f = io.open(path, "r")
  assert(f, "fixture TODO.md not found at " .. path)
  local content = f:read("*a")
  f:close()
  return vim.split(content, "\n")
end

-- Helper: make a scratch buffer from a lines table
local function make_buf(lines)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  return bufnr
end

-- ──────────────────────────────────────────────────────────────
-- count_open_questions (line-level logic via parse_open_questions)
-- ──────────────────────────────────────────────────────────────

T["count_open_questions: fixture has exactly 1 unanswered question"] = function()
  local lines = fixture_lines()
  local questions = todo.parse_open_questions(lines)
  local count = 0
  for _, q in ipairs(questions) do
    if not q.answered then
      count = count + 1
    end
  end
  MiniTest.expect.equality(count, 1)
end

T["count_open_questions: placeholder outside Open Questions is ignored"] = function()
  local lines = {
    "## Preamble",
    "",
    "<!-- user answers here -->",  -- outside section, must not count
    "",
    "## Open Questions",
    "",
    "### Q1?",
    "",
    "<!-- user answers here -->",  -- inside section, counts
    "",
    "## Other Section",
    "",
    "### Q2?",
    "",
    "<!-- user answers here -->",  -- outside section, must not count
  }
  local questions = todo.parse_open_questions(lines)
  local count = 0
  for _, q in ipairs(questions) do
    if not q.answered then count = count + 1 end
  end
  MiniTest.expect.equality(count, 1)
end

T["count_open_questions: zero when no unanswered questions"] = function()
  local lines = {
    "## Open Questions",
    "",
    "### Q1?",
    "",
    "We already decided this.",
  }
  local questions = todo.parse_open_questions(lines)
  local count = 0
  for _, q in ipairs(questions) do
    if not q.answered then count = count + 1 end
  end
  MiniTest.expect.equality(count, 0)
end

T["count_open_questions: multiple unanswered questions counted correctly"] = function()
  local lines = {
    "## Open Questions",
    "",
    "### Q1?",
    "",
    "<!-- user answers here -->",
    "",
    "### Q2?",
    "",
    "<!-- user answers here -->",
    "",
    "### Q3 answered?",
    "",
    "We know the answer.",
  }
  local questions = todo.parse_open_questions(lines)
  local count = 0
  for _, q in ipairs(questions) do
    if not q.answered then count = count + 1 end
  end
  MiniTest.expect.equality(count, 2)
end

-- ──────────────────────────────────────────────────────────────
-- publish_diagnostics
-- ──────────────────────────────────────────────────────────────

T["publish_diagnostics: one WARN per unanswered question"] = function()
  local lines = {
    "## Open Questions",
    "",
    "### Q1?",
    "",
    "<!-- user answers here -->",
    "",
    "### Q2 answered?",
    "",
    "We know.",
  }
  local bufnr = make_buf(lines)
  todo.publish_diagnostics(bufnr)
  local diags = vim.diagnostic.get(bufnr)
  MiniTest.expect.equality(#diags, 1)
  MiniTest.expect.equality(diags[1].severity, vim.diagnostic.severity.WARN)
end

T["publish_diagnostics: diagnostic is on the ### heading line (0-indexed)"] = function()
  local lines = {
    "## Open Questions",
    "",
    "### My Question?",
    "",
    "<!-- user answers here -->",
  }
  local bufnr = make_buf(lines)
  todo.publish_diagnostics(bufnr)
  local diags = vim.diagnostic.get(bufnr)
  MiniTest.expect.equality(#diags, 1)
  -- line 3 in 1-indexed = lnum 2 in 0-indexed
  MiniTest.expect.equality(diags[1].lnum, 2)
end

T["publish_diagnostics: no diagnostics when all questions answered"] = function()
  local lines = {
    "## Open Questions",
    "",
    "### Q1?",
    "",
    "Already answered.",
  }
  local bufnr = make_buf(lines)
  todo.publish_diagnostics(bufnr)
  local diags = vim.diagnostic.get(bufnr)
  MiniTest.expect.equality(#diags, 0)
end

T["publish_diagnostics: diagnostic message contains question title"] = function()
  local lines = {
    "## Open Questions",
    "",
    "### Deploy to production?",
    "",
    "<!-- user answers here -->",
  }
  local bufnr = make_buf(lines)
  todo.publish_diagnostics(bufnr)
  local diags = vim.diagnostic.get(bufnr)
  MiniTest.expect.equality(#diags, 1)
  assert(diags[1].message:find("Deploy to production?", 1, true), "message should contain title")
end

-- ──────────────────────────────────────────────────────────────
-- statusline() via init.lua
-- ──────────────────────────────────────────────────────────────

T["statusline: returns '? N' format string"] = function()
  -- count_open_questions uses git; test the formatting logic directly
  -- by verifying the pattern when count > 0.
  -- We call statusline() on the module and just check the return type
  -- (actual count depends on whether we are in a git repo with a TODO.md).
  local gtd = require("gtd")
  local result = gtd.statusline()
  assert(type(result) == "string", "statusline() must return a string")
  -- If non-empty it must match "? <number>"
  if result ~= "" then
    assert(result:match("^%? %d+$"), "statusline() format must be '? N', got: " .. result)
  end
end

return T
