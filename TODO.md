# Plan

## Feature request

> i would like to be able to open hunks referenced in REVIEW.md in a quick
> preview somehow. ideally with <leader>k

## Open questions

Answer inline under each marker. The plan body below is written assuming a
default for each; confirming or changing an answer reshapes the plan.

### Q1 — What does the preview SHOW? (central decision)

A REVIEW.md hunk line stores only `path#lnum` (a single anchor line, not a diff
range). So the preview content must be reconstructed from one of:

- **(a) git diff** of the file at that hunk vs the review base SHA — i.e. the
  added/removed lines around `lnum`, rendered as a `diff` (`+`/`-` prefixed)
  block. Matches the "hunks" framing in the request and the existing `gd` flow
  which sets the gitsigns change_base. Requires running
  `git diff <base> -- <path>` and slicing the hunk that contains `lnum`.
- **(b) current file content** — N context lines of the working-tree file
  centred on `lnum`, with `lnum` highlighted. Simpler, no diff parsing, but
  shows no change context.
- **(c) both** — diff if a hunk exists at that line, else fall back to file
  content.

Which? (Plan body assumes **(a) git diff vs review base**, the highest-value
interpretation of "hunks".)

b

### Q2 — Presentation and dismissal

- **Window type:** floating window anchored at the cursor (like
  `vim.lsp.util.open_floating_preview` / gitsigns `preview_hunk`), vs a bottom
  split, vs a `vim.lsp`-style hover that closes on cursor move?
- **Sizing:** auto-size to content with a max height/width, or fixed?
- **Dismissal:** `<leader>k` again to toggle? Any cursor move (`CursorMoved`)?
  `<Esc>` / `q` inside the float? First keypress?

(Plan body assumes a **cursor-anchored floating window, auto-sized with a max
height (~20 lines) and max width (~100 cols), closed on the next CursorMoved in
REVIEW.md or by `q`/`<Esc>` when focus is in the float**. Repeated `<leader>k`
re-opens for the new line.)

agreed

### Q3 — Implementation dependency

The float can be **self-contained** (own `nvim_open_win` + scratch buffer,
filetype `diff` or the file's own ft) or **delegate to gitsigns**
(`require("gitsigns").preview_hunk()` / `preview_hunk_inline()`). gitsigns is
currently only a soft (pcall) dependency, and its preview operates on the
_currently open file buffer at cursor_, not on a `path#lnum` reference from
REVIEW.md — so delegating would require first opening the file (defeating the
"non-disruptive" goal).

Self-contained, or insist on gitsigns? (Plan body assumes **self-contained**,
keeping gitsigns soft-optional as today.)

use gitsigns

### Q4 — Cursor on a `## chunk` heading

When `<leader>k` is pressed with the cursor on a chunk heading rather than a
hunk line: **no-op with a notify**, or **preview all hunks in that chunk**
(concatenated in the float)? (Plan body assumes **no-op + gentle notify**,
mirroring `gd`'s "no hunk on current line" behaviour.)

agreed

### Q5 — Syntax highlighting in the preview buffer

If Q1=(a) diff: set the float buffer filetype to `diff`. If Q1=(b) file content:
set it to the _source file's_ filetype (via `vim.filetype.match`) so it
highlights as code. Confirm the highlighting choice for the selected content
mode.

agreed

### Q6 — Config key name

New entry in `defaults.keys`. Proposed name **`preview_hunk = "<leader>k"`**,
registered **buffer-local in REVIEW.md** (in `M.setup_buffer_keymaps`, beside
`jump_to_hunk`). Confirm the name and that it should NOT also be a global map.

agreed

## Plan body

Assumes: Q1=(a) git diff vs review base, Q2=cursor-anchored auto-sized float,
Q3=self-contained, Q4=no-op on heading, Q5=`diff` filetype, Q6=`preview_hunk`
buffer-local.

### New: `git.diff_hunk(path, base, lnum)` in `lua/gtd/git.lua`

- Run `git diff <base> -- <path>` (via `M.git_command`, cwd = repo root).
- Parse the unified-diff output; find the `@@ -a,b +c,d @@` hunk whose new-side
  range `[c, c+d)` contains `lnum`.
- Return that hunk as a list of lines (the `@@` header + body `+`/`-`/context
  lines), or `nil` if no hunk covers `lnum` (e.g. line unchanged vs base).
- Pure-ish: takes path/base/lnum, returns lines — easy to unit test by stubbing
  `git_command`.

### New: `review.preview_hunk_under_cursor()` in `lua/gtd/review.lua`

- Parse the hunk line under cursor with `parse_hunk_line` (reuse). If nil →
  notify "no hunk on current line" and return (Q4 no-op).
- Resolve `review_path` + `base` via `git.get_review_path` / `git.get_base`
  (same as `jump_to_hunk_under_cursor`). If no base → error notify.
- Call `git.diff_hunk(hunk.path, base, hunk.lnum)`.
  - If nil/empty → notify "no diff for this hunk" (or fall back per Q1(c)).
- Build a scratch buffer (`nvim_create_buf(false, true)`), set lines to the
  diff, set `filetype=diff` and `modifiable=false`.
- Open a floating window anchored at cursor: `relative="cursor"`, size =
  min(content, max), `border="rounded"`, `style="minimal"`.
- Register dismissal: `CursorMoved` autocmd (one-shot) to close the float +
  buffer-local `q`/`<Esc>` maps in the float buffer (Q2).
- Track the open float win id in a module-local so a second `<leader>k` closes
  the previous one first (no orphan floats).

### Wiring: `lua/gtd/init.lua`

- Add `preview_hunk = "<leader>k"` to `defaults.keys`.
- In `M.setup_buffer_keymaps`, inside the REVIEW.md branch, add a buffer-local
  `n` map for `keys.preview_hunk` calling `review.preview_hunk_under_cursor()`,
  with desc "gtd: preview hunk under cursor". Guard with
  `if keys.preview_hunk then` so users can disable it.
- No global map and no `lazy_keys()` entry (buffer-local only).

### Tests: `tests/test_review_preview.lua` (new)

- `git.diff_hunk`: stub `git_command` to return a canned unified diff; assert it
  returns the correct hunk for an in-range `lnum` and `nil` for an out-of-range
  one.
- `preview_hunk_under_cursor`: in a fake REVIEW.md buffer with cursor on a hunk
  line, stub `git.diff_hunk` and assert a float window is opened with the
  expected buffer lines and `filetype=diff`; assert no-op + notify when cursor
  is on a heading (mirror existing `test_review_jump.lua` patterns).

### README

- Document the `<leader>k` preview map and the `preview_hunk` config key (keep
  keymap table in README in sync — required).

## Resolved

(none yet)
