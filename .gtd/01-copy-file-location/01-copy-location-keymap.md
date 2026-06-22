# Task: Copy current file path + line number to clipboard

## Goal

Add a keyboard shortcut that copies the current buffer's path and cursor line
number as `path/to/file:line_number` to the system clipboard, so it can be
pasted into an AI agent for context.

## Context

- `lua/gtd/init.lua` holds the plugin: a `defaults.keys` table, a `deep_merge`
  helper, global keymap registration inside `M.setup(opts)`, and a
  `M.lazy_keys()` spec. User options are deep-merged over defaults via
  `M.setup`.
- Existing global keymaps are registered in `M.setup` like:
  ```lua
  vim.keymap.set("n", keys.pick_open_questions, function()
    require("gtd.todo").pick_open_questions()
  end, { desc = "gtd: pick open questions" })
  ```
- The plugin already uses `vim.fn`, `vim.api`, `vim.keymap`. Clipboard is the
  `+` register (`vim.fn.setreg("+", ...)`).

## Implementation

1. Add a new default keybinding in `defaults.keys` in `lua/gtd/init.lua`:
   ```lua
   copy_location = "<leader>gy",
   ```
   (`y` = yank; under the existing `<leader>g` "gtd" which-key group.)

2. Add a function `M.copy_location()` that:
   - Resolves the current buffer's file path. Prefer a path relative to the
     current working directory (`vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":.")`)
     so the agent gets a repo-relative path; fall back gracefully if the buffer
     has no name (empty name -> notify a warning and return without copying).
   - Gets the current cursor line: `vim.api.nvim_win_get_cursor(0)[1]`.
   - Builds the string `"<path>:<line>"`.
   - Writes it to the system clipboard: `vim.fn.setreg("+", text)` (and also
     `vim.fn.setreg('"', text)` so it lands in the default register too).
   - Calls `vim.notify("gtd: copied " .. text)` for feedback.
   - Returns the copied string (so it is unit-testable).

3. Register the global keymap inside `M.setup`, alongside the existing ones:
   ```lua
   vim.keymap.set("n", keys.copy_location, function()
     M.copy_location()
   end, { desc = "gtd: copy file:line to clipboard" })
   ```

4. Add the entry to `M.lazy_keys()` so lazy-loading users get it too:
   ```lua
   { keys.copy_location, function() require("gtd").copy_location() end, desc = "gtd: copy file:line to clipboard" },
   ```

## Tests

Add a test to `tests/test_init.lua`:

- Create a scratch buffer with a known name, set it current, move cursor to a
  known line, then assert `require("gtd").copy_location()` returns the expected
  `path:line` string and that `vim.fn.getreg("+")` equals it.
- Assert that with a no-name buffer, `copy_location()` does not error and
  returns `nil` (or otherwise signals "no file").

Run the suite with the project's existing test command (mini.test) and confirm
green.

## Acceptance criteria

- [ ] `defaults.keys.copy_location` exists, default `<leader>gy`.
- [ ] `M.copy_location()` copies `path:line` (repo-relative path) to the `+` register.
- [ ] `M.copy_location()` returns the copied string; handles no-name buffer without erroring.
- [ ] User feedback via `vim.notify`.
- [ ] Global keymap registered in `M.setup` using `keys.copy_location`.
- [ ] Entry added to `M.lazy_keys()`.
- [ ] Tests added to `tests/test_init.lua` and passing.
- [ ] Keybinding is overridable via `setup({ keys = { copy_location = ... } })`.
