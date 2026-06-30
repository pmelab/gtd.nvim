# Task: wire `<leader>k` preview keymap in `lua/gtd/init.lua`

Register a buffer-local `preview_hunk` keymap in REVIEW.md that calls
`review.preview_hunk_under_cursor()`.

## File
- `/Users/pmelab/Code/gtd/gtd.nvim/lua/gtd/init.lua` (ONLY this file)

## Depends on
- `review.preview_hunk_under_cursor()` from package 02 (already landed).

## Changes
1. In `defaults.keys` (top of file), add:
   ```lua
   preview_hunk = "<leader>k",
   ```
   Place it alongside the other REVIEW.md buffer-local keys (e.g. after
   `toggle_done_cr`).
2. In `M.setup_buffer_keymaps`, inside the `if fname:match(".*/REVIEW%.md$")`
   branch (the same block as `jump_to_hunk`), add a guarded buffer-local map:
   ```lua
   if keys.preview_hunk then
     vim.keymap.set("n", keys.preview_hunk, function()
       review.preview_hunk_under_cursor()
     end, { buffer = bufnr, desc = "gtd: preview hunk under cursor" })
   end
   ```
   (`local review = require("gtd.review")` is already in scope in that branch.)

## Constraints
- NO global keymap, NO `lazy_keys()` entry for preview_hunk (it is buffer-local
  only). Do not change `M.lazy_keys` — the wiring test asserts it still has 5
  entries, so leaving it untouched keeps that green.
- Do NOT modify review.lua, git.lua, README, or tests.
- Keep the `if keys.preview_hunk then` guard so users can disable it.

## Acceptance criteria
- [ ] `defaults.keys.preview_hunk == "<leader>k"`.
- [ ] `M.setup_buffer_keymaps` registers a buffer-local `n` map for
      `keys.preview_hunk` with desc "gtd: preview hunk under cursor" in REVIEW.md,
      guarded by `if keys.preview_hunk then`.
- [ ] No global map and no new `lazy_keys` entry (lazy_keys still returns 5).
- [ ] Existing suite (incl. test_wiring.lua) stays green.
