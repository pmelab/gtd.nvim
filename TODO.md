# Plan

## Feature request

> i would like to be able to open hunks referenced in REVIEW.md in a quick
> preview somehow. ideally with <leader>k

## Open questions

Answer inline under each marker. The plan body below resolves each with a stated
default; confirming or changing it reshapes the plan.

### Q13 — Which hunk(s) does the float show?

A REVIEW.md hunk line is a single anchor `path#lnum`, but
`git diff <base> -- <path>` may emit MULTIPLE `@@` hunks for that file. Proposed
default: **show only the one diff hunk whose new-side range contains `lnum`**
(the line you anchored on), not the whole file's diff. The float also INCLUDES
the `@@ ... @@` header line (kept, not stripped) so the diff is well-formed and
`filetype=diff` highlights it correctly. Confirm, or request "show the whole
file's diff vs base" / "strip the @@ header":

agreed

## Plan body

Honours Q10 ("`<leader>k` does NOT switch buffer, stays in REVIEW.md").
`<leader>k` shows a quick diff-hunk preview floated at the cursor WITHOUT
leaving REVIEW.md. gitsigns is NOT used for this feature — gitsigns'
`preview_hunk` can only preview the hunk under the cursor in the CURRENT
window's buffer (no path/lnum API), so it cannot render an off-screen file's
diff while the cursor stays in REVIEW.md. gtd therefore computes the diff itself
and renders a self-contained, cursor-anchored float. This restores the original
Q1=(a) / "hybrid (iii)" self-contained-float idea and Q2's float + dismissal
design.

Assumes: Q4=no-op on heading; Q6=`preview_hunk` buffer-local in REVIEW.md;
Q13=show only the single hunk whose new-side range contains `lnum`, header kept.

### New: `git.diff_hunk(path, base, lnum)` in `lua/gtd/git.lua`

- Run git via the existing `M.git_command` runner (same `vim.system` + safety
  flags pattern; cwd = repo root). Command: `git diff <base> -- <path>` (path is
  root-relative; pass `cwd = root`, or resolve root via `M.get_root()` inside
  the helper — prefer accepting `root` so it stays a pure-ish, runner-stubbable
  function; otherwise call `get_root()`).
- Parse the unified diff stdout line by line. Track the current hunk: each
  `@@ -a,b +c,d @@ ...` header opens a hunk whose NEW-side range is `[c, c+d)`
  (when `,d` is omitted it defaults to 1). Collect the header line plus all
  following body lines (` `, `+`, `-`, `\` lines) until the next `@@` or EOF.
- Return the lines (header + body) of the hunk whose new-side range contains
  `lnum`, or `nil` if no hunk covers `lnum` (or git failed / empty diff).
- Pure-ish and unit-testable by stubbing the command runner (`M.git_command`).

### New: `review.preview_hunk_under_cursor()` in `lua/gtd/review.lua`

- Parse the hunk line under the cursor with `parse_hunk_line` (reuse). If nil →
  notify "gtd: no hunk on current line" + return (Q4 no-op), mirroring
  `jump_to_hunk_under_cursor` / `toggle_done`.
- Resolve `review_path = git.get_review_path()` and
  `base = git.get_base(review_path)` exactly as `jump_to_hunk_under_cursor`
  does. If no base → notify "gtd: could not resolve review base" + return.
- Call `git.diff_hunk(hunk.path, base, hunk.lnum)`. If nil/empty → notify "gtd:
  no changes at this line vs review base" + abort (no float). This is gtd's OWN
  no-hunk-at-line handling (formerly Q12 "let gitsigns notify").
- Build a scratch buffer (`nofile`, not listed) with the diff lines, set
  `filetype=diff` (Q5 — it's a diff, not source content) and `modifiable=false`.
- Open a cursor-anchored float over it: `relative="cursor"`, auto-size to
  content (clamp to ~20 rows / ~100 cols), `border="rounded"`,
  `style="minimal"`. Do NOT `nvim_set_current_win` to the float — the cursor
  STAYS in the REVIEW.md window (this is the core of Q10).
- Register dismissal: a one-shot `CursorMoved` autocmd in the REVIEW.md buffer
  plus buffer-local `q` / `<Esc>` maps in the float buffer, each closing the
  float window. Track the float win id in a module-local so a repeated
  `<leader>k` closes the prior float first before opening a new one.
- No gitsigns: `pcall(require, "gitsigns")` is never touched here; the feature
  has NO gitsigns dependency. The plugin keeps gitsigns soft-optional elsewhere
  (in `open_file_diff`) exactly as before.

### Wiring: `lua/gtd/init.lua`

- Add `preview_hunk = "<leader>k"` to `defaults.keys` (Q6).
- In `M.setup_buffer_keymaps`, inside the REVIEW.md branch (beside
  `jump_to_hunk`), add a buffer-local `n` map for `keys.preview_hunk` calling
  `review.preview_hunk_under_cursor()`, desc "gtd: preview hunk under cursor".
  Guard with `if keys.preview_hunk then` so users can disable it (Q6).
- No global map, no `lazy_keys()` entry — buffer-local only (Q6).

### Tests

`tests/test_git.lua` (or the existing git test file) for `diff_hunk`; a new
`tests/test_review_preview.lua` for the float — mirror
`tests/test_review_jump.lua`'s `stub` / `with_fake_root` style.

- `git.diff_hunk` with a canned unified diff (stub `M.git_command` to return a
  fixed multi-hunk diff): an in-range `lnum` returns the correct hunk's lines
  (including the `@@` header); an out-of-range `lnum` returns `nil`.
- `preview_hunk_under_cursor` happy path: cursor on a hunk line in a fake
  REVIEW.md buffer/window; stub `git.get_review_path` / `git.get_base` /
  `git.diff_hunk`. Assert a float window was opened, its buffer holds the
  expected diff lines, `filetype=diff` is set, AND the CURRENT window is still
  the REVIEW.md window (cursor did not move to the float).
- No-op + notify when the cursor is on a `## chunk` heading (Q4), mirroring
  `tests/test_review_jump.lua`.
- Notify + NO float when `diff_hunk` returns nil (assert no float window opened,
  notify mentions "no changes").

### README

- Document `<leader>k`: shows a quick diff-hunk preview floated at the cursor
  WITHOUT leaving REVIEW.md.
- State it has NO gitsigns requirement (gtd computes the diff itself).
- Add the `preview_hunk` config key and keep the README keymap table in sync.

## Resolved

### Q1 — What does the preview SHOW?

**Answer:** the diff hunk gtd computes itself (`git diff <base> -- <path>`,
single hunk containing `lnum`), rendered in a self-contained float. (Earlier
this was reinterpreted as gitsigns' diff under Q7=ii; that delegation is now
DROPPED — see Q3/Q7 below — because gitsigns cannot keep the cursor in
REVIEW.md.)

### Q2 — Presentation and dismissal

**Answer:** RESTORED. gtd builds its own cursor-anchored, auto-sized float
(`relative="cursor"`, `border="rounded"`, `style="minimal"`) and wires its own
dismissal: one-shot `CursorMoved` in REVIEW.md + buffer-local `q`/`<Esc>` in the
float, with a module-local tracking the float win so a repeat `<leader>k` closes
the prior float. (The Q7=ii gitsigns-owned-float answer is superseded.)

### Q3 — Implementation dependency

**Answer:** gitsigns delegation is DROPPED in favour of a self-contained diff
float, BECAUSE gitsigns cannot keep the user in REVIEW.md — its `preview_hunk`
only works on the current window's buffer and has no path/lnum API. This feature
now has NO gitsigns dependency; gitsigns stays soft-optional only for `gd`
(`open_file_diff`), unchanged.

### Q4 — Cursor on a `## chunk` heading

**Answer:** agreed — no-op + gentle notify, mirroring `gd`'s "no hunk on current
line" behaviour.

### Q5 — Syntax highlighting in the preview buffer

**Answer:** `filetype=diff` on the float's scratch buffer (the content is a
diff, not source).

