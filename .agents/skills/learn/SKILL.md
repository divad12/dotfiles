---
name: learn
description: "Use when the user says '/learn', 'learn this', 'document this', 'capture this', 'remember this for next time', 'update the docs', asks to capture a durable project learning, or after fixes/reviews reveal reusable patterns."
user-invocable: true
argument-hint: "[plain-English learning or evidence]"
---

# Learn

Read `docs/ai/learning-system.md` before operating or changing this workflow.

Only three user-facing front doors are normal: `/learn` to capture, `/dashboard` to review, and `/learn-init` to initialize. Treat the global `learn --repo <repo>` command as hidden glue for agents and automations, not commands the user should have to remember. Do not assume the target repo has repo-local `bin/learn`.

## Store

Use the current repo's `docs/learnings/` store. If it does not exist, ask whether to initialize it through `/learn-init` unless the user already asked to capture here.

## Capture

Capture raw evidence broadly, but write the entry at the highest actionable pattern level. Include what's at stake for the human reading this later — what they will see, lose, feel, or risk.

### Voice

Write captures the way a thoughtful teammate would talk to the user about what just happened. Plain English, direct address, concrete.

- Address the human directly — "you", "we", or just describe the situation. **Never write "User …" or "The user …"** — that third-person crime-report tone is what makes the dashboard feel like a CLI dump. The only "user" of this learning store is the person reading it.
- Prefer everyday verbs: "asked" not "questioned why", "said" not "stated", "wanted" not "indicated a desire", "tried X and got Y" not "encountered an unexpected outcome", "noticed" not "noted that".
- Lead with the situation, then the lesson. Keep technical specifics (file names, commands, error text) verbatim — the voice change is about narration, not removing detail.
- Ramification is what's at stake for **the user** if this isn't fixed: "your forms can save broken data", "you'll trust the green checkmark when the build is actually red", "merges will silently lose work". State a concrete consequence, not an abstraction.

Voice contrast — same evidence, before and after:

> Bad: "User questioned why an old capture wrapper and repo-local README duplicated /learn behavior and warned that duplicate docs drift."
>
> Good: "You pointed out that an old capture wrapper and a repo README still duplicated what /learn does — and duplicate docs always drift apart."

> Bad: "Users have to reason about multiple learning surfaces and lose trust when the setup feels like a command-line toolkit instead of a product."
>
> Good: "When the setup feels like a CLI toolkit instead of a product, you stop trusting it."

> Bad: "User noted that Codex spawns one executor per cwd, so the Journology executor should not inspect or report on dotfiles."
>
> Good: "You noticed Codex spawns one executor per cwd — which means each run has to stay in its own repo and not peek at sibling configured ones."

If the captured `--summary` / `--evidence` / `--ramification` text reads as third-person bureaucratese, rewrite it before passing it to `learn capture`.

Use the same voice for daily automation reports. Assume the reader has
context-switched from something unrelated. Do not write `Executed` and then a
stack of bare file-change bullets. For each unrelated item, explain the problem
or pattern that prompted it, what changed in ordinary language, why it helps,
and then the file/test names as receipts. Translate internal labels first:
"make every UI counter use the same shared calculation" is useful context;
"shared-count/source-boundary rule" is only a shorthand after that.

#### Reference samples

Real entries already in the canonical voice. Match this shape and rhythm — the agent should be able to drop a new capture in this list and have it read indistinguishable from the rest.

**Sample — Keep one canonical learning front door**
- Evidence: You pointed out that an old capture wrapper and a repo-local README were both duplicating /learn behavior — and duplicate docs always drift apart over time.
- Ramification: When the setup feels like a CLI toolkit with parallel docs, you stop trusting it as a product.
- Suggested fix: Move useful capture reasoning into /learn and docs/ai/learning-system.md; keep repo-local READMEs as pointer-only files.

**Sample — Verify that required behavior is actually wired**
- Evidence: You asked whether triage and executor actually read the learning-system doc and apply the abstraction ladder, surfacing that "should do X" in prose is empty unless something concrete enforces it.
- Ramification: If we say a behavior is required but no prompt, hook, test, automation, or structural check makes it happen, you can't trust the system to do what we promise.
- Suggested fix: When a workflow depends on a behavior, point at the trigger, prompt, hook, test, or structural check that enforces it — and add one if it's missing.

