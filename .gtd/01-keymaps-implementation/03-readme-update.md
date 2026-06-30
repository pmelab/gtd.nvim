# Document the new keymaps in `README.md`

Reflect the open-or-refresh feature in `README.md` (repo convention: every
significant change is mirrored in the README).

## Description

Edit `README.md`:

1. **Keymaps table** (~lines 64-75) — add two rows:
   - `| `<leader>gt` | global | Open/refresh `TODO.md` |`
   - `| `<leader>gr` | global | Open/refresh `REVIEW.md` |`

2. **Features table** (~lines 50-62) — add a row:
   - `| Open/refresh TODO & REVIEW | `<leader>gt` / `<leader>gr` open the file (or focus its window) and reload it from disk |`

3. **Key-override example blocks** — add the two keys to BOTH:
   - the lazy.nvim `opts.keys = { ... }` block (~lines 26-32), e.g.
     `open_todo = "<leader>gt",  -- global: open/refresh TODO.md` and
     `open_review = "<leader>gr",  -- global: open/refresh REVIEW.md`
   - the manual `require("gtd").setup({ keys = { ... } })` block (~lines 42-48)
     if it lists keys (it currently has a placeholder comment — leave that or add
     the keys consistently; at minimum the lazy.nvim block must list them).

## Acceptance criteria

- [ ] Keymaps table lists `<leader>gt` and `<leader>gr` as global with open/refresh descriptions.
- [ ] Features table has an open/refresh TODO & REVIEW row.
- [ ] The lazy.nvim `opts.keys` example block includes `open_todo` and `open_review`.
- [ ] Markdown tables/code blocks remain well-formed.

## Files to examine

- `README.md` lines 20-75.

## Constraints / edge cases

- Edit ONLY `README.md`. File-disjoint from the init.lua and test tasks in this package.
- Keymap defaults must read `<leader>gt` (TODO) and `<leader>gr` (REVIEW), matching `defaults.keys`.
