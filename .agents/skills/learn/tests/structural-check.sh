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
grep -q "Scheduled maintenance is one repo-scoped agent run" "$SKILL" || { echo "FAIL: combined maintenance contract"; exit 1; }
grep -q "status labels were speaking too soon" "$SKILL" || { echo "FAIL: concrete voice example in learn skill"; exit 1; }
! grep -q "reporting-voice.md" "$SKILL" || { echo "FAIL: learn skill should not point to extracted voice file"; exit 1; }
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
grep -q "done.*required.*proposed" "$SKILL" || { echo "FAIL: dashboard artifact status contract"; exit 1; }
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
grep -q "Learning maintenance is one repo-scoped agent run" "$DOC" || { echo "FAIL: learning doc combined automation"; exit 1; }
grep -q "Dotfiles runs weekly" "$DOC" || { echo "FAIL: learning doc dotfiles weekly schedule"; exit 1; }
grep -q "Journology runs Monday, Wednesday, and Friday" "$DOC" || { echo "FAIL: learning doc journology MWF schedule"; exit 1; }
grep -q "Review is optional calibration, not a daily approval gate" "$DOC" || { echo "FAIL: learning doc hands-off review contract"; exit 1; }
grep -q "Let abstractions emerge from batches of evidence" "$DOC" || { echo "FAIL: learning doc sample-backed clustering contract"; exit 1; }
grep -q "Do not manufacture one guidance line per bug" "$DOC" || { echo "FAIL: learning doc no per-bug abstraction churn"; exit 1; }
grep -q "Action status" "$DOC" || { echo "FAIL: learning doc dashboard action status"; exit 1; }
grep -q "What changed.*Next.*Blocked" "$DOC" || { echo "FAIL: learning doc readable status buckets"; exit 1; }
grep -q "Guardrail pills must show artifact state" "$DOC" || { echo "FAIL: learning doc artifact status contract"; exit 1; }
grep -q "Proposed means optional companion work" "$DOC" || { echo "FAIL: learning doc proposed artifact meaning"; exit 1; }
grep -q "Use a frontier reasoning parent model" "$DOC" || { echo "FAIL: learning automation model policy"; exit 1; }
grep -q "gpt-5.5" "$DOC" || { echo "FAIL: learning automation parent model"; exit 1; }
grep -q "high reasoning" "$DOC" || { echo "FAIL: learning automation parent reasoning"; exit 1; }
grep -q "gpt-5.3-codex" "$DOC" || { echo "FAIL: learning automation subagent model"; exit 1; }
grep -q "durable dotfiles master checkout" "$DOC" || { echo "FAIL: learning automation canonical checkout"; exit 1; }
grep -q "context-switched" "$DOC" || { echo "FAIL: learning doc context-rehydrating reports"; exit 1; }
grep -q "same shared calculation" "$DOC" || { echo "FAIL: learning doc translates jargon labels"; exit 1; }
grep -q "not terse corporate shorthand" "$DOC" || { echo "FAIL: learning doc rejects corporate shorthand"; exit 1; }
grep -q 'Do not say "prevention artifact" in a user-facing report' "$DOC" || { echo "FAIL: learning doc bans internal artifact label in reports"; exit 1; }
grep -q "Do not call file paths" "$DOC" || { echo "FAIL: learning doc bans receipt label"; exit 1; }
grep -q "receipts" "$DOC" || { echo "FAIL: learning doc names banned receipt label"; exit 1; }
grep -q "status labels were speaking too soon" "$DOC" || { echo "FAIL: concrete voice example in learning doc"; exit 1; }
! grep -q "learning-report-voice.md" "$DOC" || { echo "FAIL: learning doc should not point to extracted voice file"; exit 1; }
grep -q "Prevention artifacts: docs (required), test (required), skill (proposed)" "$DOC" || { echo "FAIL: learning doc prevention artifacts"; exit 1; }
grep -q "Skill and Doc Enforcement" "$DOC" || { echo "FAIL: skill/doc enforcement contract"; exit 1; }
grep -q "automatically loads the rule before implementation" "$DOC" || { echo "FAIL: automatic skill enforcement rationale"; exit 1; }
grep -q "write the failing test or structural check first" "$DOC" || { echo "FAIL: learning doc TDD automation"; exit 1; }
grep -q "Maintenance Sweep" "$DOC" || { echo "FAIL: maintenance sweep contract"; exit 1; }
grep -q "Maintenance Action" "$DOC" || { echo "FAIL: maintenance action contract"; exit 1; }
grep -q "Use subagents" "$DOC" || { echo "FAIL: subagent automation contract"; exit 1; }
grep -q "If the user says.*done" "$DOC" || { echo "FAIL: done trigger contract"; exit 1; }
grep -q "same-day audit marker" "$DOC" || { echo "FAIL: skip maintenance marker"; exit 1; }
grep -q "next scheduled maintenance run" "$DOC" || { echo "FAIL: skip maintenance contract"; exit 1; }
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
SHARED_MAINTENANCE_PROMPT="$CANONICAL_AUTOMATION_HOME/learning-maintenance-prompt.md"
LIVE_JOURNOLOGY_AUTOMATION="$AUTOMATION_HOME/journology-learning-maintenance/automation.toml"
LIVE_DOTFILES_AUTOMATION="$AUTOMATION_HOME/dotfiles-learning-maintenance/automation.toml"
JOURNOLOGY_AUTOMATION="$CANONICAL_AUTOMATION_HOME/journology-learning-maintenance/automation.toml"
DOTFILES_AUTOMATION="$CANONICAL_AUTOMATION_HOME/dotfiles-learning-maintenance/automation.toml"
test -f "$SHARED_MAINTENANCE_PROMPT" || { echo "FAIL: shared learning maintenance prompt missing"; exit 1; }
test -f "$JOURNOLOGY_AUTOMATION" || { echo "FAIL: Journology maintenance automation canonical copy missing"; exit 1; }
test -f "$DOTFILES_AUTOMATION" || { echo "FAIL: dotfiles maintenance automation canonical copy missing"; exit 1; }
test ! -e "$CANONICAL_AUTOMATION_HOME/daily-learning-triage" || { echo "FAIL: old daily-learning-triage folder remains"; exit 1; }
test ! -e "$CANONICAL_AUTOMATION_HOME/daily-learning-executor" || { echo "FAIL: old daily-learning-executor folder remains"; exit 1; }
grep -q ".codex/automations" symlink.sh || { echo "FAIL: symlink.sh mirrors codex automations"; exit 1; }
grep -q "Do not copy this prompt body into repo-specific automation.toml files" "$SHARED_MAINTENANCE_PROMPT" || { echo "FAIL: shared prompt forbids wrapper drift"; exit 1; }
grep -q "one combined run: first do a triage sweep, then act" "$SHARED_MAINTENANCE_PROMPT" || { echo "FAIL: shared prompt combines sweep and action"; exit 1; }
grep -q "Abstraction Ladder" "$SHARED_MAINTENANCE_PROMPT" || { echo "FAIL: shared prompt applies abstraction ladder"; exit 1; }
grep -q "sample-backed clusters" "$SHARED_MAINTENANCE_PROMPT" || { echo "FAIL: shared prompt clusters from samples"; exit 1; }
grep -q "Do not manufacture one guidance line per bug" "$SHARED_MAINTENANCE_PROMPT" || { echo "FAIL: shared prompt avoids per-bug guidance churn"; exit 1; }
grep -q "friendly plain-English summary" "$SHARED_MAINTENANCE_PROMPT" || { echo "FAIL: shared prompt plain-English reporting"; exit 1; }
grep -q "Do not use.*Executed" "$SHARED_MAINTENANCE_PROMPT" || { echo "FAIL: shared prompt avoids bare executed report"; exit 1; }
grep -q "status labels were speaking too soon" "$SHARED_MAINTENANCE_PROMPT" || { echo "FAIL: shared prompt includes concrete voice example"; exit 1; }
if test -f "$LIVE_JOURNOLOGY_AUTOMATION"; then
  test -L "$LIVE_JOURNOLOGY_AUTOMATION" || { echo "FAIL: Journology automation live file should symlink to dotfiles"; exit 1; }
