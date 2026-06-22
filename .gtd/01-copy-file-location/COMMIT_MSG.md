feat(copy): copy current file:line to clipboard for AI context

Add a <leader>gy global keymap and M.copy_location() that copies the
current buffer's repo-relative path plus cursor line as `path:line` to
the system clipboard, so it can be pasted into an AI agent for context.

- New configurable default key `copy_location` (<leader>gy)
- M.copy_location() writes to the + register, notifies, returns the string
- Wired into M.setup and M.lazy_keys
- Tests in tests/test_init.lua
- README: opts.keys example, features table, keymaps table

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
