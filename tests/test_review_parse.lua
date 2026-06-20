local T = MiniTest.new_set()

local review = require("gtd.review")

local FIXTURES = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h") .. "/fixtures"

local function fixture_lines()
  local path = FIXTURES .. "/REVIEW.md"
  local f = io.open(path, "r")
  assert(f, "fixture REVIEW.md not found at " .. path)
  local content = f:read("*a")
  f:close()
  return vim.split(content, "\n")
end

-- parse_chunks: correct chunk count (only ## sections, not # or <!-- base: -->)
T["parse_chunks returns one entry per ## section"] = function()
  local chunks = review.parse_chunks(fixture_lines())
  MiniTest.expect.equality(#chunks, 2)
end

-- parse_chunks: first chunk title
T["parse_chunks captures first chunk title"] = function()
  local chunks = review.parse_chunks(fixture_lines())
  MiniTest.expect.equality(chunks[1].title, "feat(init): add setup function")
end

-- parse_chunks: second chunk title
T["parse_chunks captures second chunk title"] = function()
  local chunks = review.parse_chunks(fixture_lines())
  MiniTest.expect.equality(chunks[2].title, "feat(init): add placeholder exports")
end

-- parse_chunks: heading line numbers are 1-based
T["parse_chunks records correct heading line for first chunk"] = function()
  local chunks = review.parse_chunks(fixture_lines())
  -- fixture line 5 is "## feat(init): add setup function"
  MiniTest.expect.equality(chunks[1].line, 5)
end

T["parse_chunks records correct heading line for second chunk"] = function()
  local chunks = review.parse_chunks(fixture_lines())
  -- fixture line 11 is "## feat(init): add placeholder exports"
  MiniTest.expect.equality(chunks[2].line, 11)
end

-- parse_chunks: hunk counts
T["parse_chunks first chunk has 3 hunks"] = function()
  local chunks = review.parse_chunks(fixture_lines())
  MiniTest.expect.equality(#chunks[1].hunks, 3)
end

T["parse_chunks second chunk has 3 hunks"] = function()
  local chunks = review.parse_chunks(fixture_lines())
  MiniTest.expect.equality(#chunks[2].hunks, 3)
end

-- parse_chunks: hunk path strips ./
T["parse_chunks strips ./ from hunk path"] = function()
  local chunks = review.parse_chunks(fixture_lines())
  MiniTest.expect.equality(chunks[1].hunks[1].path, "lua/gtd/init.lua")
end

-- parse_chunks: hunk lnum
T["parse_chunks captures lnum from hunk line"] = function()
  local chunks = review.parse_chunks(fixture_lines())
  MiniTest.expect.equality(chunks[1].hunks[1].lnum, 1)
  MiniTest.expect.equality(chunks[1].hunks[2].lnum, 12)
  MiniTest.expect.equality(chunks[1].hunks[3].lnum, 24)
end

-- parse_chunks: mixed checked/unchecked
T["parse_chunks marks checked hunks done=true"] = function()
  local chunks = review.parse_chunks(fixture_lines())
  MiniTest.expect.equality(chunks[1].hunks[1].done, true)
  MiniTest.expect.equality(chunks[1].hunks[2].done, true)
end

T["parse_chunks marks unchecked hunks done=false"] = function()
  local chunks = review.parse_chunks(fixture_lines())
  MiniTest.expect.equality(chunks[1].hunks[3].done, false)
end

-- parse_chunks: hunk line field
T["parse_chunks records buffer line for each hunk"] = function()
  local chunks = review.parse_chunks(fixture_lines())
  -- line 5 = heading, line 6 = blank, line 7/8/9 = hunks
  MiniTest.expect.equality(chunks[1].hunks[1].line, 7)
  MiniTest.expect.equality(chunks[1].hunks[2].line, 8)
  MiniTest.expect.equality(chunks[1].hunks[3].line, 9)
end

-- parse_hunk_line: checked line
T["parse_hunk_line parses checked line"] = function()
  local h = review.parse_hunk_line("- [x] ./lua/gtd/init.lua#42")
  MiniTest.expect.no_equality(h, nil)
  MiniTest.expect.equality(h.path, "lua/gtd/init.lua")
  MiniTest.expect.equality(h.lnum, 42)
  MiniTest.expect.equality(h.done, true)
end

-- parse_hunk_line: unchecked line
T["parse_hunk_line parses unchecked line"] = function()
  local h = review.parse_hunk_line("- [ ] ./src/foo.ts#99")
  MiniTest.expect.no_equality(h, nil)
  MiniTest.expect.equality(h.path, "src/foo.ts")
  MiniTest.expect.equality(h.lnum, 99)
  MiniTest.expect.equality(h.done, false)
end

-- parse_hunk_line: non-hunk lines return nil
T["parse_hunk_line returns nil for regular text"] = function()
  MiniTest.expect.equality(review.parse_hunk_line("some explanation text"), nil)
end

T["parse_hunk_line returns nil for # heading"] = function()
  MiniTest.expect.equality(review.parse_hunk_line("# Review: a1b2c3d"), nil)
end

T["parse_hunk_line returns nil for ## heading"] = function()
  MiniTest.expect.equality(review.parse_hunk_line("## A Chunk Title"), nil)
end

T["parse_hunk_line returns nil for base comment"] = function()
  MiniTest.expect.equality(
    review.parse_hunk_line("<!-- base: a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2 -->"),
    nil
  )
end

T["parse_hunk_line returns nil for empty line"] = function()
  MiniTest.expect.equality(review.parse_hunk_line(""), nil)
end

-- parse_hunk_line: missing #line anchor returns nil
T["parse_hunk_line returns nil when #line is missing"] = function()
  MiniTest.expect.equality(review.parse_hunk_line("- [ ] ./src/foo.ts"), nil)
end

return T