**Sample — Learning glue must work everywhere — global, not repo-local**
- Evidence: During a Journology merge, a session reported that bin/learn was missing, so it couldn't run the before-landing learning checkpoint at all.
- Ramification: If the learn command isn't global, you can land branches in repos that have docs/learnings but no copy of the binary — silently skipping the checkpoint.
- Suggested fix: Always invoke the global learn command with --repo, and structurally guard the merge docs against assuming a repo-local bin/learn exists.

**Sample — Observers should route learnings, not hoard them**
- Evidence: You asked whether a different Journology session would remember to capture learnings if only the /learn skill header mentioned the triggers — and whether task-observer's old observation log is still pulling its weight now that durable learnings route through the learning system.
- Ramification: If the ambient observer keeps its own backlog instead of routing through /learn, durable feedback ends up split across two stores or lost entirely.
- Suggested fix: Keep task-observer as the trigger and sensor, route durable learnings through /learn into docs/learnings/, and use observation files only as session audit fallback.

**Sample — Re-check git after browser/review tools before the final commit**
- Evidence: During a Journology merge the review server/browser wrote another comment-JSON change after the commit you thought was the final clean docs one.
- Ramification: If we don't re-check, the target branch can land without the latest review-comment state — the agent believes everything is captured, but it isn't.
- Suggested fix: After any browser or review-server tool runs, re-run git status before the final commit or branch advance, and fold any generated review state into the right commit.

#### Common slips to avoid

- "User noticed / The user said" → use **you** or just describe the situation.
- "Users have to / Users may" → name **the user** or **we**, with a concrete consequence.
- "Should be configured / Could lead to" → say what actually happens: "if we skip this, the merge lands without X."
- Generic stakes ("this could cause confusion") → specific stakes ("you'll trust a green checkmark on a build that was actually red").
- Buzzword verbs (utilize, leverage, ensure, facilitate) → plain ones (use, lean on, make sure, help).
- Treating the recommended fix as a synopsis of evidence — it's an instruction. Start with a verb the future agent can act on: *Move*, *Add*, *Trace*, *Always invoke*, *Re-run*.

### Abstraction

Use the abstraction ladder from `docs/ai/learning-system.md`, but do not force a polished rule out of every single bug. Raw bugs are useful samples. When several samples point to the same class, cluster them into the highest still-actionable principle; when there is only one sample, capture it directly only if the prevention surface is already clear or the risk is high. If a claim says a workflow "should" do something, verify the actual trigger, prompt, hook, test, structural check, or code path that makes it happen.

After identifying the principle, note what would enforce it next time: a regression test, lint rule, schema/contract scan, shared helper, checklist, docs update, skill tweak, or automation.

Store prevention work as one readable list, e.g. `Prevention artifacts: docs (required), test (required), skill (proposed)`. Required artifacts describe work needed to prevent the issue; proposed artifacts are worthwhile ideas to consider. The executor decides what is executable now and records completed, blocked, deferred, or follow-up status. Any required code, test, helper, skill, automation, architecture, or enforcement artifact requires TDD/review discipline. If the code surface does not exist yet, docs, skill, or nested-AGENTS updates may be the only executable prevention artifact for now.

Before writing, check active inbox, candidates, promoted entries, and recent archives for an existing related learning. The CLI adds `Captured: YYYY-MM-DD` and a stable fingerprint so dashboard decisions can target a row. Fingerprint matching is not semantic dedupe; it only catches exact replay-like writes. Agents own semantic dedupe and clustering and should merge related evidence instead of creating noisy parallel entries.

Before writing a new entry, also look at the last five active learnings and any same session learning captures you remember. If the learning is already covered, skip the new capture or update the existing entry only when the new evidence, source, confidence, or technical refs add value.

Use the CLI only as safe write glue:

