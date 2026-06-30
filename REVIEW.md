# Review: 43b643e

<!-- base: 43b643e427c6bb227d38c7cd4f4fd71e9a64ea2d -->

## Add git.diff_hunk helper

New `git.diff_hunk(path, base, lnum, root)` runs `git diff <base> -- <path>`
itself and scans the output for the single hunk whose new-side range
(`@@ ... +c,d @@`) contains the anchor line. Returns just that hunk's
header+body lines, or nil on git failure, empty diff, or out-of-range line. This
is what lets the preview work without gitsigns.

- [ ] ./lua/gtd/git.lua#94

## Add cursor-anchored preview float

New `review.preview_hunk_under_cursor()` parses the checkbox hunk under the
cursor, resolves the review base, fetches the hunk via `git.diff_hunk`, and
renders it in a `relative="cursor"` `filetype=diff` scratch float opened without
focus (cursor stays in REVIEW.md). A module-level `preview_win` tracks the float
so it can be replaced; a one-shot `CursorMoved` autocmd dismisses it, and
`q`/`<Esc>` close it from inside. Notifies on no-hunk / unresolved base /
no-changes instead of opening an empty float.

- [ ] ./lua/gtd/review.lua#237

## Wire preview_hunk keymap + docs

Adds the `preview_hunk = "<leader>k"` default and binds it buffer-locally in
REVIEW.md buffers, and documents the keymap plus the "no gitsigns required"
feature in the README tables.

- [ ] ./lua/gtd/init.lua#10
- [ ] ./lua/gtd/init.lua#48
- [ ] ./README.md#62

## Tests for diff_hunk and preview

Unit tests for `diff_hunk` against a canned two-hunk diff (first/second hunk
selection, out-of-range nil, non-zero git code nil, empty output nil), plus a
new integration suite stubbing git to assert the float opens with diff content
while focus stays in REVIEW.md, and that heading lines and nil diffs notify
without opening a float.

- [ ] ./tests/test_git.lua#99
- [ ] ./tests/test_review_preview.lua#51
- [ ] ./tests/test_review_preview.lua#110
- [ ] ./tests/test_review_preview.lua#141
