# Task: Document the copy-location keymap in README

## Goal

Reflect the new "copy file:line to clipboard" feature in `README.md` so users
discover and can configure it.

## Context

`README.md` has three relevant places:

1. The key-overrides example block under "Installation" (`opts.keys = { ... }`).
2. The "Features" table.
3. The "Keymaps" table.

The default keybinding being documented is `<leader>gy`, and the action copies
the current file path + cursor line as `path:line` to the system clipboard for
pasting into an AI agent.

## Implementation

1. In the `opts.keys` example block, add a line:
   ```lua
   copy_location       = "<leader>gy",  -- global: copy file:line to clipboard
   ```

2. In the "Features" table, add a row:
   ```
   | Copy file location | Copies `path:line` of the cursor to the system clipboard for pasting into an AI agent |
   ```

3. In the "Keymaps" table, add a row:
   ```
   | `<leader>gy` | global | Copy current `file:line` to system clipboard |
   ```

## Acceptance criteria

- [ ] `opts.keys` example lists `copy_location = "<leader>gy"`.
- [ ] Features table has a row describing the copy-location feature.
- [ ] Keymaps table has a `<leader>gy` row.
- [ ] Wording is consistent with the implementation (repo-relative `path:line`,
      copied to system clipboard).
