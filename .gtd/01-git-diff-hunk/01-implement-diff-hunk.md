# Task: implement `git.diff_hunk(path, base, lnum)` in `lua/gtd/git.lua`

Add a new function to the `gtd.git` module that runs `git diff <base> -- <path>`,
parses the unified diff, and returns the lines of the single hunk whose NEW-side
range contains `lnum`.

## File
- `/Users/pmelab/Code/gtd/gtd.nvim/lua/gtd/git.lua` (ONLY this file)

## Signature & behaviour
```lua
--- Return the lines (header + body) of the single diff hunk (vs `base`) whose
--- new-side range contains `lnum`, or nil if none / git failed / empty diff.
--- @param path string   root-relative file path
--- @param base string   review base SHA
--- @param lnum number    1-based anchor line (new side)
--- @param root string|nil  optional repo root (defaults to M.get_root())
--- @return string[]|nil
function M.diff_hunk(path, base, lnum, root)
```

Implementation details (match existing conventions in this file):
- Resolve root: `root = root or M.get_root()`. If no root → return nil.
- Run git via the EXISTING runner: `M.git_command({ "diff", base, "--", path }, { cwd = root })`.
  Reuses `vim.system` + safety flags pattern. Keep `M.git_command` stub-testable
  (the test stubs `M.git_command`).
- If exit code ~= 0, or stdout is empty → return nil.
- Parse the unified-diff stdout line by line (split on `\n`):
  - A hunk header matches `^@@ %-%d+,?%d* %+(%d+),?(%d*) @@`. Extract new-side
    start `c` and length `d`. When `,d` is omitted, `d` defaults to 1.
    The new-side range is `[c, c + d)` (i.e. covers lines `c .. c+d-1`).
  - When a header opens a hunk: start collecting the header line plus all
    following body lines (lines beginning with ` `, `+`, `-`, or `\`) until the
    next `@@` header or EOF.
  - Skip the file-prelude lines (`diff --git`, `index`, `---`, `+++`) — they
    are not part of any hunk body.
- Return the collected lines (INCLUDING the `@@ ... @@` header) of the FIRST hunk
  whose new-side range `[c, c+d)` contains `lnum`. If no hunk covers `lnum` →
  return nil.

## Edge cases
- `,d` omitted in header (single-line change) → treat length as 1.
- A header with new-side length 0 (pure deletion, `+c,0`) → range is empty,
  never matches lnum.
- Multiple hunks: return only the one containing lnum.
- Empty / failed git → nil.

## Constraints
- Do NOT touch any other file. The test for this lives in `tests/test_git.lua`
  (a separate parallel task) and is written against THIS signature.
- Do NOT require gitsigns. No new module dependencies.
- `return M` stays at the end.

## Acceptance criteria
- [ ] `M.diff_hunk(path, base, lnum, root)` exists in `lua/gtd/git.lua`.
- [ ] Runs `git diff <base> -- <path>` through `M.git_command` with `cwd = root`.
- [ ] Returns the matching hunk's lines including the `@@` header for an in-range lnum.
- [ ] Returns nil when no hunk covers lnum, when git exits non-zero, or when diff is empty.
- [ ] Handles `@@ -a,b +c @@` (omitted new-side length defaults to 1).
- [ ] No other files modified; existing tests still pass.
