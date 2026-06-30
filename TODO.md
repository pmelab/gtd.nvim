# TODO

add keyboard shortcuts for quickly opening/refreshing "TODO.md" and "REVIEW.md"

## Open Questions

no open questions — run gtd to plan

## Plan

Goal: add two global, overridable keymaps that open-or-refresh `TODO.md` and
`REVIEW.md` from anywhere in a git repo. Each file gets **one** key that does
both: it opens the file if not focused and reloads it from disk if already
focused (smart open-or-refresh). Both files reload from disk only — the plugin
never regenerates REVIEW.md (that is the external `gtd` tool's job). Keys are
global and, when invoked outside a git repo or with the target file missing,
`vim.notify` a WARN and do nothing.

### Architecture fit (from codebase reading)

- Keymap defaults live in `defaults.keys` in `lua/gtd/init.lua` (lines 3-12).
  Global keys are registered in `M.setup()` (lines 150-160) and mirrored in
  `M.lazy_keys()` (lines 179-186).
- File paths come from `git.get_todo_path(root)` / `git.get_review_path(root)`
  in `lua/gtd/git.lua` (both already exist); `git.get_root()` returns nil
  outside a repo.
- TODO refresh logic exists: `todo.refresh_count()` recomputes the cached count
  and re-publishes diagnostics for any loaded TODO.md buffer (`lua/gtd/todo.lua`
  lines 173-190).
- REVIEW.md has no refresh function; buffer-local keymaps for it are attached on
  `BufEnter` via `M.setup_buffer_keymaps` (init.lua lines 30-50), so opening the
  buffer auto-wires its keymaps — no extra wiring needed.
- Existing "open" pattern: pickers use `vim.cmd("edit " .. fnameescape(path))`
  and reuse an existing window via `bufwinid` when possible (todo.lua 117-126).

### Implementation steps

1. **Add a shared local reload helper in `lua/gtd/init.lua`** —
   `local function open_or_focus_reload(path)` — encapsulating the resolved
   open-or-refresh behaviour decided in the Open Questions:
   - Look up the buffer for `path` via `vim.fn.bufnr(path)`.
   - **Window focus (Q2 — agreed):** if the buffer is already shown in a window
     (`vim.fn.bufwinid(bufnr) ~= -1`), `vim.api.nvim_set_current_win(win)` to
     focus that window, mirroring `pick_open_questions` (todo.lua 117-126);
     otherwise `vim.cmd("edit " .. vim.fn.fnameescape(path))` in the current
     window.
   - **Reload from disk (Q1 — agreed, save-if-modified then `edit!`):** once the
     target buffer/window is current, check `vim.bo[bufnr].modified`. If
     modified, `:write` it first (`vim.cmd("write")`) so local edits are
     persisted, then `vim.cmd("edit!")` to force-reload the on-disk truth (this
     picks up any external/AI rewrite). If not modified, just
     `vim.cmd("edit!")`. Use `edit!` (not `:checktime`) — `:checktime` no-ops or
     prompts depending on `autoread`, whereas `edit!` deterministically reloads.

2. **Add two new functions in `lua/gtd/init.lua`** (the right home — `init.lua`
   already owns global keymaps and orchestration; `copy_location` is the
   precedent for a top-level `M.<action>` function):
   - `M.open_or_refresh_todo()`:
     - resolve path via `require("gtd.git").get_todo_path()`; nil → WARN notify
       ("gtd: no TODO.md found (not in a git repo)"), return.
     - if file missing on disk (`vim.fn.filereadable(path) == 0`) → WARN notify
       ("gtd: no TODO.md found"), return.
     - call `open_or_focus_reload(path)`, then
       `require("gtd.todo").refresh_count()` so count + diagnostics update.
   - `M.open_or_refresh_review()`:
     - resolve path via `get_review_path()`; nil/missing → friendly WARN notify
       ("gtd: no REVIEW.md (run a review first)").
     - call `open_or_focus_reload(path)` to open/focus and reload the generated
       content from disk. (REVIEW.md buffer-local keymaps already auto-attach on
       `BufEnter`, so no extra wiring needed there.)

3. **Add defaults** to `defaults.keys` in init.lua:
   - `open_todo = "<leader>gt"`
   - `open_review = "<leader>gr"`

4. **Register global keymaps** in `M.setup()` next to the existing `pick_*` /
   `copy_location` registrations, with the agreed `desc` strings (Q3 — agreed):
   - `open_todo` → `desc = "gtd: open/refresh TODO.md"`
   - `open_review` → `desc = "gtd: open/refresh REVIEW.md"` No extra which-key
     wiring needed — they live under the already-registered `<leader>g` group
     (registered in `M.register_icons()`).

5. **Add to `M.lazy_keys()`** so lazy.nvim users get lazy-loading on these keys,
   using the same agreed `desc` strings as step 4.

6. **Tests** (`tests/test_init.lua` + `tests/test_wiring.lua`, MiniTest,
   following existing style):
   - new key defaults present in `gtd.config.keys` after `setup({})`
     (`open_todo`, `open_review`).
   - `setup()` registers the two new global keymaps (assert by `desc`, mirroring
     the existing `pick_*` desc assertions in `test_wiring.lua`).
   - `open_or_refresh_todo` / `open_or_refresh_review` callable; in a temp git
     repo with a TODO.md/REVIEW.md fixture, the function opens the buffer
     (assert `nvim_buf_get_name` of current buf matches the path) and returns
     without error. Use the existing fixtures under `tests/fixtures/` (or create
     a temp repo with `git.git_command({"init"})`).
   - missing-file path: assert it notifies and does not open a buffer (stub
     `vim.notify` to capture the message, as is common in MiniTest).
   - **Update the stale `lazy_keys()` count assertion**: `test_wiring.lua`
     currently asserts `#spec == 3` (test named "lazy_keys returns a table with
     2 entries"). Adding two entries makes it 5 — bump the assertion to `5` and
     fix the test name. Add an assertion that the two new entries are present.

7. **README updates** (required by repo convention — every significant change
   reflected in README):
   - Add the two keys to the **Keymaps** table (`<leader>gt` → open/refresh
     TODO.md; `<leader>gr` → open/refresh REVIEW.md).
   - Add an **Open/refresh TODO & REVIEW** row to the **Features** table.
   - Add the two keys to both `keys = { ... }` override example blocks (the
     lazy.nvim `opts` block at lines 26-32 and the manual-setup block).

### Out of scope (unless an Open Question flips it)

- Regenerating REVIEW.md from inside the plugin (shelling out to the external
  `gtd` tool / git diff) — refresh is reload-from-disk only.
- A combined "refresh everything" command.

## Resolved

### Should "open" and "refresh" be one key each (toggle/smart) or two separate keys per file?

**Recommendation:** One key per file that does both: pressing it opens the file
(`:edit <path>`) if not already focused, and refreshes it if already focused.
This keeps the keymap surface small (2 new global keys) and matches how
`pick_open_questions`/`pick_chunks` already behave (jump-or-open). It also
sidesteps the question of what "refresh" means when the file isn't open. If
you'd rather have explicit control, we can do 4 keys (open/refresh ×
TODO/REVIEW) — but I recommend the 2-key smart approach.

**Answer:** One key per file (2 total), smart open-or-refresh.

### What does "refresh" actually mean for each file?

**Recommendation:** They differ:

- **TODO.md**: it is edited live in Neovim, so "refresh" = re-read from disk
  (`:checktime` / `:edit`) to pick up external edits (e.g. an AI agent rewrote
  it), then re-run `todo.refresh_count()` + `publish_diagnostics()` to update
  statusline/diagnostics.
- **REVIEW.md**: it is generated by an external `gtd` process, not hand-edited.
  "refresh" = reload the buffer from disk (`:edit`/`:checktime`) to show the
  newly generated content. We do NOT regenerate REVIEW.md from inside the plugin
  (that's the external tool's job) unless you say otherwise.

Confirm: should REVIEW refresh also shell out to regenerate it, or only reload
from disk? I recommend reload-only to keep the plugin free of git/diff
generation responsibility.

**Answer:** Both TODO and REVIEW should just reload from disk (no regeneration).

### Default keymaps — which keys, staying in the `<leader>g` namespace?

**Recommendation:** Add to `<leader>g` group, mnemonic by file:

- `<leader>gt` → open/refresh **T**ODO.md
- `<leader>gr` → open/refresh **R**EVIEW.md

Note `gd`/`gc`/`gy`/`gq`/`gp` are taken; `gt`/`gr` are free and mnemonic. (`gr`
is a Neovim default for LSP references in 0.11+, but only buffer-local;
`<leader>gr` is unaffected.) Both should be overridable via `setup({ keys })`
and surfaced in `lazy_keys()`, exactly like existing global keys.

**Answer:** Yes — use `<leader>gt` / `<leader>gr` defaults.

### Should these keys be global, and what happens outside a git repo?

**Recommendation:** Global (registered in `setup()`), same as the existing
pickers, since you want to jump to TODO/REVIEW from anywhere. If
`git.get_root()` returns nil (not in a repo) or the target file does not exist,
`vim.notify` a WARN and do nothing — mirroring `pick_open_questions`'s "no
TODO.md found" behaviour. For REVIEW.md specifically, a missing file is common
(no review in progress), so the notify message should be friendly: "gtd: no
REVIEW.md (run a review first)".

**Answer:** Agreed — global keys, with a WARN notify when outside a repo or the
target file is missing.

### How should the buffer be reloaded from disk, given `:checktime` only reloads when `autoread` is set (or prompts otherwise)?

**Recommendation:** Do not rely on `:checktime` (it no-ops or prompts depending
on `autoread`). Instead, when the target buffer is already loaded, force a
silent reload with `vim.cmd("edit! " .. fnameescape(path))`. Risk: `edit!` on
TODO.md would blow away _unsaved_ in-Neovim edits. To be safe: if the buffer is
modified, `:write` it first, otherwise `edit!`. I lean toward: save-if-modified
then reload, so an AI agent's external rewrite and your local edits both survive
where possible.

**Answer:** agreed — save-if-modified then reload: if the buffer is `modified`,
`:write` it first, then `vim.cmd("edit!")` (force reload from disk); not
modified → `edit!` directly. Do not use `:checktime`. (Integrated into the
reload helper, step 1.)

### "Open-or-refresh": when the file is loaded in another window/tab but not current, do we jump to that window or open in the current one?

**Recommendation:** Mirror `pick_open_questions`: if a window already shows the
buffer (`vim.fn.bufwinid(bufnr) ~= -1`), focus that window
(`nvim_set_current_win`) and then reload; otherwise `:edit` in the current
window. This keeps a single TODO/REVIEW view instead of duplicating it across
splits, matching the existing jump-or-open precedent.

**Answer:** agreed — focus the existing window via `vim.fn.bufwinid(bufnr)` +
`vim.api.nvim_set_current_win(win)` then reload; otherwise `:edit` in the
current window. Mirrors `pick_open_questions`. (Integrated into the reload
helper, step 1.)

### which-key/`desc` labels and discoverability for the two new keys?

**Recommendation:** Use `desc = "gtd: open/refresh TODO.md"` and
`desc = "gtd: open/refresh REVIEW.md"` for both the `setup()` registration and
the `lazy_keys()` entries, consistent with existing `gtd: ...` desc strings. No
extra which-key wiring needed — they live under the already-registered
`<leader>g` group.

**Answer:** agreed — `desc = "gtd: open/refresh TODO.md"` /
`desc = "gtd: open/refresh REVIEW.md"` on both `setup()` and `lazy_keys()`
entries; no extra which-key wiring (uses the existing `<leader>g` group).
(Integrated into steps 4 and 5.)