```bash
learn --repo "$PWD" capture \
  --source "<QA|review|bugfix|agent-discovery|user-feedback|failed-command|before-merge|task-observer|learn>" \
  --summary "<plain-English one-liner>" \
  --evidence "<plain-English evidence>" \
  --ramification "<user-facing impact>" \
  --recommended-fix "<one-line prevention action>" \
  --prevention-artifact "<test|lint|helper|skill|docs|nested-AGENTS|automation|archive>:<required|proposed>" \
  --confidence "<low|medium|high>" \
  --technical-ref "<file/function/test/log/screenshot>"
```

After capture or useful update, regenerate the dashboard and announce exactly one session-visible line:

```text
🧠 Captured learning: <plain-English summary>
```

If you skipped it because the learning was already captured, say:

```text
🧠 Learning already captured: <plain-English summary>
```

## Dashboard

For user review, prefer the served dashboard with finish execution:

```bash
learn --repo "$PWD" dashboard --serve --execute-on-finish --host 127.0.0.1 --port 0
```

The dashboard records decisions to `docs/learnings/decisions.jsonl`. Finish & Execute applies queued decisions, clears the queue, refreshes the dashboard, and shuts the server down. If serving is not available, run:

```bash
learn --repo "$PWD" dashboard
```

If the user asks to review without automatic finish execution, serve read/write decisions only:

```bash
learn --repo "$PWD" dashboard --serve --host 127.0.0.1 --port 0
```

The dashboard must show triage signals for Needs Review, Open Items, Auto Done, Raw Inbox, Candidates, Aging/Stale, Likely Duplicates, Calibration Learned, Blocked Decisions, and Ask Agent Prompts. Aging/Stale is date-backed from `Captured` entries. Expandable evidence must include Additional evidence from exact replay merges and agent-clustered captures.

Candidate cards must show Action status in plain English instead of dumping raw decision history. Bucket decision, follow-up, draft, and executor notes into What changed, Next, Blocked, and Notes so the reader can tell what automation already did, what remains, and whether anything needs help. Raw audit wording such as "follow-up required before code changes" belongs in the learning files or `auto-actions.md`, not as the primary dashboard copy.

## Agentic Maintenance

Daily maintenance is split into Triage automation and Executor automation. Triage runs around 5pm: it clusters new learnings when the samples support a natural pattern, merges duplicate evidence, archives obvious junk, and prepares candidate actions. Executor runs around 9pm: it acts by default on high-confidence narrow work, updates low-risk docs, or implements focused prevention artifacts when it can follow TDD/review.

The dashboard is optional calibration, not a daily approval gate. Do not make the user process a large review queue before useful work happens; do your best, commit successful automation changes locally, and report what changed. Existing dirty files are normal: snapshot them, leave them untouched and unstaged, do non-overlapping work, and fix verification failures caused by your own changes before committing. Ask only for true product choices or risky/blocked work.

Batch automations are file-only: regenerate `docs/learnings/dashboard.md` and
`dashboard.html`, but do not try to serve a live dashboard from cron. The user
owns the long-running interactive tab through `learn live`.

Automation reports should be friendly plain-English summaries, not corporate
shorthand. Include enough context for each unrelated item that the user can tell
what problem it came from, why it mattered, and what changed without opening the
file first.

If the user says `done` after reviewing the triage dashboard, run executor automation immediately for that repo, append a same-day audit marker, and skip the scheduled 9pm executor for that repo.

Executor automation should use subagents for independent implementation, review, or verification slices with disjoint file ownership. It should log every action in `docs/learnings/auto-actions.md`.

The executor can apply archive, candidate, promote, confidence, prevention-artifact, prevention-artifacts, note, calibration, defer, block, revise-wording, follow-up, draft-plan, and draft-patch decisions. It should plan or execute required prevention artifacts when they are clear enough and consider proposed artifacts when they fit the task. Draft decisions write `docs/learnings/drafts/<fingerprint>-plan.md` and `docs/learnings/drafts/<fingerprint>-patch.md`.

Learning-file updates and low-risk docs can be applied directly. Code, shared skill, enforcement, and architecture changes must become TDD/review tasks or focused verified changes; never silently edit code and never mark code-related prevention as promoted before tests and required review pass.

## Before Merge

At landing checkpoints, agents may use:

```bash
learn --repo "$PWD" check-merge
```

Surface high-confidence open items in plain English. If a prevention artifact is missing, ask whether to create it, defer it, or acknowledge landing with a follow-up.
