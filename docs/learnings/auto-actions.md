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
decision: archive 04e0529e5585 Done: required learning-system wiring is enforced by canonical docs, live automation prompts, and the learn structural check; remaining executor dashboard-serving parity is tracked as a draft plan.
archive: 04e0529e5585 Done: required learning-system wiring is enforced by canonical docs, live automation prompts, and the learn structural check; remaining executor dashboard-serving parity is tracked as a draft plan.
decision: draft-plan e4ffe1d2e3a0 Prototype executor parity: add a failing structural check that the executor prompt says not to serve a live dashboard, then add the file-only dashboard sentence to the canonical/live executor automation. Blocked this run because sandbox denied writes to .agents and .codex files.
draft-plan: e4ffe1d2e3a0 wrote drafts/e4ffe1d2e3a0-plan.md
draft-plan: e4ffe1d2e3a0 TDD/review task marker created
decision: archive 627a97bbdbbc Done: docs, learn skill, executor prompt, and structural check now require act-by-default/autopick behavior, local commits, and true-product-choice escalation only.
archive: 627a97bbdbbc Done: docs, learn skill, executor prompt, and structural check now require act-by-default/autopick behavior, local commits, and true-product-choice escalation only.
decision: archive 29b7632b5c3b Done: docs, learn skill, triage/executor prompts, and structural check now require baseline dirty snapshots, untouched baseline paths, and staging only automation-owned changes.
archive: 29b7632b5c3b Done: docs, learn skill, triage/executor prompts, and structural check now require baseline dirty snapshots, untouched baseline paths, and staging only automation-owned changes.
- 2026-05-07 executor: dotfiles run started with baseline dirty path `.claude/settings.json`; left it untouched and unstaged.
- 2026-05-07 executor: archived 04e0529e5585, 627a97bbdbbc, and 29b7632b5c3b because their prevention artifacts are already enforced by docs, automation prompts, and structural checks.
- 2026-05-07 executor: prototyped e4ffe1d2e3a0 as `docs/learnings/drafts/e4ffe1d2e3a0-plan.md` for executor file-only dashboard parity.
- 2026-05-07 executor: attempted the TDD structural-check slice for e4ffe1d2e3a0, but this sandbox denied writes to `.agents/skills/learn/tests/structural-check.sh` and `.codex/automations/daily-learning-executor/automation.toml`; kept the next patch as a draft plan instead.
- 2026-05-07 executor: regenerated `docs/learnings/dashboard.md` and `docs/learnings/dashboard.html` for dotfiles via `bin/learn --repo "$PWD" dashboard`.
- 2026-05-07 executor: verification: `git diff --check -- <automation-owned learning paths>` passed.
- 2026-05-07 executor: verification: `.agents/skills/learn/tests/structural-check.sh` passed against the existing enforced learning contracts.
decision: archive 8d3cf8846396 Done: the learning structural check now runs python3 -m py_compile bin/learn, so syntax mistakes like backslash escapes inside f-string expressions fail before the dashboard glue ships.
archive: 8d3cf8846396 Done: the learning structural check now runs python3 -m py_compile bin/learn, so syntax mistakes like backslash escapes inside f-string expressions fail before the dashboard glue ships.
decision: archive e4ffe1d2e3a0 Done: the learning docs, learn skill, triage prompt, executor prompt, and structural check now keep cron automations file-only; the live dashboard stays user-owned through learn live.
archive: e4ffe1d2e3a0 Done: the learning docs, learn skill, triage prompt, executor prompt, and structural check now keep cron automations file-only; the live dashboard stays user-owned through learn live.
decision: archive 88d602ab001f Done: global AGENTS guidance, learning docs, learn skill, triage/executor prompts, and structural checks now require context-rich friendly plain-English reports instead of terse technical bullets.
archive: 88d602ab001f Done: global AGENTS guidance, learning docs, learn skill, triage/executor prompts, and structural checks now require context-rich friendly plain-English reports instead of terse technical bullets.
