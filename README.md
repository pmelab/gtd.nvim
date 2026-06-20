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

### Manual setup

```lua
require("gtd").setup({
  -- override defaults here
  keys = {
    -- keymaps added in later packages
  },
})
```

## Features

| Feature | Status |
|---|---|
| Open question count in statusline | planned |
| Jump to next open question | planned |
| Review hunk navigation | planned |
| Answer question inline | planned |

## Keymaps

| Key | Action | Status |
|---|---|---|
| _(none yet)_ | — | planned |

## Statusline integration

```lua
-- Example with lualine
require("lualine").setup({
  sections = {
    lualine_x = { require("gtd").statusline },
  },
})
```
