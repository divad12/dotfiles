#!/bin/bash
set -e

SKILL=.agents/skills/learn/SKILL.md
DOC=docs/ai/learning-system.md
AGENTS=.claude/AGENTS.md

test -f "$SKILL" || { echo "FAIL: learn skill missing"; exit 1; }
test -f "$DOC" || { echo "FAIL: learning system doc missing"; exit 1; }
test -f "$AGENTS" || { echo "FAIL: global AGENTS missing"; exit 1; }
python3 -m py_compile bin/learn
test ! -e .agents/skills/capture-learning/SKILL.md || { echo "FAIL: capture-learning skill should not exist"; exit 1; }
grep -q "^name: learn$" "$SKILL" || { echo "FAIL: learn name"; exit 1; }
grep -q "^user-invocable: true$" "$SKILL" || { echo "FAIL: learn user-invocable"; exit 1; }
grep -q "document this.*capture this.*remember this for next time.*update the docs" "$SKILL" || { echo "FAIL: learn legacy capture triggers"; exit 1; }
grep -q "^## Store$" "$SKILL" || { echo "FAIL: Store section"; exit 1; }
grep -q "^## Capture$" "$SKILL" || { echo "FAIL: Capture section"; exit 1; }
grep -q "^## Dashboard$" "$SKILL" || { echo "FAIL: Dashboard section"; exit 1; }
grep -q "^## Agentic Maintenance$" "$SKILL" || { echo "FAIL: Agentic Maintenance section"; exit 1; }
grep -q "^## Before Merge$" "$SKILL" || { echo "FAIL: Before Merge section"; exit 1; }
grep -q "docs/ai/learning-system.md" "$SKILL" || { echo "FAIL: learning-system reference"; exit 1; }
grep -q "Only three user-facing front doors" "$SKILL" || { echo "FAIL: three front doors contract"; exit 1; }
grep -q "/learn.*capture.*dashboard.*learn-init" "$SKILL" || { echo "FAIL: command front doors"; exit 1; }
grep -q "Daily maintenance is split into Triage automation and Executor automation" "$SKILL" || { echo "FAIL: split automation contract"; exit 1; }
grep -q "🧠 Captured learning:" "$SKILL" || { echo "FAIL: capture announcement"; exit 1; }
grep -q "last five active learnings" "$SKILL" || { echo "FAIL: recent duplicate check"; exit 1; }
grep -q "same session" "$SKILL" || { echo "FAIL: session duplicate check"; exit 1; }
grep -q "plain-English" "$SKILL" || { echo "FAIL: plain-English contract"; exit 1; }
grep -q "Captured: YYYY-MM-DD" "$SKILL" || { echo "FAIL: captured date contract"; exit 1; }
! grep -q "dedupes overlapping captures" "$SKILL" || { echo "FAIL: misleading CLI dedupe claim"; exit 1; }
grep -q "not semantic dedupe" "$SKILL" || { echo "FAIL: semantic dedupe boundary"; exit 1; }
grep -q "Agents own semantic dedupe and clustering" "$SKILL" || { echo "FAIL: agent-only dedupe contract"; exit 1; }
grep -q "dashboard --serve --host 127.0.0.1 --port 0" "$SKILL" || { echo "FAIL: served dashboard contract"; exit 1; }
grep -q "dashboard --serve --execute-on-finish --host 127.0.0.1 --port 0" "$SKILL" || { echo "FAIL: finish dashboard contract"; exit 1; }
grep -q "decisions.jsonl" "$SKILL" || { echo "FAIL: decisions.jsonl contract"; exit 1; }
grep -q "Needs Review.*Open Items.*Auto Done.*Raw Inbox.*Candidates.*Aging/Stale.*Likely Duplicates.*Calibration Learned.*Blocked Decisions.*Ask Agent Prompts" "$SKILL" || { echo "FAIL: dashboard triage contract"; exit 1; }
grep -q "Action status" "$SKILL" || { echo "FAIL: dashboard action status contract"; exit 1; }
grep -q "What changed.*Next.*Blocked" "$SKILL" || { echo "FAIL: dashboard readable status buckets"; exit 1; }
grep -q "Aging/Stale is date-backed" "$SKILL" || { echo "FAIL: date-backed aging contract"; exit 1; }
grep -q "Additional evidence" "$SKILL" || { echo "FAIL: additional evidence contract"; exit 1; }
grep -q "Prevention artifacts: docs (required), test (required), skill (proposed)" "$SKILL" || { echo "FAIL: prevention artifacts contract"; exit 1; }
grep -q "archive.*candidate.*promote.*confidence.*prevention-artifact.*prevention-artifacts.*note.*calibration.*defer.*block.*revise-wording.*follow-up.*draft-plan.*draft-patch" "$SKILL" || { echo "FAIL: executor actions contract"; exit 1; }
grep -q "docs/learnings/drafts/<fingerprint>-plan.md.*docs/learnings/drafts/<fingerprint>-patch.md" "$SKILL" || { echo "FAIL: draft artifact contract"; exit 1; }
grep -q "TDD/review tasks" "$SKILL" || { echo "FAIL: TDD/review executor contract"; exit 1; }
grep -q "never silently edit code" "$SKILL" || { echo "FAIL: code decision guardrail"; exit 1; }
grep -q "mark code-related prevention as promoted" "$SKILL" || { echo "FAIL: code promotion guardrail"; exit 1; }
grep -q "Only three user-facing front doors" "$DOC" || { echo "FAIL: learning doc front doors"; exit 1; }
grep -q "The Abstraction Ladder" "$DOC" || { echo "FAIL: abstraction ladder moved to canonical doc"; exit 1; }
grep -q "Fingerprint matching is not semantic dedupe" "$DOC" || { echo "FAIL: learning doc fingerprint boundary"; exit 1; }
grep -q "Daily maintenance is split" "$DOC" || { echo "FAIL: learning doc daily automation"; exit 1; }
grep -q "Review is optional calibration, not a daily approval gate" "$DOC" || { echo "FAIL: learning doc hands-off review contract"; exit 1; }
grep -q "Let abstractions emerge from batches of evidence" "$DOC" || { echo "FAIL: learning doc sample-backed clustering contract"; exit 1; }
grep -q "Do not manufacture one guidance line per bug" "$DOC" || { echo "FAIL: learning doc no per-bug abstraction churn"; exit 1; }
grep -q "Action status" "$DOC" || { echo "FAIL: learning doc dashboard action status"; exit 1; }
grep -q "What changed.*Next.*Blocked" "$DOC" || { echo "FAIL: learning doc readable status buckets"; exit 1; }
grep -q "Use a frontier reasoning parent model" "$DOC" || { echo "FAIL: learning automation model policy"; exit 1; }
grep -q "gpt-5.5.*high reasoning" "$DOC" || { echo "FAIL: learning automation parent model"; exit 1; }
grep -q "gpt-5.3-codex" "$DOC" || { echo "FAIL: learning automation subagent model"; exit 1; }
grep -q "durable dotfiles master checkout" "$DOC" || { echo "FAIL: learning automation canonical checkout"; exit 1; }
grep -q "context-switched" "$DOC" || { echo "FAIL: learning doc context-rehydrating reports"; exit 1; }
grep -q "same shared calculation" "$DOC" || { echo "FAIL: learning doc translates jargon labels"; exit 1; }
grep -q "not terse corporate shorthand" "$DOC" || { echo "FAIL: learning doc rejects corporate shorthand"; exit 1; }
grep -q "Prevention artifacts: docs (required), test (required), skill (proposed)" "$DOC" || { echo "FAIL: learning doc prevention artifacts"; exit 1; }
grep -q "Skill and Doc Enforcement" "$DOC" || { echo "FAIL: skill/doc enforcement contract"; exit 1; }
grep -q "automatically loads the rule before implementation" "$DOC" || { echo "FAIL: automatic skill enforcement rationale"; exit 1; }
grep -q "write the failing test or structural check first" "$DOC" || { echo "FAIL: learning doc TDD automation"; exit 1; }
grep -q "Triage automation" "$DOC" || { echo "FAIL: triage automation contract"; exit 1; }
grep -q "Executor automation" "$DOC" || { echo "FAIL: executor automation contract"; exit 1; }
grep -q "Use subagents" "$DOC" || { echo "FAIL: subagent automation contract"; exit 1; }
grep -q "5pm" "$DOC" || { echo "FAIL: triage time contract"; exit 1; }
grep -q "9pm" "$DOC" || { echo "FAIL: executor time contract"; exit 1; }
grep -q "If the user says.*done" "$DOC" || { echo "FAIL: done trigger contract"; exit 1; }
grep -q "skip the scheduled 9pm executor" "$DOC" || { echo "FAIL: skip executor contract"; exit 1; }
grep -q "Each cron invocation is repo-scoped" "$DOC" || { echo "FAIL: learning doc repo-scoped automation"; exit 1; }
grep -q "Do not leave successful automation runs dirty" "$DOC" || { echo "FAIL: learning doc automation git hygiene"; exit 1; }
grep -q "snapshot baseline dirty paths" "$DOC" || { echo "FAIL: learning doc baseline dirty snapshot"; exit 1; }
grep -q "leave baseline dirty files untouched" "$DOC" || { echo "FAIL: learning doc preserves user dirt"; exit 1; }
grep -q "fix verification failures caused by its own changes" "$DOC" || { echo "FAIL: learning doc verification repair"; exit 1; }
grep -q "create one local commit" "$DOC" || { echo "FAIL: learning doc automation commit contract"; exit 1; }
grep -q "Do not push" "$DOC" || { echo "FAIL: learning doc automation no-push contract"; exit 1; }
grep -q "Plain English means context-rich and human" "$AGENTS" || { echo "FAIL: global user-facing plain English contract"; exit 1; }
grep -q "not terse or legalistic" "$AGENTS" || { echo "FAIL: global CEO wording correction"; exit 1; }
grep -q "same shared calculation" "$AGENTS" || { echo "FAIL: global jargon translation example"; exit 1; }

