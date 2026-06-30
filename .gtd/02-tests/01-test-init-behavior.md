# Behavioral tests for open-or-refresh in `tests/test_init.lua`

Depends on package 01 (the implementation must exist for these tests to pass).
Add MiniTest cases for the new defaults and the two new functions.

## Description

Append tests to `tests/test_init.lua` (MiniTest style, matching the existing
`copy_location` tests):

1. **Defaults present**: after `gtd.setup({})`, assert
   `gtd.config.keys.open_todo == "<leader>gt"` and
   `gtd.config.keys.open_review == "<leader>gr"`.

2. **Functions callable**: assert `type(gtd.open_or_refresh_todo) == "function"`
   and `type(gtd.open_or_refresh_review) == "function"`.

3. **Opens the file in a temp git repo**: create a temp dir, run
   `require("gtd.git").git_command({ "init" }, { cwd = dir })`, write a `TODO.md`
   (and `REVIEW.md`) fixture into it, `cd`/`vim.cmd("cd " .. dir)` or pass cwd so
   `git.get_root()` resolves to it, call `gtd.open_or_refresh_todo()` and assert
   the current buffer name (`vim.api.nvim_buf_get_name(0)`) matches the TODO.md
   path; same for REVIEW. (You can reuse the fixtures under `tests/fixtures/` for
   content, but the file must live inside a git repo for `get_root` to resolve.)

4. **Missing-file notifies, does not open**: in a temp git repo with NO TODO.md
   (or REVIEW.md), stub `vim.notify` to capture messages, call the function, and
   assert it notified (WARN) and did NOT switch to a TODO.md/REVIEW.md buffer.
   Restore the original `vim.notify` after.

## Acceptance criteria

- [ ] Test asserts `open_todo`/`open_review` defaults after `setup({})`.
- [ ] Test asserts both functions are callable (`type == "function"`).
- [ ] Test opens TODO.md (and REVIEW.md) in a temp git repo and asserts current buffer name matches the resolved path.
- [ ] Test stubs `vim.notify`, asserts a WARN is emitted and no target buffer opened when the file is missing, then restores `vim.notify`.
- [ ] All tests pass against the package-01 implementation.

## Files to examine

- `tests/test_init.lua` (the only file this task edits).
- `lua/gtd/git.lua` — `git_command`, `get_root`, `get_todo_path`, `get_review_path`.
- `lua/gtd/init.lua` — the functions under test (from package 01).
- `tests/fixtures/TODO.md`, `tests/fixtures/REVIEW.md` — reusable fixture content.

## Constraints / edge cases

- Edit ONLY `tests/test_init.lua` (file-disjoint from the sibling test-wiring task).
- `get_root` shells out to git relative to cwd — set cwd into the temp repo (e.g. `vim.cmd("cd " .. dir)`) or otherwise ensure resolution; restore cwd in cleanup.
- Always restore stubbed globals (`vim.notify`) and clean up temp dirs/buffers to avoid leaking state into other MiniTest cases.
