# Review: 4b825dc

<!-- base: 4b825dc642cb6eb9a060e54bf8d69288fbee4904 -->

## Open-or-refresh TODO/REVIEW keymaps

The headline feature of this session. Two global keymaps (`<leader>gt`,
`<leader>gr`) open TODO.md / REVIEW.md (or focus their existing window) and
force-reload from disk. A shared `open_or_focus_reload` helper resolves the
buffer, focuses its window if visible (else `:edit`), writes pending changes,
then runs `edit!` to discard the stale in-memory copy in favor of disk. Both
entry points resolve the path via `gtd.git`, warn (no jump) when the file is
missing, and TODO additionally refreshes the open-question count.

- [ ] ./lua/gtd/init.lua#99
- [ ] ./lua/gtd/init.lua#119
- [ ] ./lua/gtd/init.lua#135

## Wire keymaps into setup and defaults

Registers the two new keymaps: default lhs values in the `keys` table, global
`vim.keymap.set` calls in `setup`, and matching entries in the lazy.nvim
`lazy_keys` spec (now 5 entries).

- [ ] ./lua/gtd/init.lua#11
- [ ] ./lua/gtd/init.lua#210
- [ ] ./lua/gtd/init.lua#235

## Test the open-or-refresh feature

`test_init.lua` exercises the new functions end-to-end in a temp git repo:
opening the right buffer, and warning (without switching buffers) when files are
absent. `test_wiring.lua` asserts the global keymaps register by description and
that `lazy_keys` includes both entries.

- [ ] ./tests/test_init.lua#56
- [ ] ./tests/test_init.lua#70
- [ ] ./tests/test_init.lua#113
- [ ] ./tests/test_wiring.lua#101
- [ ] ./tests/test_wiring.lua#117

## Document new keymaps; add test-runner config

README gains feature/keymap rows for the open-or-refresh keys. `.gtdrc.yaml`
defines the headless test command, gating success on the reporter's "Fails (0)"
line since MiniTest's `+qa` always exits 0.

- [ ] ./README.md#65
- [ ] ./README.md#73
- [ ] ./.gtdrc.yaml#5

## Context: git helper module

Pre-existing. Wraps git with safety flags (`core.hooksPath=`, `gc.auto=0`),
resolves repo root and TODO.md/REVIEW.md paths, and extracts the review base SHA
from the `<!-- base: ... -->` marker. The new feature depends on
`get_todo_path`/`get_review_path` here.

- [ ] ./lua/gtd/git.lua#7
- [ ] ./lua/gtd/git.lua#41
- [ ] ./lua/gtd/git.lua#63

## Context: TODO open-questions module

Pre-existing. Parses the `## Open Questions` section, counts unanswered
placeholders (cached per git root), drives the `vim.ui.select` picker, and
publishes WARN diagnostics on unanswered `### ` headings.

- [ ] ./lua/gtd/todo.lua#19
- [ ] ./lua/gtd/todo.lua#73
- [ ] ./lua/gtd/todo.lua#135
- [ ] ./lua/gtd/todo.lua#195

## Context: REVIEW chunks module

Pre-existing. Parses `## ` chunks and `- [ ] ./path#NN` hunk lines, offers a
chunk picker, jumps to a hunk's source file (setting gitsigns base), and toggles
checkbox state with write-through.

- [ ] ./lua/gtd/review.lua#8
- [ ] ./lua/gtd/review.lua#50
- [ ] ./lua/gtd/review.lua#95
- [ ] ./lua/gtd/review.lua#123
- [ ] ./lua/gtd/review.lua#211

## Context: statusline, autocmds, integrations

Pre-existing init.lua surface: `statusline`/`open_questions_count` for
lualine/heirline, autocmds attaching buffer-local keymaps and refreshing the
count (BufWritePost, FocusGained, 5-min timer), and optional
`mini.icons`/`which-key` registration.

- [ ] ./lua/gtd/init.lua#55
- [ ] ./lua/gtd/init.lua#163
- [ ] ./lua/gtd/init.lua#249

## Context: pre-existing tests and fixtures

Pre-existing test suite covering git, todo parse/count, and review
parse/jump/toggle, plus the headless runner and TODO/REVIEW fixtures.

- [ ] ./tests/run.sh#25
- [ ] ./tests/test_git.lua#1
- [ ] ./tests/test_todo_parse.lua#1
- [ ] ./tests/test_review_toggle.lua#1

## Resolved

<!-- resolved items move here as the user works through the review -->
