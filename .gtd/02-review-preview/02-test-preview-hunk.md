# Task: tests for `review.preview_hunk_under_cursor()` in a NEW `tests/test_review_preview.lua`

Create a new MiniTest file mirroring `tests/test_review_jump.lua`'s stub style.
Cover the float happy-path, the heading no-op, and the nil-diff no-float case.

## File
- `/Users/pmelab/Code/gtd/gtd.nvim/tests/test_review_preview.lua` (NEW file, ONLY this file)

## Depends on
- `review.preview_hunk_under_cursor()` from package 02 (parallel task; tested
  as a whole after both land) and `git.diff_hunk` from package 01.

## Skeleton
```lua
local T = MiniTest.new_set()
local review = require("gtd.review")
local git = require("gtd.git")
```
Use a local `stub(mod, key, replacement)` helper returning a restore fn (copy
from test_review_jump.lua).

## Helper: a real REVIEW.md buffer + window with cursor on a hunk line
Create a scratch buffer with lines like test_review_jump.lua's wiring test:
```
# Review: a1b2c3d
<!-- base: a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2 -->
## chunk
- [ ] ./lua/gtd/init.lua#12
```
Open it in a real window (`nvim_open_win`, `relative="editor"`), set cursor on
the hunk line. Remember the window id as `review_win`.

## Cases
1. Happy path — float opens, stays in REVIEW.md:
   - Stub `git.get_review_path` → some path, `git.get_base` → the base SHA,
     and `git.diff_hunk` → a fixed table e.g.
     `{ "@@ -1,1 +1,2 @@", " ctx", "+added" }`.
   - Record windows before: `vim.api.nvim_list_wins()`.
   - Call `review.preview_hunk_under_cursor()`.
   - Assert a NEW window appeared. Find the float (a win whose config
     `relative == "cursor"`, via `nvim_win_get_config`).
   - Assert its buffer lines equal the stubbed diff lines.
   - Assert the float buffer's `vim.bo[fbuf].filetype == "diff"`.
   - Assert `vim.api.nvim_get_current_win() == review_win` (cursor did NOT move
     to the float).
   - Clean up: close the float + review window, restore stubs.
2. Heading no-op + notify:
   - Buffer with cursor on a `## heading` line (no hunk).
   - Stub `vim.notify` to capture msg.
   - Call; assert notify mentions "no hunk" and NO new float window opened
     (compare `nvim_list_wins()` count before/after).
3. nil diff → notify + no float:
   - Cursor on a valid hunk line. Stub `git.get_review_path`/`git.get_base` as
     in case 1 but `git.diff_hunk` → nil.
   - Stub `vim.notify` to capture msg.
   - Call; assert notify mentions "no changes" and NO new float opened.

## Constraints
- Restore EVERY stub (`vim.notify`, `git.*`) and close created windows/buffers
  even on assert failure where feasible (use pcall + restore like
  `with_fake_root`).
- Do NOT modify `review.lua`, `init.lua`, README, or other test files.
- Detect the float via `nvim_win_get_config(win).relative == "cursor"`, not by
  guessing ids.

## Acceptance criteria
- [ ] New file `tests/test_review_preview.lua` returning a MiniTest set.
- [ ] Happy-path: a `relative="cursor"` float opens whose buffer holds the stubbed diff lines and has `filetype=diff`.
- [ ] Happy-path asserts the current window is still the REVIEW.md window after the call.
- [ ] Heading case: no float, notify mentions "no hunk".
- [ ] nil-diff case: no float, notify mentions "no changes".
- [ ] All stubs/windows cleaned up; suite green after pkg 02 lands.
