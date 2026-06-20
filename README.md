# gtd.nvim

A Neovim plugin for the [gtd](https://github.com/pmelab/gtd) workflow — surfaces open questions and review status from your repo's `TODO.md` and `REVIEW.md` files directly inside Neovim.

## Requirements

- Neovim >= 0.10

## Installation

### lazy.nvim

```lua
{
  "pmelab/gtd.nvim",
  opts = {},
}
```

With key overrides:

```lua
{
  "pmelab/gtd.nvim",
  opts = {
    keys = {
      pick_open_questions = "<leader>gq",  -- global: open question picker
      pick_chunks         = "<leader>gp",  -- global: review chunk picker
      jump_to_hunk        = "gd",          -- REVIEW.md buffer-local
      toggle_done         = "<leader>gc",  -- REVIEW.md buffer-local
      toggle_done_cr      = "<cr>",        -- REVIEW.md buffer-local
    },
  },
  -- Optionally declare keys for lazy.nvim lazy-loading:
  keys = function() return require("gtd").lazy_keys() end,
}
```

### Manual setup

```lua
require("gtd").setup({
  keys = {
    -- override any default here
  },
})
```

## Features

| Feature | Description |
|---|---|
| Open question count in statusline | Shows `? N` when there are N unanswered questions in `TODO.md` |
| Open question picker | `vim.ui.select` over unanswered questions; jumps to the question in `TODO.md` |
| Diagnostics in TODO.md | WARN diagnostics on each unanswered `### ` heading |
| Review chunk picker | `vim.ui.select` over `## ` sections in `REVIEW.md` |
| Jump to hunk | Opens the source file at the hunk line from a `REVIEW.md` checkbox entry |
| Toggle checkbox | Toggle `- [ ]` / `- [x]` on a hunk line and write the file |
| Auto-refresh | Count refreshed on `BufWritePost TODO.md`, `FocusGained`, and every 5 minutes |
| Optional integrations | `mini.icons` and `which-key` registered when present (no hard dependency) |

## Keymaps

| Key | File | Action |
|---|---|---|
| `<leader>gq` | global | Pick open question and jump to it |
| `<leader>gp` | global | Pick review chunk and jump to it |
| `gd` | `REVIEW.md` | Jump to hunk under cursor in source file |
| `<leader>gc` | `REVIEW.md` | Toggle checkbox done on hunk under cursor |
| `<cr>` | `REVIEW.md` | Toggle checkbox done on hunk under cursor |

All keys are overridable via `setup({ keys = { ... } })`.

## Statusline integration

`require("gtd").statusline()` returns `"? N"` when there are N unanswered open
questions, or `""` when there are none. It reads a cache and is cheap to call
on every redraw.

```lua
-- Example with lualine
require("lualine").setup({
  sections = {
    lualine_x = { require("gtd").statusline },
  },
})

-- Example with heirline (component table)
{
  provider = function() return require("gtd").statusline() end,
}
```

## Diagnostics

When you open `TODO.md`, gtd publishes `WARN` diagnostics for every unanswered
open question (`<!-- user answers here -->` placeholder still present). The
diagnostics are updated automatically on `BufWritePost` and `FocusGained`.
