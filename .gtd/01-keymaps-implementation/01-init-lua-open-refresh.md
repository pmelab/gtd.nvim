# Implement open-or-refresh for TODO.md / REVIEW.md in `lua/gtd/init.lua`

Implement the entire feature's runtime code in the single file
`lua/gtd/init.lua`. This is one task because all changes live in one file and
cannot be parallelized. See `TODO.md` `## Plan` (the source of truth) for the
full, settled design and the resolved Open Questions.

## Description

Add two global, overridable keymaps (`<leader>gt`, `<leader>gr`) that
open-or-refresh `TODO.md` / `REVIEW.md` from anywhere in a git repo, backed by a
shared reload helper.

Concretely, in `lua/gtd/init.lua`:

1. **Shared local reload helper** — `local function open_or_focus_reload(path)`:
   - `local bufnr = vim.fn.bufnr(path)`.
   - If the buffer is shown in a window (`vim.fn.bufwinid(bufnr) ~= -1`), focus
     it with `vim.api.nvim_set_current_win(win)`; otherwise
     `vim.cmd("edit " .. vim.fn.fnameescape(path))` in the current window.
     Mirror the jump-or-open precedent in `lua/gtd/todo.lua` lines 117-126
     (`pick_open_questions`).
   - After the target buffer/window is current: re-resolve the bufnr, and if
     `vim.bo[bufnr].modified` is true, `vim.cmd("write")` first (persist local
     edits), then `vim.cmd("edit!")` to force-reload disk truth. If not
     modified, `vim.cmd("edit!")` directly. Do NOT use `:checktime`.

2. **`M.open_or_refresh_todo()`**:
   - Resolve path via `require("gtd.git").get_todo_path()`.
   - nil (not in a repo) → `vim.notify("gtd: no TODO.md found (not in a git repo)", vim.log.levels.WARN)` and `return`.
   - File missing (`vim.fn.filereadable(path) == 0`) → `vim.notify("gtd: no TODO.md found", vim.log.levels.WARN)` and `return`.
   - Else call `open_or_focus_reload(path)`, then `require("gtd.todo").refresh_count()`.

3. **`M.open_or_refresh_review()`**:
   - Resolve path via `require("gtd.git").get_review_path()`.
   - nil OR missing (`vim.fn.filereadable(path) == 0`) → `vim.notify("gtd: no REVIEW.md (run a review first)", vim.log.levels.WARN)` and `return`.
   - Else call `open_or_focus_reload(path)`. (REVIEW.md buffer-local keymaps
     auto-attach on `BufEnter` — no extra wiring.)

4. **Defaults** — add to `defaults.keys` (init.lua lines 3-12):
   - `open_todo = "<leader>gt"`
   - `open_review = "<leader>gr"`

5. **Global keymaps in `M.setup()`** (next to existing `pick_*` / `copy_location`
   registrations, ~lines 150-160):
   - `keys.open_todo` → calls `M.open_or_refresh_todo()`, `desc = "gtd: open/refresh TODO.md"`.
   - `keys.open_review` → calls `M.open_or_refresh_review()`, `desc = "gtd: open/refresh REVIEW.md"`.

6. **`M.lazy_keys()`** (~lines 179-186) — add two entries using the same `desc`
   strings, calling `require("gtd").open_or_refresh_todo()` /
   `open_or_refresh_review()`, matching the existing entry style.

## Acceptance criteria

- [ ] `local function open_or_focus_reload(path)` exists with focus-existing-window-via-`bufwinid` + save-if-modified-then-`edit!` behaviour (no `:checktime`).
- [ ] `M.open_or_refresh_todo()` resolves via `git.get_todo_path()`, WARN-notifies + returns on nil-root and on missing file, else reloads and calls `todo.refresh_count()`.
- [ ] `M.open_or_refresh_review()` resolves via `git.get_review_path()`, WARN-notifies the friendly "run a review first" message + returns on nil/missing, else reloads.
- [ ] `defaults.keys` gains `open_todo = "<leader>gt"` and `open_review = "<leader>gr"`.
- [ ] `M.setup()` registers both global keymaps with the exact `desc` strings `"gtd: open/refresh TODO.md"` and `"gtd: open/refresh REVIEW.md"`.
- [ ] `M.lazy_keys()` returns two additional entries (5 total) with those same `desc` strings.
- [ ] Existing test suite still passes (`make test` / the MiniTest runner). NOTE: this task alone would leave `test_wiring.lua`'s `#spec == 3` assertion failing — that fix is done in the sibling task `02-test-wiring-count-fix.md` in THIS package, so the package ends green.

## Files to examine

- `lua/gtd/init.lua` (the only file this task edits)
- `lua/gtd/git.lua` — `get_todo_path`, `get_review_path`, `get_root` signatures
- `lua/gtd/todo.lua` lines 117-126 (jump-or-open precedent) and `refresh_count` ~173-190

## Constraints / edge cases

- Edit ONLY `lua/gtd/init.lua`. Do not touch test files or README in this task.
- Notify levels must be `vim.log.levels.WARN`.
- `bufnr` for an unloaded/nonexistent buffer is `-1`; after `:edit` re-resolve the bufnr before checking `modified`.
- Keep `desc` strings byte-for-byte identical between `setup()` and `lazy_keys()` (tests assert on them).
