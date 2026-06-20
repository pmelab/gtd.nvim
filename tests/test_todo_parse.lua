local T = MiniTest.new_set()

local todo = require("gtd.todo")

local FIXTURES = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h") .. "/fixtures"

-- Helper: read fixture TODO.md into lines table
local function fixture_lines()
  local path = FIXTURES .. "/TODO.md"
  local f = io.open(path, "r")
  assert(f, "fixture TODO.md not found at " .. path)
  local content = f:read("*a")
  f:close()
  return vim.split(content, "\n")
end

-- Returns exactly the questions under ## Open Questions
T["parse_open_questions returns items only from Open Questions section"] = function()
  local lines = fixture_lines()
  local items = todo.parse_open_questions(lines)
  -- fixture has 2 ### blocks under Open Questions and 1 under Answered Questions
  MiniTest.expect.equality(#items, 2)
end

-- First item title
T["parse_open_questions captures correct title"] = function()
  local items = todo.parse_open_questions(fixture_lines())
  MiniTest.expect.equality(items[1].title, "What deployment strategy should we use?")
end

-- First item line number (line 5 in fixture)
T["parse_open_questions captures correct line number"] = function()
  local items = todo.parse_open_questions(fixture_lines())
  MiniTest.expect.equality(items[1].line, 5)
end

-- Block with placeholder => unanswered
T["parse_open_questions marks block with placeholder as unanswered"] = function()
  local items = todo.parse_open_questions(fixture_lines())
  MiniTest.expect.equality(items[1].answered, false)
end

-- Block without placeholder => answered
T["parse_open_questions marks block without placeholder as answered"] = function()
  local items = todo.parse_open_questions(fixture_lines())
  MiniTest.expect.equality(items[2].answered, true)
end

-- Section boundary: ### under ## Answered Questions is excluded
T["parse_open_questions excludes blocks outside Open Questions"] = function()
  local lines = fixture_lines()
  local items = todo.parse_open_questions(lines)
  for _, item in ipairs(items) do
    MiniTest.expect.no_equality(item.title, "Which test framework should we use?")
  end
end

-- Recommendation extraction
T["parse_open_questions extracts recommendation when present"] = function()
  local lines = {
    "## Open Questions",
    "",
    "### Should we use X?",
    "",
    "**Recommendation:** Use X because it is fast.",
    "",
    "<!-- user answers here -->",
  }
  local items = todo.parse_open_questions(lines)
  MiniTest.expect.equality(#items, 1)
  MiniTest.expect.equality(items[1].recommendation, "Use X because it is fast.")
end

-- No recommendation when absent
T["parse_open_questions leaves recommendation nil when absent"] = function()
  local items = todo.parse_open_questions(fixture_lines())
  MiniTest.expect.equality(items[1].recommendation, nil)
end

-- Recommendation truncated at 60 chars
T["parse_open_questions truncates recommendation to 60 chars"] = function()
  local long = string.rep("a", 80)
  local lines = {
    "## Open Questions",
    "",
    "### Q?",
    "",
    "**Recommendation:** " .. long,
    "",
    "<!-- user answers here -->",
  }
  local items = todo.parse_open_questions(lines)
  MiniTest.expect.equality(#items[1].recommendation, 60)
  MiniTest.expect.equality(items[1].recommendation:sub(58, 60), "...")
end

return T