test -f .agents/skills/dashboard/SKILL.md || { echo "FAIL: dashboard skill missing"; exit 1; }
grep -q "^name: dashboard$" .agents/skills/dashboard/SKILL.md || { echo "FAIL: dashboard skill name"; exit 1; }
grep -q "dashboard --serve --execute-on-finish" .agents/skills/dashboard/SKILL.md || { echo "FAIL: dashboard finish loop"; exit 1; }
grep -q "manual-executor-ran: YYYY-MM-DD" .agents/skills/dashboard/SKILL.md || { echo "FAIL: dashboard done executor marker"; exit 1; }

test -f .agents/skills/learn-init/SKILL.md || { echo "FAIL: learn-init skill missing"; exit 1; }
grep -q "^name: learn-init$" .agents/skills/learn-init/SKILL.md || { echo "FAIL: learn-init skill name"; exit 1; }
grep -q "learn-init" .agents/skills/learn-init/SKILL.md || { echo "FAIL: learn-init command"; exit 1; }

grep -q "Capture landing learnings" .agents/skills/merge/SKILL.md || { echo "FAIL: merge learning capture"; exit 1; }
grep -q "last five active" docs/ai/git.md || { echo "FAIL: git learning duplicate check"; exit 1; }
grep -q "same-session captures" docs/ai/git.md || { echo "FAIL: git session duplicate check"; exit 1; }
grep -q "🧠 Captured learning:" docs/ai/git.md || { echo "FAIL: git capture announcement"; exit 1; }
grep -q 'invoke `/learn`' .agents/skills/task-observer/SKILL.md || { echo "FAIL: task-observer invokes learn"; exit 1; }
grep -q 'without waiting for the user to say `/learn`' .agents/skills/task-observer/SKILL.md || { echo "FAIL: task-observer ambient learn capture"; exit 1; }
grep -q "current repo's \`docs/learnings/\`" .agents/skills/task-observer/SKILL.md || { echo "FAIL: task-observer project learning destination"; exit 1; }
grep -q "dotfiles \`docs/learnings/\`" .agents/skills/task-observer/SKILL.md || { echo "FAIL: task-observer global learning destination"; exit 1; }
grep -q "The learning store is the durable destination" .agents/skills/task-observer/SKILL.md || { echo "FAIL: task-observer learning store primary"; exit 1; }
grep -q "Do not maintain a parallel durable backlog" .agents/skills/task-observer/SKILL.md || { echo "FAIL: task-observer no parallel backlog"; exit 1; }
grep -q "fallback or session audit trail" .agents/skills/task-observer/SKILL.md || { echo "FAIL: task-observer observation fallback"; exit 1; }
grep -q "task-observer is the ambient sensor" "$DOC" || { echo "FAIL: learning doc task-observer boundary"; exit 1; }
grep -q "learning store is the durable system" "$DOC" || { echo "FAIL: learning doc durable destination"; exit 1; }
grep -q "global \`learn --repo <repo>\` command" "$SKILL" || { echo "FAIL: learn skill global CLI contract"; exit 1; }
grep -q "learn --repo \"\$PWD\" check-merge" docs/ai/git.md || { echo "FAIL: git check-merge uses global learn"; exit 1; }
! grep -q "bin/learn --repo \"\$PWD\" check-merge" docs/ai/git.md || { echo "FAIL: git check-merge assumes repo-local bin/learn"; exit 1; }
grep -q "Use \`learn\`, not repo-local \`bin/learn\`" docs/ai/git.md || { echo "FAIL: git explains global learn rationale"; exit 1; }
grep -q "browser or review-server tools" docs/ai/git.md || { echo "FAIL: git final status after browser/review-server"; exit 1; }
grep -q "global \`learn --repo <repo>\`" "$DOC" || { echo "FAIL: learning doc global CLI contract"; exit 1; }

