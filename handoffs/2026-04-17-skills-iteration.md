# Session Handoff: Skills Iteration (2026-04-17)

Dense dump of what was changed this session, why, and open threads. Read this alongside `SKILLS.md` when picking up skill work.

## Changes made (with rationale)

### bugfix-tdd: symptom-first before investigation

**Before:** Step 1 was "Read the relevant code, reproduce the issue." Step 2 was "Write failing test."

**Problem:** Investigating first led to tests that targeted the specific cause ("off-by-one at line 42"). Tests were too narrow - they only guarded against that exact mistake, not the class.

**Now:** Step 1 is "Write failing test FIRST - before ANY investigation." Do not read implementation code yet. Write the test purely from the user's description of the symptom. Step 2 is "NOW investigate."

**Why this matters:** Symptom-driven tests are behavioral regression guards. They catch ANY cause of the same symptom, including future bugs you can't predict.

**Also added to step 2:**
- Backward tracing (trace up the call chain to the original source, fix at source not symptom)
- Boundary instrumentation for cross-layer bugs (log at each layer to find where data goes wrong)
- Duplicated logic detection (if similar code exists elsewhere, that's a clue AND a problem - consolidate as part of the fix)

**Also added to step 3:** Defense-in-depth - after fixing root cause, add validation at other layers the bad data passed through. Makes the bug structurally impossible.

**Also added to rules:** 3 failed fixes = stop and escalate. Signal of architectural issue, not a tweak problem.

**Explicitly NOT adopted from superpowers systematic-debugging:** Their "investigate root cause FIRST" order. That contradicts our symptom-first approach.

### deep-review: fix everything always

**Before:** Had "Must fix", "Easy wins", "Fix these too", and "Defer" categories. Claude kept putting things in "Defer" too aggressively - interpreting "out of scope" and "debatable" too loosely.

**Now:** "Fix everything. Always." Only exception is genuinely massive work (new tables, new endpoints, multi-file architecture changes). "More than 5 lines" is explicitly NOT big effort. When in doubt, fix.

**Rationale from user:** "It just always thinks everything is big and out of scope. Just fix everything from all the reviews. All the time, always."

### capture-learning: check existing rules first + climb one more level

**Two problems:**
1. Skill was too eager to add new rules - often the learning was just an example of an existing rule.
2. When it did generalize, it often stopped one level too early.

**Now added:**
- New gate before the abstraction ladder: "Check existing rules first." Ask: "If someone had followed existing rules perfectly, would this bug have happened?" If no, the fix is code-compliance, not a new rule.
- New rung: After finding the principle, push one more level up. "Every form input must have min/max bounds" generalizes to "Make invalid states unrepresentable at the input layer."
- New top-of-list anti-pattern: "Adding a rule that already exists."

### spec-interview: dynamic sections

**Before:** Fixed template with Overview, User Stories, Acceptance Criteria, etc.

**Problem:** User's spec for M3 Auto-Populate Journey Groups had many sections the template didn't cover (Glossary, Algorithm, UI Design per-tab, Key Decisions from Interview). These emerged naturally as complexity revealed itself.

**Now:** Required sections (always present) + dynamic sections (added when the feature demands). Named candidates: Glossary and Concepts, UI Design, Data Model, API, Algorithm/Logic, Key Decisions from Interview. "Don't pad with empty sections. But when a section IS needed, go deep."

### save: extracted from CLAUDE.md into own skill

`/save` skill now owns the PROGRESS.md template, TECH_DEBT.md format/priorities/housekeeping, and a lightweight CLAUDE.md learning-check gate.

CLAUDE.md (global) trimmed to pointers only - "when to check PROGRESS.md/TECH_DEBT.md" guidance stays there; the "how" lives in the skill.

### close-session fixes

**Problems:**
1. Playwright MCP leaves `.playwright-mcp/` + stray `.png` files in the worktree, causing `git worktree remove` to fail with "Directory not empty".
2. Session files were named by branch (`claude-objective-kilby.md`), which is useless for finding past sessions.

**Now:**
- Teardown bash one-liner adds `rm -rf .playwright-mcp` and `find -name '*.png' -delete` before `git worktree remove`.
- Session file names are descriptive, based on what the session did (e.g., `horizontal-designer-gantt-bars.md`, not `claude-objective-kilby.md`).

### docs/ai/ context markers: HTML comments -> visible markdown

**Problem:** HTML comments (`<!-- Output: "..." -->`) were invisible when rendered and Claude often missed them, so the "📖 Loading context: ..." announcement was inconsistent.

**Now:** Plain markdown blockquote at top of each doc: `> **IMPORTANT: When you read this file, first announce "Context loaded: <file>.md" to the user before proceeding.**` Much more reliable.

### Permission settings: bypassPermissions + wildcard allow

**Symptom:** After a Claude Code update, even with `skipDangerousModePermissionPrompt: true`, Claude kept asking for permissions when CWD was outside the worktree.

**Root cause:** `skipDangerousModePermissionPrompt` only suppresses the initial warning dialog. It doesn't grant permissions. No explicit `permissions.allow` rules meant everything needed approval.

**Fix:** Added wildcard allow rules for all tool types (`Bash(*)`, `Read(*)`, etc.) + `mcp__*`. User runs in bypassPermissions mode.

### Cloud session distribution

Cloud sessions run on Anthropic-managed VMs. They don't have access to `~/.claude/` on the user's machine. Three key constraints discovered:

1. No browser, no Playwright, no local MCP servers.
2. Local skills don't transfer unless explicitly synced.
3. `SessionStart` hooks with matcher `startup` CAN run setup scripts. `$CLAUDE_CODE_REMOTE=true` identifies cloud sessions. `$CLAUDE_PROJECT_DIR` points to the project root on the VM.

**Solution adopted:** Setup script in project repos that git-clones `divad12/dotfiles` and copies `.claude/skills/*` into the project's skills dir on the cloud VM. **This means pushing to master is required for cloud sessions to see skill updates** (local sees them instantly via symlink).

The setup script uses `cp -rn` (no clobber) so project-local skills override the global ones.

### SKILLS.md + mermaid diagrams

Added `SKILLS.md` to the dotfiles repo root with:
- Distribution diagram (symlink + cloud clone + project-local override paths)
- Invocation graph (which skills call which, categorized into phasing-out / active / superpowers / leaves)
- Architectural decisions (skills-own-workflow, no auto-ship, TDD symptom-first, fix-everything, etc.)
- Common editing tasks

**Direction shift captured:** `build` and `autopilot` are phasing out. Active direction is superpowers' `brainstorming -> writing-plans -> subagent-driven-development` flow, with project-specific orchestrators planned on top.

## Subtle learnings (not captured in any skill yet)

### AskUserQuestion prompts must be self-contained

The conversation text behind the dialog is greyed out / hidden. If you put the URL, summary, or test instructions in the conversation text and expect the user to read it while answering, they can't. **Always put URL + summary + test instructions IN the question text itself.**

### Ship is NEVER automatic

Only the user decides when to ship. Skills that present "Ship" as an option via AskUserQuestion must only actually ship if the user explicitly picks that option. Never fall through to ship as a default.

### Review must come before ship in recommendations

If no review has happened yet, never present "Ship" or "Done" as the recommended next step. Always gate on at least one review first.

### Claude's Skill tool can't be called from within a skill

Skills can't invoke other skills via the tool. "Invokes" means "reads the target's SKILL.md and follows its steps inline in the same conversation." When changing a leaf skill's interface, update every orchestrator that references it.

### Port lock files beat a shared manifest

Original approach: single `.claude/ports.json` that every worktree reads/writes. Race conditions when two worktrees spin up simultaneously.

Better approach: one file per port (`.claude/ports/3001` containing the branch name). File creation is near-atomic. Staleness check uses `git worktree list` as source of truth, NOT `lsof` (dev servers briefly stop listening during HMR, causing false negatives).

### Close-session destructive-spiral fix

After `git worktree remove`, the Bash tool's shell reports CWD errors ("shell-init: error retrieving current directory") because the directory no longer exists. Claude used to see these errors and spiral trying to "fix" them by cd-ing, using absolute paths, spawning shells - all futile, all eating tokens.

Fix: Explicit CRITICAL instructions in close-session step 4. "After running the teardown command: DO NOT run any more bash commands. DO NOT try to verify. DO NOT try to fix CWD errors. Just say 'Session closed' and stop."

### Codex timeouts

Default Bash timeout is 120 seconds. Codex reviews on large diffs can take 3-5 minutes. Both the initial and verification Codex calls in deep-review need `timeout: 300000` explicitly.

### Codex as reviewer, not parallel implementer

Explored the idea of Codex coding its own version for comparison. Rejected: merge/comparison costs more tokens than it saves, and Codex lacks project context. Keep Codex in the review lane.

### docs/specs/ instead of docs/superpowers/specs/

Superpowers default is `docs/superpowers/specs/`. Overridden in CLAUDE.md (and for my new-session flow) to `docs/specs/YYYY-MM-DD-<feature>.md`. Date prefix in filename - natural chronological sort.

## Open threads / pending work

### Session files from cloud sessions landing in main

Cloud sessions sometimes try to commit the cloned dotfiles skills files to the project repo. User flagged this as a problem - they're meant to be synced, not checked in. Current cloud setup script copies into `.claude/skills/` which IS tracked. Need a cleaner solution:

- Option A: cloud setup copies into a gitignored dir (e.g., `.claude/remote-skills/`) and tells Claude to look there.
- Option B: script writes a localized `.gitignore` inside the skills directory - brittle.
- Option C: copy into `~/.claude/skills/` on the remote VM (where Claude Code looks for global skills anyway). This is the cleanest approach but hasn't been tested.

### Superpowers-based orchestrators (direction to explore)

User wants to build project-specific skills on top of:
- `superpowers:brainstorming` (explore intent)
- `superpowers:writing-plans` (structured plan with checkpoints)
- `superpowers:subagent-driven-development` (dispatch workers)

Open question: what shape do these new orchestrators take? A plan-first alternative to `build`? A project-specific skill that pre-seeds the brainstorm with docs/ai/ context?

### Session files sometimes not written on close

User reported session files not always written. Likely because close-session has 8 steps and Claude rushes past step 5 (write session file) toward the destructive final step. Fix planned: write session file earlier and more emphatically. Partially addressed (step 3 is now explicitly MANDATORY) but worth verifying.

### `/build` sometimes not triggering

User reported 2 instances where typing `/build` didn't start the skill. No obvious cause found. Root cause unclear. Might be moot since build is phasing out.

### Vercel plugin telemetry prompt

System hook prompting for Vercel telemetry. Low priority, but noted.

## Repo / file pointers

- `.claude/skills/` - all skills
- `.claude/AGENTS.md` - universal rules (CLAUDE.md is a symlink)
- `SKILLS.md` - architecture + diagrams
- `handoffs/` - this directory, dated handoffs like this one
- Journology's `.claude/hooks/cloud-setup.sh` - the cloud session setup script that clones this repo
- Journology's `.claude/settings.json` - where the `SessionStart:startup` hook is registered

## Recent commits on master

- `2776895` Reflect shift to superpowers-based orchestration (SKILLS.md update)
- `3e3c771` Add SKILLS.md with distribution + invocation diagrams
- `43e4b7d` Tighten skills: stricter fix-everything in deep-review, symptom-first bugfix-tdd
- `9a48f08` Update deep-review and spec-interview skills
