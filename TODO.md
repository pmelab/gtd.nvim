# Plan

## Feature request

> i would like to be able to open hunks referenced in REVIEW.md in a quick
> preview somehow. ideally with <leader>k

## Open questions

Answer inline under each marker. The plan body below resolves the conflict with
a stated default; confirming or changing it reshapes the plan.

### Q7 — CONFLICT: "show file content (Q1=b)" vs "use gitsigns (Q3)"

You answered Q1=**(b) file content** (preview shows the working-tree file, a
window of context lines around `hunk.lnum`, anchor line highlighted) AND
Q3=**use gitsigns**. These are in direct tension and cannot both be honoured as
literally stated:

- gitsigns' preview APIs (`preview_hunk`, `preview_hunk_inline`) render the
  **diff** of a hunk against the gitsigns base. They operate on the
  **currently-open file buffer at the cursor** — they cannot show plain file
  content for an arbitrary `path#lnum` reference, and they require the target
  file to already be the current buffer (i.e. the file must be opened first,
  with gitsigns attached and `change_base` set — exactly the disruptive flow
  `open_file_diff` already does for `gd`).
- So "show file content" (b) and "delegate to gitsigns" cannot coexist in one
  preview. Confirmed against the source: `review.open_file_diff` /
  `jump_to_hunk_under_cursor` already `pcall(require, "gitsigns")` +
  `gs.change_base(base, true)` then `:edit` the file; gitsigns has no
  content-preview-by-path API.

Real options:

- **(i) Self-contained file-content float** — honour Q1=b literally. Read the
  working-tree file (`vim.fn.readfile` / the buffer), show ±N context lines
  around `lnum` with the anchor highlighted, source-file filetype for syntax.
  gitsigns is NOT involved in the preview (Q3 treated as not applicable to a
  content preview). Most "non-disruptive": no file is opened, no base mutation.
- **(ii) gitsigns diff preview** — reinterpret/override Q1=b. Open & load the
  target file buffer, set gitsigns base, then call gitsigns' preview. Shows the
  diff hunk, not file content. Less non-disruptive (opens the file, mutates the
  gitsigns base globally).
- **(iii) Hybrid** — e.g. self-contained float that renders a diff computed by
  gtd itself (no gitsigns), or content-by-default with a toggle to diff.

The plan body below assumes **(i) self-contained file-content float**, as the
only option that satisfies both Q1=b and the "quick / non-disruptive preview"
intent of the request, treating "use gitsigns" as not applicable to a
content-only preview. Confirm (i), or redirect to (ii)/(iii):

<!-- user answers here -->

### Q8 — Anchor-line edge cases (Q1=b specifics)

Q1=b opens a few behavioural choices. Proposed defaults (folded into the plan
body unless you change them here):

- **Context window:** ±10 lines around `lnum` (anchor centred where possible).
- **Near file start/end:** clamp the window to `[1, line_count]` (still ±10 of
  total span, anchor not necessarily centred at edges).
- **File missing / `lnum` out of range:** notify + abort (no float).
- **Anchor highlight:** highlight the anchor line in the float with a
  `CursorLine`-like highlight via `nvim_buf_add_highlight` on the line's row in
  the scratch buffer (computed from where `lnum` lands in the clamped window).

Accept these defaults, or change any:

<!-- user answers here -->

## Plan body

Assumes: Q1=(b) working-tree file content, Q2=cursor-anchored auto-sized float,
Q7=(i) self-contained float (gitsigns NOT used for the content preview),
Q4=no-op on heading, Q5=source-file filetype for syntax, Q6=`preview_hunk`
buffer-local, Q8 defaults (±10 ctx, clamp, notify-on-missing, anchor highlight).

### New: `review.preview_hunk_under_cursor()` in `lua/gtd/review.lua`

- Parse the hunk line under cursor with `parse_hunk_line` (reuse). If nil →
  notify "no hunk on current line" and return (Q4 no-op), mirroring
  `jump_to_hunk_under_cursor` / `toggle_done`.
- Resolve repo root via `git.get_root()`. If nil → error notify.
- Build the absolute path (`root .. "/" .. hunk.path`). Read the working-tree
  file content:
  - Prefer an already-loaded buffer for that path (`vim.fn.bufnr(abs_path)`);
    else `vim.fn.readfile(abs_path)`.
  - If the file does not exist / unreadable → notify "file not found" + abort
    (Q8).