if rg -n "capture-learning|/capture-learning" .agents/skills SKILLS.md docs/ai docs/learnings --glob '!**/structural-check.sh'; then
  echo "FAIL: capture-learning reference remains"
  exit 1
fi

AUTOMATION_HOME="${CODEX_HOME:-$HOME/.codex}/automations"
CANONICAL_AUTOMATION_HOME=".codex/automations"
TRIAGE_AUTOMATION="$AUTOMATION_HOME/daily-learning-triage/automation.toml"
EXECUTOR_AUTOMATION="$AUTOMATION_HOME/daily-learning-executor/automation.toml"
test -f "$CANONICAL_AUTOMATION_HOME/daily-learning-triage/automation.toml" || { echo "FAIL: triage automation canonical copy missing"; exit 1; }
test -f "$CANONICAL_AUTOMATION_HOME/daily-learning-executor/automation.toml" || { echo "FAIL: executor automation canonical copy missing"; exit 1; }
grep -q ".codex/automations" symlink.sh || { echo "FAIL: symlink.sh mirrors codex automations"; exit 1; }
if test -f "$TRIAGE_AUTOMATION"; then
  test -L "$TRIAGE_AUTOMATION" || { echo "FAIL: triage automation live file should symlink to dotfiles"; exit 1; }
  grep -q "docs/ai/learning-system.md" "$TRIAGE_AUTOMATION" || { echo "FAIL: triage reads canonical learning doc"; exit 1; }
  grep -q "Abstraction Ladder" "$TRIAGE_AUTOMATION" || { echo "FAIL: triage applies abstraction ladder"; exit 1; }
  grep -q "sample-backed clusters" "$TRIAGE_AUTOMATION" || { echo "FAIL: triage clusters from samples"; exit 1; }
  grep -q "Do not manufacture one guidance line per bug" "$TRIAGE_AUTOMATION" || { echo "FAIL: triage avoids per-bug guidance churn"; exit 1; }
  grep -q "dashboard is optional calibration" "$TRIAGE_AUTOMATION" || { echo "FAIL: triage treats dashboard as optional"; exit 1; }
  grep -q "current working directory only" "$TRIAGE_AUTOMATION" || { echo "FAIL: triage scoped to current cwd"; exit 1; }
  grep -q "git status --short" "$TRIAGE_AUTOMATION" || { echo "FAIL: triage checks dirty worktree"; exit 1; }
  grep -q "baseline dirty paths" "$TRIAGE_AUTOMATION" || { echo "FAIL: triage snapshots baseline dirt"; exit 1; }
  grep -q "Do not touch or stage those baseline dirty paths" "$TRIAGE_AUTOMATION" || { echo "FAIL: triage preserves baseline dirt"; exit 1; }
  grep -q "fix the failure and rerun verification" "$TRIAGE_AUTOMATION" || { echo "FAIL: triage repairs verification failures"; exit 1; }
  grep -q "create one local commit" "$TRIAGE_AUTOMATION" || { echo "FAIL: triage commits successful changes"; exit 1; }
  grep -q "Do not push" "$TRIAGE_AUTOMATION" || { echo "FAIL: triage no-push contract"; exit 1; }
  grep -q "friendly plain-English summary" "$TRIAGE_AUTOMATION" || { echo "FAIL: triage plain-English reporting"; exit 1; }
  grep -q "Do not use.*Executed" "$TRIAGE_AUTOMATION" || { echo "FAIL: triage avoids bare executed report"; exit 1; }
  grep -q "context-switched" "$TRIAGE_AUTOMATION" || { echo "FAIL: triage rehydrates context"; exit 1; }
  grep -q "file paths and technical labels only as receipts" "$TRIAGE_AUTOMATION" || { echo "FAIL: triage uses files as receipts"; exit 1; }
  ! grep -q "stop before writing" "$TRIAGE_AUTOMATION" || { echo "FAIL: triage should not stop on baseline dirt"; exit 1; }
  ! grep -q "For each configured repo" "$TRIAGE_AUTOMATION" || { echo "FAIL: triage must not loop configured repos"; exit 1; }
