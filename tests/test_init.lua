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

return T
