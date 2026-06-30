# Keymap-registration + lazy_keys presence tests in `tests/test_wiring.lua`

Depends on package 01 (implementation) AND on the count-assertion fix from
package 01's `02-test-wiring-count-fix.md` already being in place. Adds the new
registration/presence assertions.

## Description

Append tests to `tests/test_wiring.lua` (MiniTest style, using the existing
`find_by_desc` / `find_by_lhs` helpers):

1. **setup() registers open_todo global keymap**: after `gtd.setup({})`,
   `vim.api.nvim_get_keymap("n")` contains an entry with
   `desc == "gtd: open/refresh TODO.md"`.

2. **setup() registers open_review global keymap**: same, with
   `desc == "gtd: open/refresh REVIEW.md"`.

3. **lazy_keys includes the two new entries**: after `gtd.setup({})`,
   `gtd.lazy_keys()` contains entries whose `desc` (the `.desc` field of the
   spec entry, i.e. `entry.desc`) equals `"gtd: open/refresh TODO.md"` and
   `"gtd: open/refresh REVIEW.md"`. (lazy_keys entries are positional tables:
   `entry[1]` = lhs, `entry[2]` = fn, `entry.desc` = desc.)

Do NOT touch the existing `#spec == 5` count assertion (it was fixed in package
01) — only add new tests.

## Acceptance criteria

- [ ] Test asserts a normal-mode keymap with `desc == "gtd: open/refresh TODO.md"` exists after `setup({})`.
- [ ] Test asserts a normal-mode keymap with `desc == "gtd: open/refresh REVIEW.md"` exists after `setup({})`.
- [ ] Test asserts `lazy_keys()` contains entries with both new `desc` strings.
- [ ] Full suite passes.

## Files to examine

- `tests/test_wiring.lua` (the only file this task edits) — reuse `find_by_desc`/`find_by_lhs`.
- `lua/gtd/init.lua` — `setup()` and `lazy_keys()` from package 01.

## Constraints / edge cases

- Edit ONLY `tests/test_wiring.lua` (file-disjoint from the sibling test-init task).
- `desc` strings must match the implementation byte-for-byte.
- Do not duplicate or alter the existing pick_*/count tests.