fi
if test -f "$EXECUTOR_AUTOMATION"; then
  test -L "$EXECUTOR_AUTOMATION" || { echo "FAIL: executor automation live file should symlink to dotfiles"; exit 1; }
  grep -q "docs/ai/learning-system.md" "$EXECUTOR_AUTOMATION" || { echo "FAIL: executor reads canonical learning doc"; exit 1; }
  grep -q "Abstraction Ladder" "$EXECUTOR_AUTOMATION" || { echo "FAIL: executor applies abstraction ladder"; exit 1; }
  grep -q "Act by default" "$EXECUTOR_AUTOMATION" || { echo "FAIL: executor hands-off action contract"; exit 1; }
  grep -q "Do not wait for a daily dashboard review" "$EXECUTOR_AUTOMATION" || { echo "FAIL: executor no daily review gate"; exit 1; }
  grep -q "current working directory only" "$EXECUTOR_AUTOMATION" || { echo "FAIL: executor scoped to current cwd"; exit 1; }
  grep -q "git status --short" "$EXECUTOR_AUTOMATION" || { echo "FAIL: executor checks dirty worktree"; exit 1; }
  grep -q "baseline dirty paths" "$EXECUTOR_AUTOMATION" || { echo "FAIL: executor snapshots baseline dirt"; exit 1; }
  grep -q "Do not touch or stage those baseline dirty paths" "$EXECUTOR_AUTOMATION" || { echo "FAIL: executor preserves baseline dirt"; exit 1; }
  grep -q "fix the failure and rerun verification" "$EXECUTOR_AUTOMATION" || { echo "FAIL: executor repairs verification failures"; exit 1; }
  grep -q "create one local commit" "$EXECUTOR_AUTOMATION" || { echo "FAIL: executor commits successful changes"; exit 1; }
  grep -q "Do not push" "$EXECUTOR_AUTOMATION" || { echo "FAIL: executor no-push contract"; exit 1; }
  grep -q "Autopick the top one or two obvious high-leverage next actions" "$EXECUTOR_AUTOMATION" || { echo "FAIL: executor autopicks obvious prevention work"; exit 1; }
  grep -q "Ask the user only for true product choices" "$EXECUTOR_AUTOMATION" || { echo "FAIL: executor avoids micro-decision handoff"; exit 1; }
  grep -q "friendly plain-English summary" "$EXECUTOR_AUTOMATION" || { echo "FAIL: executor plain-English reporting"; exit 1; }
  grep -q "Do not use.*Executed" "$EXECUTOR_AUTOMATION" || { echo "FAIL: executor avoids bare executed report"; exit 1; }
  grep -q "context-switched" "$EXECUTOR_AUTOMATION" || { echo "FAIL: executor rehydrates context"; exit 1; }
  grep -q "file paths and technical labels only as receipts" "$EXECUTOR_AUTOMATION" || { echo "FAIL: executor uses files as receipts"; exit 1; }
  grep -q "Do not attempt to serve a live dashboard" "$EXECUTOR_AUTOMATION" || { echo "FAIL: executor must stay file-only"; exit 1; }
  ! grep -q "CEO-style summary" "$EXECUTOR_AUTOMATION" || { echo "FAIL: executor should not request CEO-style summary"; exit 1; }
  ! grep -q "stop before writing" "$EXECUTOR_AUTOMATION" || { echo "FAIL: executor should not stop on baseline dirt"; exit 1; }
  ! grep -q "If verification fails, do not commit" "$EXECUTOR_AUTOMATION" || { echo "FAIL: executor should fix own verification failures"; exit 1; }
  ! grep -q "For each configured repo" "$EXECUTOR_AUTOMATION" || { echo "FAIL: executor must not loop configured repos"; exit 1; }
fi

echo "OK: learn structural check passed"
