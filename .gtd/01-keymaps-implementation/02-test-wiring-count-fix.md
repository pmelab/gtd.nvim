# Fix stale `lazy_keys()` count assertion in `tests/test_wiring.lua`

Adding two entries to `M.lazy_keys()` (sibling task `01-init-lua-open-refresh.md`)
makes `#spec` go from 3 to 5, which breaks the existing assertion. This fix MUST
ship in the SAME package so the tree ends GREEN.

## Description

In `tests/test_wiring.lua`, the test currently named
`"lazy_keys returns a table with 2 entries"` asserts `#spec == 3`. Update it:

- Rename the test key to reflect the new count (e.g.
  `"lazy_keys returns a table with 5 entries"`).
- Change `MiniTest.expect.equality(#spec, 3)` to `5`.

Do NOT add new behavioral tests here (those go in package 02) — this task only
keeps the existing suite green. Do not edit any other test or assertion.

## Acceptance criteria

- [ ] The `lazy_keys` count test asserts `#spec == 5`.
- [ ] The test name reflects 5 entries.
- [ ] Full suite passes once the sibling `init.lua` task is applied.

## Files to examine

- `tests/test_wiring.lua` lines 60-66 (the count test).

## Constraints / edge cases

- Edit ONLY `tests/test_wiring.lua`. This is the only test task in this package;
  it is file-disjoint from the init.lua task and the README task.
- Do not add the new-keymap-registration assertions here — those belong in
  package 02 (which also edits `test_wiring.lua`, so it must be a later package).
