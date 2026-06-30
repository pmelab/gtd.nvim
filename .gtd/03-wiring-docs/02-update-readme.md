# Task: document `<leader>k` preview in `README.md`

Document the new quick diff-hunk preview keymap and config key.

## File
- `/Users/pmelab/Code/gtd/gtd.nvim/README.md` (ONLY this file)

## Changes
1. In the `opts.keys` example block (the `### lazy.nvim` "key overrides" code
   block), add the new key alongside the other REVIEW.md buffer-local entries:
   ```lua
   preview_hunk        = "<leader>k",         -- REVIEW.md buffer-local
   ```
2. In the **Features** table, add a row:
   ```
   | Preview hunk | Quick diff-hunk preview floated at the cursor in `REVIEW.md` without leaving the buffer (gtd computes the diff itself — no gitsigns required) |
   ```
3. In the **Keymaps** table, add a row (with the other REVIEW.md keys):
   ```
   | `<leader>k` | `REVIEW.md` | Preview the diff hunk under the cursor in a float (stays in REVIEW.md) |
   ```

## Constraints
- Do NOT modify any code or test files — README.md only.
- Keep table formatting consistent with the existing rows.
- Make clear it has NO gitsigns requirement and that it does NOT switch buffers
  (contrast with `gd`, which opens the file).

## Acceptance criteria
- [ ] `preview_hunk = "<leader>k"` appears in the keys-override example.
- [ ] Features table has a "Preview hunk" row noting no-gitsigns + stays in REVIEW.md.
- [ ] Keymaps table has a `<leader>k` / `REVIEW.md` row.
- [ ] No other files changed.
