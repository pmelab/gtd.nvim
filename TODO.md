# Plan

## Feature request

> i would like to be able to open hunks referenced in REVIEW.md in a quick
> preview somehow. ideally with <leader>k

## Open questions

Answer inline under each marker. The plan body below resolves each with a stated
default; confirming or changing it reshapes the plan. These questions are NEW —
they arise from choosing the gitsigns-diff approach (Q7=ii), which is inherently
more involved than the earlier file-content idea.

### Q9 — Disruption model: do we leave REVIEW.md?

gitsigns' `preview_hunk` previews the hunk under the cursor **in the current
window's buffer**. It has no path/lnum API, so to preview a `path#lnum` ref from
REVIEW.md we must actually OPEN that file (set gitsigns base, attach, move
cursor to `lnum`) and then call `preview_hunk`. The simplest correct flow is: do
exactly what `gd` does (`open_file_diff`), then immediately pop the gitsigns
hunk-preview float.

That means `<leader>k` LEAVES REVIEW.md (the file becomes the current buffer),
just like `gd`. Staying in the REVIEW.md window while floating an off-screen
file's diff is not something gitsigns can do.

Proposed default: **`<leader>k` == "do what `gd` does, then auto-pop the
gitsigns hunk preview float".** Accept (you end up in the file, with the diff
float open), or specify a different model:

<!-- user answers here -->

### Q10 — How is `<leader>k` different from `gd`?

If `<leader>k` opens the file (like `gd`) and additionally pops the gitsigns
preview float, the only difference from `gd` is the auto-popped float. Is that
the intended distinction, or did you expect `<leader>k` to be non-disruptive
(stay in REVIEW.md) — which gitsigns can't deliver for an off-screen file?

Proposed default: **`<leader>k` = `gd` + auto-popped `preview_hunk` float.** It
is "`gd` with the diff already shown". Confirm this is a useful enough
distinction, or redirect (e.g. drop the feature, or revisit the
self-contained-float option i):

<!-- user answers here -->

### Q11 — Reuse `gd`'s global base mutation?

`open_file_diff` already calls `gs.change_base(base, true)` — the `true` makes
the gitsigns base **global** (affects all buffers). `<leader>k` reusing
`open_file_diff` inherits this side effect (same as `gd` today). Acceptable to
keep mutating the global base for the preview too?

Proposed default: **yes — reuse `open_file_diff` as-is, accept the same global
base mutation `gd` already performs.** Confirm or request a scoped base:

<!-- user answers here -->

### Q12 — Line not inside a gitsigns-tracked hunk

If `hunk.lnum` is on a line that gitsigns doesn't see as changed vs base,
`preview_hunk` no-ops / notifies "no current hunk". Let gitsigns handle/notify,
or pre-check in gtd?

Proposed default: **let gitsigns notify** (no gtd pre-check; gitsigns' own "no
current hunk" message is adequate). Confirm or request a gtd pre-check:

<!-- user answers here -->

## Plan body

Assumes: Q7=(ii) gitsigns diff preview; Q9=`<leader>k` does what `gd` does then
auto-pops the gitsigns hunk-preview float (leaves REVIEW.md); Q10=the
distinction from `gd` is exactly the auto-popped float; Q11=reuse
`open_file_diff`'s global `change_base`; Q12=let gitsigns notify on no-hunk;
Q4=no-op on heading; Q6= `preview_hunk` buffer-local in REVIEW.md.

### New: `review.preview_hunk_under_cursor()` in `lua/gtd/review.lua`

- Parse the hunk line under the cursor with `parse_hunk_line` (reuse). If nil →
  notify "no hunk on current line" and return (Q4 no-op), mirroring
  `jump_to_hunk_under_cursor` / `toggle_done`.
- Resolve the review base exactly as `jump_to_hunk_under_cursor` does:
  `review_path = git.get_review_path()`, `base = git.get_base(review_path)`. If
  nil → notify "could not resolve review base" + return.
- **Require gitsigns up front** (it is only a soft dependency elsewhere): if
  `pcall(require, "gitsigns")` fails (or `gs.preview_hunk` is absent) → notify
  "gtd: gitsigns required for preview" + abort (do NOT open the file). This is a
  deliberate change from `open_file_diff`, which silently skips gitsigns.
- Open the file via the existing `M.open_file_diff(hunk, base)`: this sets the
  global gitsigns base (Q11), `:edit`s the target file (Q9 — we leave
  REVIEW.md), and positions the cursor at `hunk.lnum`. We reuse it verbatim so
  `<leader>k` and `gd` share one open path.
- After the file is open and the cursor is on `hunk.lnum`, call
  `gitsigns.preview_hunk()` so the diff float pops automatically. gitsigns may
  need a moment after `:edit` to attach + apply the base; call inside a
  `vim.schedule(...)` (and/or `defer_fn`) so attach + signs are in place before
  the preview, then `pcall` the `preview_hunk` call so a transient failure just
  no-ops rather than erroring.
- If the cursor line is not inside a tracked hunk, gitsigns itself notifies "no
  current hunk" (Q12) — no gtd pre-check.

Net effect: `<leader>k` is "`gd`, then the gitsigns hunk-diff float is shown
automatically". No self-contained float, no `vim.filetype.match`, no manual
context slicing, no anchor highlight, no `CursorMoved` dismissal logic —
gitsigns owns the float and its lifecycle (it closes on the next cursor move /
its own maps). The earlier file-content machinery (Q1=b / Q8) is dropped.

### Wiring: `lua/gtd/init.lua`

- Add `preview_hunk = "<leader>k"` to `defaults.keys` (Q6).
- In `M.setup_buffer_keymaps`, inside the REVIEW.md branch (beside
  `jump_to_hunk`), add a buffer-local `n` map for `keys.preview_hunk` calling
  `review.preview_hunk_under_cursor()`, desc "gtd: preview hunk under cursor".
  Guard with `if keys.preview_hunk then` so users can disable it (Q6).
- No global map and no `lazy_keys()` entry — buffer-local only (Q6).

### Tests: `tests/test_review_preview.lua` (new)

Mirror `tests/test_review_jump.lua`'s stubbing style (stub helper,
`with_fake_root`), and additionally STUB gitsigns since the flow now depends on
it:

