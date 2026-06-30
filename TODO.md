# Plan

## Captured input

These changes were captured as the starting point for this feature. Develop
them into a concrete plan and surface any open questions for the user.

```diff
diff --git a/TODO.md b/TODO.md
index ffd9dd0..a19d54a 100644
--- a/TODO.md
+++ b/TODO.md
@@ -17,7 +17,7 @@ recommend: if the buffer is modified, `:write` it first (or warn and skip the
 reload), otherwise `edit!`. I lean toward: save-if-modified then reload, so an
 AI agent's external rewrite and your local edits both survive where possible.
 
-<!-- user answers here -->
+agreed
 
 ### "Open-or-refresh": when the file is loaded in another window/tab but not current, do we jump to that window or open in the current one?
 
@@ -27,7 +27,7 @@ buffer (`vim.fn.bufwinid(bufnr) ~= -1`), focus that window
 window. This keeps a single TODO/REVIEW view instead of duplicating it across
 splits, matching the existing jump-or-open precedent.
 
-<!-- user answers here -->
+agreed
 
 ### which-key/`desc` labels and discoverability for the two new keys?
 
@@ -37,7 +37,7 @@ the `lazy_keys()` entries, consistent with existing `gtd: ...` desc strings. No
 extra which-key wiring needed — they live under the already-registered
 `<leader>g` group.
 
-<!-- user answers here -->
+agreed
 
 ## Plan
 
```