### Q6 — Config key name

**Answer:** agreed — `preview_hunk = "<leader>k"`, registered buffer-local in
REVIEW.md (in `M.setup_buffer_keymaps`, beside `jump_to_hunk`); NOT a global
map.

### Q7 — CONFLICT resolution: file content vs gitsigns

**Answer:** gitsigns delegation (formerly chosen as ii) is DROPPED, BECAUSE it
cannot keep the cursor in REVIEW.md (Q10). The preview is a self-contained float
rendering a diff gtd computes itself via `git.diff_hunk` — the "hybrid (iii)"
option originally listed here. Reinstates Q1=(a) and Q2's float/dismissal
design.

### Q8 — Anchor-line edge cases

**Answer:** missing file / out-of-range / no-hunk-at-line → `git.diff_hunk`
returns nil → gtd notifies "no changes at this line vs review base" + aborts (no
float). gtd owns this check now (no gitsigns involvement).

### Q9 — Disruption model: do we leave REVIEW.md? (SUPERSEDED by Q10)

**Answer:** default-accepted as "leave REVIEW.md", but SUPERSEDED by Q10's
explicit free-text intent: there is NO file open and the cursor stays in
REVIEW.md, so Q9's "leave REVIEW.md" is REJECTED.

### Q10 — How is `<leader>k` different from `gd`? (DECISIVE)

**Answer:** the user wants `<leader>k` to NOT switch buffers and to remain in
REVIEW.md. This is the governing requirement and is why gitsigns delegation is
dropped (Q3/Q7) and the self-contained cursor-anchored diff float is used.
`<leader>k` = non-disruptive diff preview without leaving REVIEW.md; `gd` =
actually open the file.

### Q11 — Reuse `gd`'s global base mutation? (MOOT)

**Answer:** N/A. The preview does not use gitsigns and does not open the file,
so there is no `change_base` / global base mutation for `<leader>k`. The base
SHA is only read (via `get_base`) and passed to `git diff`.

### Q12 — Line not inside a tracked hunk (SUPERSEDED)

**Answer:** gtd handles no-hunk-at-line itself: when `git.diff_hunk` finds no
hunk covering `lnum`, gtd notifies "no changes at this line vs review base" and
opens no float. (Formerly "let gitsigns notify" — moot, gitsigns is not used.)