- Determine the context window: `lnum = hunk.lnum`; if `lnum < 1` or
  `lnum > #file_lines` → notify "line out of range" + abort (Q8). Else
  `start = max(1, lnum - 10)`, `finish = min(#file_lines, lnum + 10)`; slice
  those lines (Q8 clamp).
- No more `git.diff_hunk` helper is needed (this is file content, not a diff).
  gitsigns is NOT called.
- Build a scratch buffer (`nvim_create_buf(false, true)`), set lines to the
  sliced context, set `modifiable=false`.
- Set the float buffer filetype to the SOURCE FILE's filetype so it highlights
  as code (Q5): derive via `vim.filetype.match({ filename = abs_path })` (fall
  back to matching on `buf`/`contents` if needed), set `bo[buf].filetype`.
- Highlight the anchor line (Q8): the anchor's 0-based row in the scratch buffer
  is `lnum - start`; apply a `CursorLine`-like highlight to that row via
  `nvim_buf_add_highlight` (e.g. an `hl_group` of `CursorLine` / a small custom
  group) across the whole line.
- Open a floating window anchored at cursor (Q2): `relative="cursor"`,
  `row=1, col=0`, size = min(content, max) with max height ~20 and max width
  ~100 (width from longest sliced line), `border="rounded"`, `style="minimal"`.
- Register dismissal (Q2): one-shot `CursorMoved` autocmd in REVIEW.md to close
  the float, plus buffer-local `q` / `<Esc>` maps in the float buffer.
- Track the open float win id in a module-local so a repeated `<leader>k` closes
  the previous float first, then re-opens for the new line (no orphan floats)
  (Q2).

### Wiring: `lua/gtd/init.lua`

- Add `preview_hunk = "<leader>k"` to `defaults.keys` (Q6).
- In `M.setup_buffer_keymaps`, inside the REVIEW.md branch (beside
  `jump_to_hunk`), add a buffer-local `n` map for `keys.preview_hunk` calling
  `review.preview_hunk_under_cursor()`, desc "gtd: preview hunk under cursor".
  Guard with `if keys.preview_hunk then` so users can disable it (Q6).
- No global map and no `lazy_keys()` entry — buffer-local only (Q6).

### Tests: `tests/test_review_preview.lua` (new)

- `preview_hunk_under_cursor`: in a fake REVIEW.md buffer with the cursor on a
  hunk line pointing at a temp source file, assert a float window opens with the
  expected sliced lines (±10 around `lnum`, clamped at edges) and the source
  file's `filetype` set.
- Assert the anchor row carries the highlight (inspect extmarks/highlights at
  `lnum - start`).
- Assert no-op + notify when the cursor is on a `## chunk` heading (Q4),
  mirroring `tests/test_review_jump.lua` patterns.
- Assert notify + no float when the source file is missing and when `lnum` is
  out of range (Q8).

### README

- Document the `<leader>k` preview map and the `preview_hunk` config key, and
  keep the README keymap table in sync (required).

## Resolved

### Q1 — What does the preview SHOW?

**Answer:** (b) current file content — N working-tree context lines centred on
`hunk.lnum` (±10), anchor line highlighted. NOT a git diff. No `git.diff_hunk`
helper; read the working tree directly (`vim.fn.readfile` or the buffer).

### Q2 — Presentation and dismissal

**Answer:** agreed — cursor-anchored, auto-sized float (max ~20 rows / ~100
cols), closed on the next `CursorMoved` in REVIEW.md or `q` / `<Esc>` when focus
is in the float; repeated `<leader>k` re-opens for the new line.

### Q3 — Implementation dependency

**Answer:** use gitsigns — BUT this conflicts with Q1=b (see open Q7). gitsigns
cannot render plain file content for a `path#lnum` reference; its preview APIs
show a diff of the currently-open buffer. Conflict surfaced as Q7; plan body
defaults to a self-contained float (gitsigns not used for the content preview)
pending confirmation.

### Q4 — Cursor on a `## chunk` heading

**Answer:** agreed — no-op + gentle notify, mirroring `gd`'s "no hunk on current
line" behaviour.

### Q5 — Syntax highlighting in the preview buffer

**Answer:** agreed — since Q1=b, set the float buffer filetype to the SOURCE
file's filetype (via `vim.filetype.match`) so it highlights as code.

### Q6 — Config key name

**Answer:** agreed — `preview_hunk = "<leader>k"`, registered buffer-local in
REVIEW.md (in `M.setup_buffer_keymaps`, beside `jump_to_hunk`); NOT a global
map.
