# Task: implement `review.preview_hunk_under_cursor()` in `lua/gtd/review.lua`

Add a non-disruptive diff-hunk preview that STAYS in REVIEW.md: show the single
git-diff hunk (vs the review base) for the anchor under the cursor in a
cursor-anchored floating window. The cursor does NOT leave the REVIEW.md window.

## File
- `/Users/pmelab/Code/gtd/gtd.nvim/lua/gtd/review.lua` (ONLY this file)

## Depends on
- `git.diff_hunk(path, base, lnum, root)` from package 01 (already landed).
- Existing `M.parse_hunk_line`, `git.get_review_path`, `git.get_base`, `git.get_root`.

## Behaviour (mirror `M.jump_to_hunk_under_cursor` for the front half)
Add a module-local at the top of the file (after `local git = ...`) to track the
float window id:
```lua
local preview_win = nil
```
Add `function M.preview_hunk_under_cursor()`:
1. Read the line under the cursor (same as `jump_to_hunk_under_cursor`):
   `buf = nvim_get_current_buf()`, `row = nvim_win_get_cursor(0)[1]`, get that line.
2. `hunk = M.parse_hunk_line(line)`. If nil → `vim.notify("gtd: no hunk on current line", vim.log.levels.WARN)` + return (Q4 no-op on heading).
3. `review_path = git.get_review_path()`; `base = review_path and git.get_base(review_path)`.
   If no base → `vim.notify("gtd: could not resolve review base", vim.log.levels.ERROR)` + return.
4. `local lines = git.diff_hunk(hunk.path, base, hunk.lnum)`.
   If `not lines or #lines == 0` → `vim.notify("gtd: no changes at this line vs review base", vim.log.levels.INFO)` + return (NO float).
5. If `preview_win` is set and `nvim_win_is_valid(preview_win)` → close it first
   (`pcall(vim.api.nvim_win_close, preview_win, true)`); then `preview_win = nil`.
6. Build a scratch buffer: `local pbuf = vim.api.nvim_create_buf(false, true)`.
   Set lines: `nvim_buf_set_lines(pbuf, 0, -1, false, lines)`.
   Set options: `vim.bo[pbuf].buftype = "nofile"`, `vim.bo[pbuf].bufhidden = "wipe"`,
   `vim.bo[pbuf].filetype = "diff"`, `vim.bo[pbuf].modifiable = false`.
7. Compute size: `width = min(100, max line length)`, `height = min(20, #lines)`.
8. Open a cursor-anchored float WITHOUT focusing it:
   ```lua
   preview_win = vim.api.nvim_open_win(pbuf, false, {
     relative = "cursor", row = 1, col = 0,
     width = width, height = height,
     border = "rounded", style = "minimal",
   })
   ```
   The `false` for `enter` keeps the cursor in REVIEW.md (core of Q10). Do NOT
   call `nvim_set_current_win` on the float.
9. Dismissal:
   - One-shot `CursorMoved` autocmd on the REVIEW.md buffer (`buffer = buf`,
     `once = true`) whose callback closes `preview_win` if valid and nils it.
   - Buffer-local `q` and `<Esc>` normal maps in `pbuf` that close `preview_win`
     and nil it (`{ buffer = pbuf, nowait = true }`).

## Constraints
- Do NOT touch gitsigns anywhere in this function — no `pcall(require,"gitsigns")`.
- Do NOT modify `init.lua`, tests, or README (separate tasks/packages).
- Keep `return M` at the end. Do not change existing functions.
- Guard all window closes with `nvim_win_is_valid` + `pcall` so repeat/stale ids
  don't error.

## Acceptance criteria
- [ ] `M.preview_hunk_under_cursor()` exists in `lua/gtd/review.lua`.
- [ ] Parses the hunk under cursor; no-op + "no hunk on current line" notify on a heading.
- [ ] Resolves review_path + base via `git.get_review_path` / `git.get_base`; notifies + returns when no base.
- [ ] Calls `git.diff_hunk(hunk.path, base, hunk.lnum)`; on nil/empty notifies "no changes at this line vs review base" and opens NO float.
- [ ] Builds a `nofile`, `filetype=diff`, non-modifiable scratch buffer with the diff lines.
- [ ] Opens a cursor-anchored (`relative="cursor"`), rounded, minimal float WITHOUT entering it (cursor stays in REVIEW.md).
- [ ] Repeat invocation closes the prior float first (module-local `preview_win`).
- [ ] Registers one-shot `CursorMoved` dismissal + buffer-local `q`/`<Esc>` in the float.
- [ ] No gitsigns reference; existing tests still pass.