fi
if test -f "$LIVE_DOTFILES_AUTOMATION"; then
  test -L "$LIVE_DOTFILES_AUTOMATION" || { echo "FAIL: dotfiles automation live file should symlink to dotfiles"; exit 1; }
fi
test ! -e "$AUTOMATION_HOME/daily-learning-triage" || { echo "FAIL: old live daily-learning-triage folder remains"; exit 1; }
test ! -e "$AUTOMATION_HOME/daily-learning-executor" || { echo "FAIL: old live daily-learning-executor folder remains"; exit 1; }
if test -f "$JOURNOLOGY_AUTOMATION"; then
  grep -q 'id = "journology-learning-maintenance"' "$JOURNOLOGY_AUTOMATION" || { echo "FAIL: Journology automation id"; exit 1; }
  grep -q "MWF Journology learning maintenance" "$JOURNOLOGY_AUTOMATION" || { echo "FAIL: Journology automation name"; exit 1; }
  grep -q 'rrule = "FREQ=WEEKLY;BYDAY=MO,WE,FR;BYHOUR=17;BYMINUTE=0;BYSECOND=0"' "$JOURNOLOGY_AUTOMATION" || { echo "FAIL: Journology MWF schedule"; exit 1; }
  grep -q 'cwds = \["/Users/david/Dropbox (Personal)/code/journology"\]' "$JOURNOLOGY_AUTOMATION" || { echo "FAIL: Journology cwd only"; exit 1; }
  grep -q "learning-maintenance-prompt.md" "$JOURNOLOGY_AUTOMATION" || { echo "FAIL: Journology reads shared maintenance prompt"; exit 1; }
  grep -q 'repo label "Journology"' "$JOURNOLOGY_AUTOMATION" || { echo "FAIL: Journology repo label"; exit 1; }
  ! grep -q "Sweep first" "$JOURNOLOGY_AUTOMATION" || { echo "FAIL: Journology wrapper duplicates shared prompt body"; exit 1; }
  ! grep -q "status labels were speaking too soon" "$JOURNOLOGY_AUTOMATION" || { echo "FAIL: Journology wrapper duplicates concrete voice example"; exit 1; }
  ! grep -q "For each configured repo" "$JOURNOLOGY_AUTOMATION" || { echo "FAIL: Journology must not loop configured repos"; exit 1; }
