# Learning Auto-Actions

- 2026-05-05 executor: dotfiles run started (no `manual-executor-ran: 2026-05-05` marker found).
- 2026-05-05 executor: dotfiles had no pending decisions (`docs/learnings/decisions.jsonl` empty) and no prepared candidates/drafts to execute.
- 2026-05-05 executor: regenerated `docs/learnings/dashboard.md` + `docs/learnings/dashboard.html` via `bin/learn dashboard`.
- 2026-05-05 executor: verification: `.agents/skills/learn/tests/structural-check.sh` passed.
- 2026-05-05 executor: verification: `python3 -m pytest setup/tests/test_learn_cli.py -q` failed (2 tests) because the sandbox blocks binding a local HTTP server (`PermissionError: [Errno 1] Operation not permitted` when binding `127.0.0.1`).
- 2026-05-05 executor: journology repo detected at `/Users/david/Dropbox (Personal)/code/journology`, but executor actions were skipped because this environment is read-only outside the dotfiles writable roots (cannot append audit lines or regenerate dashboards there).
