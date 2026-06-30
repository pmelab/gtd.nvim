# Task: tests for `git.diff_hunk` in `tests/test_git.lua`

Add MiniTest cases for the new `git.diff_hunk(path, base, lnum, root)` helper.
Stub `git.git_command` to return a canned multi-hunk unified diff (mirror the
stub style in `tests/test_review_jump.lua`).

## File
- `/Users/pmelab/Code/gtd/gtd.nvim/tests/test_git.lua` (ONLY this file)

## What to add
Append new `T[...]` cases to the existing set (keep the existing tests intact;
`local git = require("gtd.git")` is already at the top; `return T` stays last).

Use a canned diff fixture string with at least TWO hunks, e.g.:
```
diff --git a/foo.lua b/foo.lua
index 1111111..2222222 100644
--- a/foo.lua
+++ b/foo.lua
@@ -1,3 +1,4 @@
 line one
+added line
 line two
 line three
@@ -10,2 +11,3 @@
 ten
+eleven
 twelve
```
New-side ranges: first hunk `[1, 5)` (lines 1..4), second hunk `[11, 14)`
(lines 11..13).

Stub the runner before each call and restore after:
```lua
local orig = git.git_command
git.git_command = function(args, opts) return CANNED_DIFF, 0 end
-- ... call git.diff_hunk(...) ...
git.git_command = orig
```
Also stub `git.get_root` (return a fake non-nil root) OR pass an explicit
`root` arg to `diff_hunk` so it does not shell out for the root.

## Cases to cover
1. In-range lnum hits the correct hunk: `diff_hunk("foo.lua", "deadbeef", 2, root)`
   returns a table whose FIRST element is the `@@ -1,3 +1,4 @@` header and which
   contains `"+added line"`. Assert it does NOT contain `"+eleven"`.
2. In-range lnum for the SECOND hunk: `diff_hunk("foo.lua", "deadbeef", 12, root)`
   returns a table whose first element is the `@@ -10,2 +11,3 @@` header and
   contains `"+eleven"`.
3. Out-of-range lnum: `diff_hunk("foo.lua", "deadbeef", 100, root)` returns nil.
4. Git failure: stub `git_command` to return `("", 1)` → returns nil.
5. (Optional) empty diff: stub returns `("", 0)` → returns nil.

## Constraints
- Do NOT modify `lua/gtd/git.lua` (separate parallel task implements it).
- Use `MiniTest.expect.equality` / `MiniTest.expect.no_equality` and `assert`
  with `:find(needle, 1, true)` for substring checks, matching existing style.
- Always restore stubbed functions (use pcall-around or restore inline) so a
  failing assert doesn't leak the stub into other tests.

## Acceptance criteria
- [ ] New cases added to `tests/test_git.lua` covering in-range (both hunks),
      out-of-range (nil), and git-failure (nil).
- [ ] First returned element is asserted to be the matching `@@` header line.
- [ ] Returned hunk asserted to contain the expected `+` line and NOT the other hunk's.
- [ ] `git.git_command` (and `git.get_root` if stubbed) restored after each case.
- [ ] Existing test_git.lua cases untouched; full suite green after pkg 01 lands.