fi
if test -f "$DOTFILES_AUTOMATION"; then
  grep -q 'id = "dotfiles-learning-maintenance"' "$DOTFILES_AUTOMATION" || { echo "FAIL: dotfiles automation id"; exit 1; }
  grep -q "Weekly dotfiles learning maintenance" "$DOTFILES_AUTOMATION" || { echo "FAIL: dotfiles automation name"; exit 1; }
  grep -q 'rrule = "FREQ=WEEKLY;BYDAY=TU;BYHOUR=17;BYMINUTE=0;BYSECOND=0"' "$DOTFILES_AUTOMATION" || { echo "FAIL: dotfiles weekly schedule"; exit 1; }
  grep -q 'cwds = \["/Users/david/Dropbox (Personal)/code/dotfiles"\]' "$DOTFILES_AUTOMATION" || { echo "FAIL: dotfiles cwd only"; exit 1; }
  grep -q "learning-maintenance-prompt.md" "$DOTFILES_AUTOMATION" || { echo "FAIL: dotfiles reads shared maintenance prompt"; exit 1; }
  grep -q 'repo label "dotfiles"' "$DOTFILES_AUTOMATION" || { echo "FAIL: dotfiles repo label"; exit 1; }
  ! grep -q "Sweep first" "$DOTFILES_AUTOMATION" || { echo "FAIL: dotfiles wrapper duplicates shared prompt body"; exit 1; }
  ! grep -q "status labels were speaking too soon" "$DOTFILES_AUTOMATION" || { echo "FAIL: dotfiles wrapper duplicates concrete voice example"; exit 1; }
  ! grep -q "CEO-style summary" "$DOTFILES_AUTOMATION" || { echo "FAIL: dotfiles should not request CEO-style summary"; exit 1; }
  ! grep -q "If verification fails, do not commit" "$DOTFILES_AUTOMATION" || { echo "FAIL: dotfiles should fix own verification failures"; exit 1; }
  ! grep -q "For each configured repo" "$DOTFILES_AUTOMATION" || { echo "FAIL: dotfiles must not loop configured repos"; exit 1; }
fi

echo "OK: learn structural check passed"