- Stub `package.loaded["gitsigns"]` (or inject a fake via the same `require`
  gitsigns returns) with a table exposing `change_base` and `preview_hunk`
  spies.
- `preview_hunk_under_cursor` happy path: cursor on a hunk line in a fake
  REVIEW.md buffer; stub `git.get_root` / `git.get_base`, intercept `vim.cmd`
  and cursor APIs (as the jump test does). Assert that:
  - the file was `:edit`ed at the expected root-relative path (i.e.
    `open_file_diff` behaviour),
  - the cursor was positioned at `hunk.lnum`,
  - `gitsigns.change_base` was called with the base and global=`true`,
  - `gitsigns.preview_hunk` was invoked (flush any `vim.schedule`/`defer_fn` in
    the test, e.g. `vim.wait`).
- No-op + notify when the cursor is on a `## chunk` heading (Q4), mirroring
  `tests/test_review_jump.lua`.
- gitsigns missing: with `require("gitsigns")` forced to fail (or `preview_hunk`
  absent), assert notify "gitsigns required" AND that NO file was opened
  (`vim.cmd` edit not called).
- No assertion about "no current hunk" handling — that path is gitsigns' own
  notify (Q12), out of gtd's control.

### README

- Document the `<leader>k` preview map and the `preview_hunk` config key.
- State clearly that `<leader>k` opens the referenced file (like `gd`) and then
  pops a gitsigns hunk-diff preview float, and that it **requires gitsigns**
  (unlike the rest of the plugin, where gitsigns is optional).
- Keep the README keymap table in sync (required).

## Resolved

### Q1 — What does the preview SHOW?

**Answer:** (b) file content — BUT this is now OVERRIDDEN by Q7=(ii). The
preview shows the **gitsigns diff hunk** (diff against the review base), not
working-tree file content. No file-content slicing, no `git.diff_hunk` helper.

### Q2 — Presentation and dismissal

**Answer:** superseded by Q7=(ii). The float is produced and owned entirely by
gitsigns' `preview_hunk` (its own sizing, border, and dismissal — closes on the
next cursor move / gitsigns' own maps). gtd no longer builds a cursor-anchored
float or wires `CursorMoved`/`q`/`<Esc>` dismissal.

### Q3 — Implementation dependency

**Answer:** use gitsigns — now HONOURED (Q7=ii). The preview delegates to
gitsigns' `preview_hunk`. gitsigns is consequently a HARD requirement for this
one feature: if absent, `<leader>k` notifies + aborts.

### Q4 — Cursor on a `## chunk` heading

**Answer:** agreed — no-op + gentle notify, mirroring `gd`'s "no hunk on current
line" behaviour.

### Q5 — Syntax highlighting in the preview buffer

**Answer:** superseded by Q7=(ii). Highlighting is whatever gitsigns'
`preview_hunk` renders — a diff-style float — not the source file's filetype.
gtd does not set a filetype or call `vim.filetype.match`.

### Q6 — Config key name

**Answer:** agreed — `preview_hunk = "<leader>k"`, registered buffer-local in
REVIEW.md (in `M.setup_buffer_keymaps`, beside `jump_to_hunk`); NOT a global
map.

### Q7 — CONFLICT resolution: file content vs gitsigns

**Answer:** (ii) gitsigns diff preview. This OVERRIDES Q1=(b) "file content".
The preview opens the target file (as `gd` does via `open_file_diff`), then
calls gitsigns' `preview_hunk` to pop the diff-hunk float. Reinterprets Q1/Q2/Q5
as above; honours Q3 ("use gitsigns").

### Q8 — Anchor-line edge cases

**Answer:** agreed in spirit, but mostly MOOT under Q7=(ii). Q8's ±10 context
window, edge clamping, and anchor highlight were written for the file-content
float (option i) — gitsigns renders the diff itself, so none of that applies.
Still applicable: missing file / out-of-range `lnum` → notify + abort (handled
by `open_file_diff`'s existing best-effort guards and the base/gitsigns checks).
