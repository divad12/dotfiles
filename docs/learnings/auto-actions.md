# Learning Auto-Actions

- 2026-05-05 executor: dotfiles run started (no `manual-executor-ran: 2026-05-05` marker found).
- 2026-05-05 executor: dotfiles had no pending decisions (`docs/learnings/decisions.jsonl` empty) and no prepared candidates/drafts to execute.
- 2026-05-05 executor: regenerated `docs/learnings/dashboard.md` + `docs/learnings/dashboard.html` via `bin/learn dashboard`.
- 2026-05-05 executor: verification: `.agents/skills/learn/tests/structural-check.sh` passed.
- 2026-05-05 executor: verification: `python3 -m pytest setup/tests/test_learn_cli.py -q` failed (2 tests) because the sandbox blocks binding a local HTTP server (`PermissionError: [Errno 1] Operation not permitted` when binding `127.0.0.1`).
- 2026-05-05 executor: journology repo detected at `/Users/david/Dropbox (Personal)/code/journology`, but executor actions were skipped because this environment is read-only outside the dotfiles writable roots (cannot append audit lines or regenerate dashboards there).
decision: archive 83b06990aeb2 triage 2026-05-06: already covered by canonical /learn front-door contract, pointer-only README, and structural check; cluster: productized learning front door
archive: 83b06990aeb2 triage 2026-05-06: already covered by canonical /learn front-door contract, pointer-only README, and structural check; cluster: productized learning front door
decision: archive 65a9dbb0b3b5 triage 2026-05-06: already covered by automation prompts plus structural check; cluster: workflow guarantees must be wired and verified
archive: 65a9dbb0b3b5 triage 2026-05-06: already covered by automation prompts plus structural check; cluster: workflow guarantees must be wired and verified
decision: archive 755a268f4869 triage 2026-05-06: semantic dedupe vs fingerprint identity is already stated in docs and skill contract; cluster: agent-owned clustering
archive: 755a268f4869 triage 2026-05-06: semantic dedupe vs fingerprint identity is already stated in docs and skill contract; cluster: agent-owned clustering
decision: archive 8fa091b8f04e triage 2026-05-06: task-observer now routes durable learnings to the learning store and reserves observations for fallback; cluster: observer as sensor
archive: 8fa091b8f04e triage 2026-05-06: task-observer now routes durable learnings to the learning store and reserves observations for fallback; cluster: observer as sensor
decision: archive 23031c089efa triage 2026-05-06: repo-scoped automation is already in triage/executor prompts and structural check; cluster: workflow guarantees must be wired and verified
archive: 23031c089efa triage 2026-05-06: repo-scoped automation is already in triage/executor prompts and structural check; cluster: workflow guarantees must be wired and verified
decision: archive 631e0a957ad5 triage 2026-05-06: readable required/proposed prevention artifact list is already in docs, skill, and structural check; cluster: prevention artifacts as enforceable contracts
archive: 631e0a957ad5 triage 2026-05-06: readable required/proposed prevention artifact list is already in docs, skill, and structural check; cluster: prevention artifacts as enforceable contracts
decision: archive f25da97943c6 triage 2026-05-06: triage and executor configs now use gpt-5.5 high reasoning and docs cover parent/subagent model policy; cluster: judgment-heavy automation model policy
archive: f25da97943c6 triage 2026-05-06: triage and executor configs now use gpt-5.5 high reasoning and docs cover parent/subagent model policy; cluster: judgment-heavy automation model policy
decision: archive 08c2d3bc8cf3 triage 2026-05-06: duplicate of b1ade9e50ec0 with less complete refs; merged as duplicate evidence into canonical-doc-path cluster
archive: 08c2d3bc8cf3 triage 2026-05-06: duplicate of b1ade9e50ec0 with less complete refs; merged as duplicate evidence into canonical-doc-path cluster
decision: archive b1ade9e50ec0 triage 2026-05-06: canonical durable master checkout path is already in automation prompts and structural check; cluster: workflow guarantees must be wired and verified
archive: b1ade9e50ec0 triage 2026-05-06: canonical durable master checkout path is already in automation prompts and structural check; cluster: workflow guarantees must be wired and verified
decision: archive 00e184061921 triage 2026-05-06: global learn --repo glue is already in git/learning docs, learn skill, and structural check; cluster: productized learning front door
archive: 00e184061921 triage 2026-05-06: global learn --repo glue is already in git/learning docs, learn skill, and structural check; cluster: productized learning front door
decision: archive 6dd075d24cef triage 2026-05-06: final git status after browser/review-server state is already in git docs and structural check; cluster: landing state must include generated review state
archive: 6dd075d24cef triage 2026-05-06: final git status after browser/review-server state is already in git docs and structural check; cluster: landing state must include generated review state
- 2026-05-06 triage: structural learning check passed, so all 11 open dotfiles learning rows were classified as already-covered, stale, or duplicate evidence rather than new executor work.
- 2026-05-06 triage: clusters closed today were productized learning front door, wired workflow guarantees, observer-as-sensor routing, prevention artifact contracts, automation model policy, and generated review-state landing checks.
- 2026-05-06 triage: no candidate actions or draft plans were prepared because the referenced docs, skills, automation configs, and structural check already cover the prevention artifacts.
- 2026-05-06 triage: regenerated docs/learnings/dashboard.md and docs/learnings/dashboard.html for dotfiles.
- 2026-05-06 triage: dashboard server could not start because this sandbox blocks binding 127.0.0.1; use the regenerated dashboard.html file for review.
- 2026-05-06 triage: recorded 08c2d3bc8cf3 as duplicate evidence on the retained b1ade9e50ec0 archive record.
- 2026-05-06 executor: dotfiles run started (no `manual-executor-ran: 2026-05-06` marker found).
- 2026-05-06 executor: inspected candidates, inbox, calibration, decisions, and triage audit notes; no prepared candidate actions, draft plans, or saved decisions were present.
- 2026-05-06 executor: no prevention artifacts were executed because triage classified the dotfiles learning rows as already-covered, stale, or duplicate evidence.
- 2026-05-06 executor: initial dashboard refresh command failed because `--repo` was placed after the `dashboard` subcommand; reran with `bin/learn --repo "$PWD" dashboard`.
- 2026-05-06 executor: regenerated `docs/learnings/dashboard.md` and `docs/learnings/dashboard.html` for dotfiles.
- 2026-05-06 executor: verification: `.agents/skills/learn/tests/structural-check.sh` passed.
- 2026-05-06 executor: verification: `python3 -m pytest setup/tests/test_learn_cli.py -q` failed 2 dashboard-server tests after 33 passed because this sandbox did not emit a local `127.0.0.1` server URL.
decision: archive d12111e6daf4 Done: .codex/automations/*.toml are tracked in dotfiles, symlink.sh wires ~/.codex/automations -> dotfiles, and structural-check.sh verifies the prompts.
archive: d12111e6daf4 Done: .codex/automations/*.toml are tracked in dotfiles, symlink.sh wires ~/.codex/automations -> dotfiles, and structural-check.sh verifies the prompts.
decision: archive 02b34308afad Done: both triage and executor automation.toml now run git diff --check + create one local commit + 'do not leave a successful run dirty'.
archive: 02b34308afad Done: both triage and executor automation.toml now run git diff --check + create one local commit + 'do not leave a successful run dirty'.
decision: archive 83b06990aeb2 Done: capture reasoning lives in /learn and docs/ai/learning-system.md; docs/learnings/README is pointer-only.
archive: 83b06990aeb2 Done: capture reasoning lives in /learn and docs/ai/learning-system.md; docs/learnings/README is pointer-only.
decision: archive bd3fb5f75282 Done: learning-system.md and learn SKILL both say fingerprint matching is row-id only and semantic dedupe is agent-owned.
archive: bd3fb5f75282 Done: learning-system.md and learn SKILL both say fingerprint matching is row-id only and semantic dedupe is agent-owned.
decision: archive 9f76a57015e7 Done: task-observer SKILL declares the learning store is the durable destination and routes through /learn; observation files are fallback only.
archive: 9f76a57015e7 Done: task-observer SKILL declares the learning store is the durable destination and routes through /learn; observation files are fallback only.
decision: archive b27c9463bf75 Done: both automation TOMLs say 'operate on the current working directory only' and refuse to touch sibling configured repos.
archive: b27c9463bf75 Done: both automation TOMLs say 'operate on the current working directory only' and refuse to touch sibling configured repos.
decision: archive 053992e19e3d Done: bin/learn stores prevention work as one list with required/proposed markers; learning-system.md and learn SKILL teach the same shape.
archive: 053992e19e3d Done: bin/learn stores prevention work as one list with required/proposed markers; learning-system.md and learn SKILL teach the same shape.
decision: archive 60fa957fe0f0 Done: both automations run on gpt-5.5 with reasoning_effort = high.
archive: 60fa957fe0f0 Done: both automations run on gpt-5.5 with reasoning_effort = high.
decision: archive 08c2d3bc8cf3 Done: both automations read /Users/david/Dropbox (Personal)/code/dotfiles/docs/ai/learning-system.md (the master worktree path).
archive: 08c2d3bc8cf3 Done: both automations read /Users/david/Dropbox (Personal)/code/dotfiles/docs/ai/learning-system.md (the master worktree path).
decision: archive b1ade9e50ec0 Done: duplicate of 08c2d3bc8cf3 — same prevention now in place via the master-path automation prompts.
archive: b1ade9e50ec0 Done: duplicate of 08c2d3bc8cf3 — same prevention now in place via the master-path automation prompts.
decision: archive 9681e329c380 Done: learn is on PATH; merge skill, git.md, and learn SKILL all use 'learn --repo "$PWD"' rather than repo-local bin/learn.
archive: 9681e329c380 Done: learn is on PATH; merge skill, git.md, and learn SKILL all use 'learn --repo "$PWD"' rather than repo-local bin/learn.
decision: archive 5301da11e4f9 Done: docs/ai/git.md 'Before-Landing Learning Check' explicitly requires re-running git status --short after browser/review-server tools.
archive: 5301da11e4f9 Done: docs/ai/git.md 'Before-Landing Learning Check' explicitly requires re-running git status --short after browser/review-server tools.
