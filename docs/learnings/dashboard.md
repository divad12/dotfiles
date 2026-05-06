# Learning Dashboard

## inbox.md

# Learning Inbox

### 83b06990aeb2-keep-one-canonical-learning-front-door
- Fingerprint: 83b06990aeb2
- Sources: user-feedback
- Captured: 2026-05-05
- Source events: None
- Scope: project
- User-facing summary: Keep one canonical learning front door
- Evidence: You pointed out that an old capture wrapper and a repo-local README were both duplicating /learn behavior — and duplicate docs always drift apart over time.
- Technical refs: .agents/skills/learn/SKILL.md, docs/ai/learning-system.md, docs/learnings/README.md
- Ramification: When the setup feels like a CLI toolkit with parallel docs, you stop trusting it as a product.
- Suspected pattern: Unknown
- Recommended fix: Move useful capture reasoning into /learn and docs/ai/learning-system.md; keep repo-local READMEs as pointer-only files.
- Prevention artifacts: skill (required)
- Requires TDD/review: yes
- Confidence: high
- Status: inbox
### 04e0529e5585-verify-that-required-behavior-is-actually-wired
- Fingerprint: 04e0529e5585
- Sources: user-feedback
- Captured: 2026-05-05
- Source events: None
- Scope: project
- User-facing summary: Verify that required behavior is actually wired
- Evidence: You asked whether triage and executor actually read the learning-system doc and apply the abstraction ladder, surfacing that "should do X" in prose is empty unless something concrete enforces it.
- Technical refs: /Users/david/.codex/automations/daily-learning-triage/automation.toml, /Users/david/.codex/automations/daily-learning-executor/automation.toml, .agents/skills/learn/tests/structural-check.sh
- Ramification: If we say a behavior is required but no prompt, hook, test, automation, or structural check makes it happen, you can't trust the system to do what we promise.
- Suspected pattern: Claims about expected behavior drift from actual wiring.
- Recommended fix: When a workflow depends on a behavior, point at the trigger, prompt, hook, test, or structural check that enforces it — and add one if it's missing.
- Prevention artifacts: automation (required)
- Requires TDD/review: yes
- Confidence: high
- Status: inbox
### bd3fb5f75282-don-t-dress-fingerprints-up-as-semantic-judgment
- Fingerprint: bd3fb5f75282
- Sources: user-feedback
- Captured: 2026-05-05
- Source events: None
- Scope: project
- User-facing summary: Don't dress fingerprints up as semantic judgment
- Evidence: You pointed out that exact fingerprint matching almost never dedupes probabilistic agent wording — real duplicate detection and clustering need agent judgment, not a hash.
- Technical refs: .agents/skills/learn/SKILL.md, docs/ai/learning-system.md, bin/learn
- Ramification: If the docs sell fingerprints as semantic dedupe, you'll trust dead plumbing and miss that the real work happens during agentic triage.
- Suspected pattern: Unknown
- Recommended fix: Treat fingerprints as row IDs and exact-replay guards only; make the docs, tests, and automation prompts say semantic dedupe and clustering belong to the agent.
- Prevention artifacts: docs (required)
- Confidence: high
- Status: inbox
### 9f76a57015e7-observers-should-route-learnings--not-hoard-them
- Fingerprint: 9f76a57015e7
- Sources: user-feedback
- Captured: 2026-05-05
- Source events: None
- Scope: project
- User-facing summary: Observers should route learnings, not hoard them
- Evidence: You asked whether a different Journology session would remember to capture learnings if only the /learn skill header mentioned the triggers — and whether task-observer's old observation log is still pulling its weight now that durable learnings route through the learning system.
- Technical refs: .agents/skills/task-observer/SKILL.md, .agents/skills/learn/SKILL.md, .claude/AGENTS.md
- Ramification: If the ambient observer keeps its own backlog instead of routing through /learn, durable feedback ends up split across two stores or lost entirely.
- Suspected pattern: Ambient sensors drift into parallel memory systems.
- Recommended fix: Keep task-observer as the trigger and sensor, route durable learnings through /learn into docs/learnings/, and use observation files only as session audit fallback.
- Prevention artifacts: skill (required)
- Requires TDD/review: yes
- Confidence: high
- Status: inbox
### b27c9463bf75-multi-cwd-automations-must-stay-in-their-own-repo-per-run
- Fingerprint: b27c9463bf75
- Sources: user-feedback
- Captured: 2026-05-05
- Source events: None
- Scope: project
- User-facing summary: Multi-cwd automations must stay in their own repo per run
- Evidence: You noticed Codex spawns one executor per cwd, which means the Journology executor shouldn't be inspecting or reporting on dotfiles — but the prompts didn't say so.
- Technical refs: /Users/david/.codex/automations/daily-learning-executor/automation.toml, /Users/david/.codex/automations/daily-learning-triage/automation.toml, docs/ai/learning-system.md
- Ramification: Without explicit scoping, a repo-scoped automation gets noisy and can hit sandbox or write failures when one run reaches into sibling configured repos.
- Suspected pattern: Unknown
- Recommended fix: State in the automation prompts and contracts that each cron invocation operates only on its own current working directory — never on sibling configured repos.
- Prevention artifacts: automation (required)
- Requires TDD/review: yes
- Confidence: high
- Status: inbox
### 053992e19e3d-prevention-plans-usually-need-more-than-one-artifact
- Fingerprint: 053992e19e3d
- Sources: user-feedback
- Captured: 2026-05-06
- Source events: None
- Scope: agent-system
- User-facing summary: Prevention plans usually need more than one artifact
- Evidence: Journology candidates kept showing prevention plans that needed more than one piece — a test plus docs, or a helper plus a test. You also clarified you wanted one readable list with required/proposed markers, not separate primary/secondary fields.
- Technical refs: docs/ai/learning-system.md, .agents/skills/learn/SKILL.md, setup/tests/test_learn_cli.py
- Ramification: If the system reads only one prevention artifact, an agent can auto-promote a docs-shaped entry and silently skip the test, helper, skill, or automation work that actually prevents the bug from coming back.
- Suspected pattern: Unknown
- Recommended fix: Store Prevention artifacts as one list with explicit required/proposed markers, and gate any required code-risk artifact behind TDD/review.
- Prevention artifacts: docs (required), test (required)
- Requires TDD/review: yes
- Confidence: high
- Status: inbox
### 60fa957fe0f0-daily-learning-automations-need-a-frontier-judgment-model
- Fingerprint: 60fa957fe0f0
- Sources: user-feedback
- Captured: 2026-05-06
- Source events: None
- Scope: agent-system
- User-facing summary: Daily learning automations need a frontier judgment model
- Evidence: You noticed daily learning automations were defaulting to gpt-5.2, which isn't strong enough to cluster, abstract, weigh safety, and calibrate across many learnings.
- Technical refs: docs/ai/learning-system.md, /Users/david/.codex/automations/daily-learning-triage/automation.toml, /Users/david/.codex/automations/daily-learning-executor/automation.toml
- Ramification: A weak parent model misclusters evidence, auto-executes the wrong prevention work, or misses when a decision needed your eyes on it.
- Suspected pattern: Unknown
- Recommended fix: Run daily triage and executor parents on gpt-5.5 with high reasoning; only fall back to focused coding models like gpt-5.3-codex for bounded subagents the executor dispatches.
- Prevention artifacts: docs (required), automation (required)
- Requires TDD/review: yes
- Confidence: high
- Status: inbox
### 08c2d3bc8cf3-daily-automations-should-read-canonical-docs-from-master
- Fingerprint: 08c2d3bc8cf3
- Sources: user-feedback
- Captured: 2026-05-06
- Source events: None
- Scope: agent-system
- User-facing summary: Daily automations should read canonical docs from master
- Evidence: The daily learning automation prompts were still pointing at /Users/david/.codex/worktrees/20dc/dotfiles even after the work had landed on master — they were reading from a feature worktree that could disappear.
- Technical refs: None
- Ramification: Scheduled runs end up following stale or vanished feature-worktree instructions instead of the canonical learning contract.
- Suspected pattern: Unknown
- Recommended fix: Point daily learning automations at the durable dotfiles master checkout, and treat repo-local docs as cwd-specific supplements only.
- Prevention artifacts: docs (required)
- Confidence: medium
- Status: inbox
### b1ade9e50ec0-daily-automations-should-read-canonical-docs-from-master
- Fingerprint: b1ade9e50ec0
- Sources: user-feedback
- Captured: 2026-05-06
- Source events: None
- Scope: agent-system
- User-facing summary: Daily automations should read canonical docs from master
- Evidence: The daily learning automation prompts were still pointing at /Users/david/.codex/worktrees/20dc/dotfiles even after the work had landed on master — they were reading from a feature worktree that could disappear.
- Technical refs: docs/ai/learning-system.md, /Users/david/.codex/automations/daily-learning-triage/automation.toml, /Users/david/.codex/automations/daily-learning-executor/automation.toml
- Ramification: Scheduled runs end up following stale or vanished feature-worktree instructions instead of the canonical learning contract.
- Suspected pattern: Unknown
- Recommended fix: Point daily learning automations at the durable dotfiles master checkout, and treat repo-local docs as cwd-specific supplements only.
- Prevention artifacts: docs (required), automation (required)
- Requires TDD/review: yes
- Confidence: high
- Status: inbox
### 9681e329c380-learning-glue-must-work-everywhere---global--not-repo-local
- Fingerprint: 9681e329c380
- Sources: user-feedback
- Captured: 2026-05-06
- Source events: None
- Scope: agent-system
- User-facing summary: Learning glue must work everywhere — global, not repo-local
- Evidence: During a Journology merge, a session reported that bin/learn was missing, so it couldn't run the before-landing learning checkpoint at all.
- Technical refs: docs/ai/git.md, .agents/skills/learn/SKILL.md, .agents/skills/learn/tests/structural-check.sh
- Ramification: If the learn command isn't global, you can land branches in repos that have docs/learnings but no copy of the binary — silently skipping the checkpoint.
- Suspected pattern: Unknown
- Recommended fix: Always invoke the global learn command with --repo, and structurally guard the merge docs against assuming a repo-local bin/learn exists.
- Prevention artifacts: docs (required), test (required), skill (required)
- Requires TDD/review: yes
- Confidence: high
- Status: inbox
### 5301da11e4f9-re-check-git-after-browser-review-tools-before-the-final-commit
- Fingerprint: 5301da11e4f9
- Sources: user-feedback
- Captured: 2026-05-06
- Source events: None
- Scope: agent-system
- User-facing summary: Re-check git after browser/review tools before the final commit
- Evidence: During a Journology merge the review server/browser wrote another comment-JSON change after the commit you thought was the final clean docs one.
- Technical refs: docs/ai/git.md, .agents/skills/learn/tests/structural-check.sh
- Ramification: If we don't re-check, the target branch can land without the latest review-comment state — the agent believes everything is captured, but it isn't.
- Suspected pattern: Unknown
- Recommended fix: After any browser or review-server tool runs, re-run git status before the final commit or branch advance, and fold any generated review state into the right commit.
- Prevention artifacts: docs (required), test (required)
- Requires TDD/review: yes
- Confidence: high
- Status: inbox


## candidates.md

# Learning Candidates

