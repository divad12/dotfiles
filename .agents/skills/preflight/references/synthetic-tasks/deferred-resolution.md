# Deferred Resolution Synthetic Task

Always inject a `[SYNTHETIC: deferred-resolution]` task at the end of EVERY checklist (after the Session Gate, before Fly Verification). For multi-session plans this means each `checklist-N.md` has its own deferred-resolution task so each session clears its own backlog before handing off. This task wraps up any items that landed in `<plan>-deferred.md` during this session's run, so fly itself stays mechanical and doesn't burn context classifying/resolving deferred items.

For multi-session plans: each session's deferred-resolution task processes ALL §N entries currently in `<plan>-deferred.md` (sessions append to the same file across runs; previously-resolved entries already have `Status: RESOLVED in <SHA>` lines and are skipped). The user gets per-session "needs your input" prompts and "Try it yourself" walkthroughs, not a giant pile at the end of session K.

The injected task is a no-op when deferred.md is absent or empty, so it's safe to always inject.

## Task body to inject

```markdown
### Task final.deferred-resolution [SYNTHETIC: deferred-resolution] | Model: sonnet | Mode: subagent | LOC: ~0 | Review: combined

Goal: do as much of the deferred work as possible automatically; surface the rest clearly so the user can decide.

**Why review:** the fix-implementer commits this task lands run AFTER the Session Gate - they have no other reviewer coverage. One combined review at task end covers the cumulative diff (`git diff <task-start-sha>..HEAD`) for all auto-resolved §N fixes. If zero §N entries auto-resolved (all surfaced to user, none dispatched), the reviewer sees an empty diff and emits `No issues.`.

If `<plan-basename>-deferred.md` is missing or contains zero `## §` entries: print "No deferred items." and skip to the "Try it yourself" section below.

Otherwise, for each `## §N` entry, classify it into ONE of two buckets:

**Bucket A - Auto-resolve.** You can fix it without needing user input (BLOCKED-on-model item now tractable with upgraded model, reviewer mis-disposed a fixable nit, small refactor/typo/dead-code, anything else you have enough context to just do): dispatch an implementer (sonnet default; opus if original BLOCK was sonnet) with the finding + suggested fix + file path; run tests; commit with message `fix: §N <short title> (deferred resolution)`; append `Status: RESOLVED in <SHA>` to the §N entry in deferred.md. Auto-resolved items are NOT surfaced to the user (the commit is the surface).

**Bucket B - Surface to user.** Anything you cannot fix yourself: genuine UX/scope/policy decision, hard-to-reverse architectural choice, work that needs its own future session, OR a "latent / decide later" item parked because no current caller is affected and the right shape depends on future work. **There is no third bucket.** "Latent" items still go to Bucket B - they are still deferred items the user is committing to live with, and the user needs to weigh "live with this" against "fix now" with the same plain-English framing.

For EVERY Bucket B §N, use this exact format:

  ### §N: <plain-English title - what a non-engineer would call it>

  **What it is:** <2-3 sentences in user's terms - what the code does, in product/feature language. Translate file:line citations into "the X feature does Y when Z" framing. Avoid type/cast/interface/ref/Map/hook/state jargon unless it's the only honest framing - and if it is, define it.>
  **User-facing impact:** <one sentence: what does the user actually see, feel, lose, or risk if this stays unfixed? Concrete, time-anchored framing for latent items - "Today: nothing visible. When Session 2 wires the venue drawer to push external time edits, users editing inline times would see stale values until they click out of the field and back." Don't write "Latent" or "no current caller" - those are dev concepts; translate into product time. If there's TRULY no impact even in the worst future scenario, say "No user-facing impact - this is purely about <code maintainability / future-proofing>". Don't pad, don't hedge, don't skip this line.>
  **Why I didn't just do it:** <one short sentence - decision needed / too large for this session / risky / shape depends on future work>
  **My recommendation:** <what you'd do + 1 sentence why>
  **Options:** <list, OR "do now" / "spawn separate task" / "skip" if it's a follow-up rather than a decision-with-options>
  **Where:** `<file>:<line>` (full reviewer notes in `§N` of `<plan-basename>-deferred.md`)

