Error in command line:
E5108: Lua: [string ":lua"]:1: attempt to call field 'run_file_at_cursor' (a nil value)
stack traceback:
	[string ":lua"]:1: in main chunk[1mTotal number of cases:[0m 94
[1mTotal number of groups:[0m 9

tests/test_git.lua: [1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m
tests/test_init.lua: [1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m
gtd: copied /private/var/folders/jc/_7rqk0_s2n9gf8xv833xwrfh0000gn/T/nvim.pmelab/NKfksY/0.lua:1[1;32mo[0m
gtd: no file — nothing copied[1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m
tests/test_review_jump.lua: [1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m
tests/test_review_parse.lua: [1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m
tests/test_review_preview.lua: [1;31mx[0m[1;32mo[0m[1;32mo[0m
tests/test_review_toggle.lua: 
<lders/jc/_7rqk0_s2n9gf8xv833xwrfh0000gn/T/nvim.pmelab/NKfksY/3.md" <_s2n9gf8xv833xwrfh0000gn/T/nvim.pmelab/NKfksY/3.md" 2L, 37B written[1;32mo[0m
<lders/jc/_7rqk0_s2n9gf8xv833xwrfh0000gn/T/nvim.pmelab/NKfksY/4.md" <_s2n9gf8xv833xwrfh0000gn/T/nvim.pmelab/NKfksY/4.md" 2L, 37B written[1;32mo[0m
<lders/jc/_7rqk0_s2n9gf8xv833xwrfh0000gn/T/nvim.pmelab/NKfksY/5.md" <_s2n9gf8xv833xwrfh0000gn/T/nvim.pmelab/NKfksY/5.md" 1L, 31B written[1;32mo[0m
<lders/jc/_7rqk0_s2n9gf8xv833xwrfh0000gn/T/nvim.pmelab/NKfksY/6.md" <_s2n9gf8xv833xwrfh0000gn/T/nvim.pmelab/NKfksY/6.md" 1L, 27B written
<lders/jc/_7rqk0_s2n9gf8xv833xwrfh0000gn/T/nvim.pmelab/NKfksY/6.md" <_s2n9gf8xv833xwrfh0000gn/T/nvim.pmelab/NKfksY/6.md" 1L, 27B written[1;32mo[0m[1;32mo[0m[1;32mo[0m
<lders/jc/_7rqk0_s2n9gf8xv833xwrfh0000gn/T/nvim.pmelab/NKfksY/7.md" <s2n9gf8xv833xwrfh0000gn/T/nvim.pmelab/NKfksY/7.md" 9L, 128B written[1;32mo[0m[1;32mo[0m
tests/test_todo_count.lua: [1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m
tests/test_todo_parse.lua: [1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m
tests/test_wiring.lua: [1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m[1;32mo[0m

[1mFails (1) and Notes (0)[0m
[1;31mFAIL[0m in tests/test_review_preview.lua | preview_hunk_under_cursor opens a cursor-relative float with diff content:
  [1mFailed expectation for equality.[0m
  Left:  2
  Right: 1
  Traceback:
    tests/test_review_preview.lua:89