**This format is mandatory for EVERY surfaced item, with no exceptions and no shorthand.** This rule is in the global AGENTS.md / CLAUDE.md "Surfacing to the User" section: deferred items are listed there explicitly alongside recommendations, decisions, review findings, blockers, and questions. Bullet-point shorthand like "§N [minor]: <terse title>. Latent - no current caller affected. Decide alongside Session 2." is exactly what that rule forbids - it's dev reasoning, not user-facing framing.

Bad surface (what the rule forbids):
> §4 [minor]: ClampedTimeInput draft state not re-synced when value prop changes externally. Latent - no current caller affected. Decide alongside Session 2 overview-table inline editor when the contract becomes clear.

Good surface (what the rule requires):
> ### §4: Time fields might show stale values when something else changes them
>
> **What it is:** The time-of-day input on the slot row keeps its own draft of what the user is typing. If a different part of the app (e.g., the upcoming inline editor in the overview table or the venue drawer in Session 2) pushes a new time value into that field from outside, the field today does not refresh to show that new value.
> **User-facing impact:** Today: nothing visible - no other part of the app pushes external time changes. When Session 2 ships the inline editor or venue drawer that does push them, a user could see a stale time in the input until they click out of the field and back in - and might overwrite the real value with their stale one if they hit Save before noticing.
> **Why I didn't just do it:** The right shape (force-resync vs warn-on-conflict vs lock) depends on which Session 2 surface lands first.
> **My recommendation:** Decide alongside the Session 2 inline editor, since that's the first caller that will trigger this.
> **Options:** "decide now" / "spawn separate task" / "skip - revisit when Session 2 starts"
> **Where:** `src/components/ClampedTimeInput.tsx:45`

If you cannot articulate a user-facing impact (even "no user-facing impact - purely internal"), you do not understand the finding well enough to surface it - re-read the reviewer's notes in §N before writing the block.

After processing, return:

  Deferred resolution summary:
  - Auto-resolved: <X> items (<sha-list>)
  - Need your input: <Y> items (see below)

  <If Y > 0:> [list of §N blocks above]
  Reply per §N with your pick (e.g., "§1: A", "§2: spawn", "§3: skip") - I'll apply.

  <If Y == 0:> "No items need your input."

  ## Try it yourself
  <ALWAYS compose this section if the diff touches any user-facing surface (UI, CLI output, API response shape). Don't skip just because phases were `tests-only`. Read `Residual manual test` lines across phases + diff context (route paths, hook names, button labels, command examples).

  Two flavors based on phase tags:
  - **Required** - if any phase was `has-residual`, those steps are the load-bearing manual verification. Lead with them.
  - **Optional** - if all phases were `tests-only`, prefix the section with "Optional - integration tests cover the behavior; this is for eyeballing visual polish, copy, animations, and anything tests can't see."

  Aim for the clarity of a coworker's "here's what I'd click to verify this shipped" message, not a checklist. Always note what tests already cover so the user knows what they're adding by clicking through.>
  <Omit only if the diff has zero user-facing surface (e.g. pure refactor, infra-only change). In that case write: "No manual verification - diff is internal only.">

Note: subagents can't call `mcp__ccd_session__spawn_task` directly. If a §N's recommendation is "spawn", return it as data; fly's main context invokes the spawn tool when the user picks it.

Plan steps:
- [ ] Step 1: read deferred.md (no-op if missing/empty)
- [ ] Step 2: for each §N, try to resolve (dispatch + commit) OR format as user-facing block
- [ ] Step 3: compose "Try it yourself" walkthrough from residual manual items (if any)
- [ ] Step 4: print summary; commit any deferred.md Status updates with message `chore: deferred resolution pass`
```

`Review: combined` because resolved fixes commit during this task and the cumulative diff still benefits from a review pass; unresolved items surface to the user (the user IS the reviewer for those).
