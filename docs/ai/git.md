> **IMPORTANT: Before reading, check if you already read this file earlier in this session. If yes, skip the read and announce "Context already loaded: git.md (re-using from earlier)". If no, read it and announce "Context loaded: git.md".**

# Git Conventions

## Contract

- Keep the target branch history user-meaningful. The target may be `main`,
  `master`, or a feature integration branch such as `m3`. Before landing a
  branch, inspect the branch-only commits and squash noisy workstream,
  checkpoint, review-fix, or fixup commits into one coherent commit or a small
  set of meaningful commits.
- Use `git rebase <target>` by default. Keep history linear when the rebase is
  practical.
- Treat the local target branch as the landing authority. Do not use
  `origin/<target>` to decide whether a rebase or merge is needed.
- Use a merge commit only as a narrow exception: after history cleanup, rebasing
  the branch is still more error-prone than resolving conflicts once.
- Tell the user before choosing a history tradeoff. The ramification is what
  the target branch history will look like and whether conflict resolution
  happens once or across several rebased commits.

## Choose the Target Branch

Use the branch the user named. If the user did not name one, infer only from
clear repo context such as the checked-out integration worktree or an existing
single default branch. Do not assume every repo lands to `main`; some use
`master`, and feature programs may land into a branch like `m3`.

If the target is unclear, ask before rewriting history or landing commits.

## Local Target Only

All landing decisions use the local target branch. Do not fetch, pull, or switch
the comparison base to `origin/<target>` unless the user explicitly asks.

Forbidden shortcut:

```bash
git merge-base --is-ancestor origin/<target> HEAD
```

That check answers whether the branch contains the remote-tracking ref, not
whether it is ready to land into the local target branch. It can hide that the
local target worktree is stale or that the agent silently changed the base of
comparison.

Use the local target instead:

```bash
git merge-base --is-ancestor <target> HEAD
git log --oneline --decorate <target>..HEAD
```

If the agent believes `origin/<target>` has relevant commits, tell the user the
ramification: remote-tracking refs may be newer than the local landing branch,
but the current workflow lands into the local target. Ask before fetching,
pulling, or treating `origin/<target>` as authoritative.

## Before Merging to the Target

Inspect the commits that would land:

```bash
git log --oneline --decorate <target>..HEAD
```

If the list is riddled with agent workstream commits, squash before advancing
the target branch. Good final history should answer "what changed?" rather than
"how many review passes happened?"

### Default squash mapping for /fly output

`/fly` produces a feat → review → fix-review-findings → orch-inline pattern
per task. When landing a `/fly` branch, every commit matching either of these
patterns is a `fixup` candidate for the immediately preceding `feat:`,
`refactor:`, or top-level `fix(scope):` commit:

- `fix:.*review findings` — per-task review fixes
- `fix:.*orch-inline` — orchestrator-applied review fixes
- `fix(test):` immediately following a `feat:` for the same area
- `docs(checklist):` paired with the task it describes

Run a squash audit before rebasing and make the cleanup decision yourself.
Do not stop for approval on routine history cleanup. Surface the mapping only
when it is ambiguous, risky, or would surprise someone else.

Use interactive rebase when keeping several meaningful commits:

```bash
git rebase -i <target>
```

Use a soft reset when the branch should land as one commit:

```bash
git reset --soft <target>
git commit
```

Do not rewrite published/shared branch history silently. If rewriting would
surprise someone else, tell the user the ramification and ask first.

## The Merge Workflow

When the user says "merge" or uses the `/merge` skill:

1. Identify the target branch.
2. Inspect `<target>..HEAD` to count the commits that would land.
3. Run the squash audit and choose the history cleanup plan yourself. Report
   the result in the final summary; pause only for ambiguous/risky history
   rewrites.
4. Squash per your chosen plan (interactive rebase or soft reset).
5. Capture landing-relevant learnings, then run the before-landing learning
   check.
6. Rebase the squashed feature branch onto local `<target>`.
7. If the rebase is practical, fast-forward the target with
   `git merge --ff-only`.
8. If the rebase becomes too error-prone even after squashing, abort it
   and merge the feature branch into the target with `git merge --no-ff`.
9. Verify the target contains the feature branch changes.

## The Squash Audit

Run this before history cleanup so the target branch stays readable. The audit
produces three numbers and a proposed mapping; use them to decide whether to
land as-is, squash to one commit, or interactively squash noisy fixups into
their feature parents.

```bash
TOTAL=$(git log --oneline <target>..HEAD | wc -l | tr -d ' ')
REVIEW_FIX=$(git log --oneline <target>..HEAD \
  | grep -cE 'fix:.*review|fix:.*orch-inline|fix\(test\):')
MEANINGFUL=$(git log --oneline <target>..HEAD \
  | grep -cE '^[a-f0-9]+ (feat|refactor|fix\([a-z]+\)):')
```

Default decision rules:

- If there is one meaningful commit and no fixup noise, land it as-is.
- If the branch is one coherent feature with multiple workstream/fixup commits,
  squash to one commit.
- If the branch contains several meaningful features, keep a small set of
  meaningful commits and fold review/fixup commits into their parents.
- If the rewrite could surprise someone else because the branch is published,
  shared, long-lived, or semantically unclear, tell the user the ramification
  and ask before rewriting.

The audit must run regardless of branch size, but it is not a user approval
checkpoint. Include the chosen cleanup in the final report, e.g. "squashed 4
fixup commits into 2 feature commits" or "landed 1 clean commit as-is."

## Before-Landing Learning Check

After the squash audit is complete and before rebasing or fast-forwarding the
target, identify any durable bug class, review finding, failed-command lesson,
merge conflict pattern, or workflow issue from the branch. Invoke `/learn`
capture for relevant new learnings, but first check the last five active
learnings and same-session captures so duplicates are skipped or updated instead
of recreated.
Announce each capture or skip with the session-visible `🧠 Captured learning:` /
`🧠 Learning already captured:` one-liner.

Then run:

```bash
bin/learn --repo "$PWD" check-merge
```

If high-confidence open learnings are reported, surface them in plain English
with the user-facing ramification. Ask whether to create the prevention
artifact, defer with an explicit follow-up, or acknowledge landing without the
artifact.

This checkpoint prevents a branch from landing with only chat memory of a bug
class or review finding. It does not replace TDD or code review; it decides
whether a prevention artifact is needed before landing.

## Merge-Commit Exception

Squashing noisy commits before landing should make this exception rare. Keep it
because it protects against the remaining case where replaying the branch is the
riskier operation: for example, a long-lived branch with broad conflicts where a
single merge resolution is safer and easier to audit than conflict resolution
across a rebase.

Before using the exception, tell the user the ramification: the target branch
will include a merge commit, but conflict resolution happens once.

## Guardrails

### Never `git reset --hard` on the target branch

Other worktrees may have merged to the target branch in the meantime. A hard
reset wipes those commits. This has caused lost work before and required reflog
recovery.

Instead, rebase the feature branch by default, then `git merge --ff-only` to
advance the target. If ff-only fails, the histories diverged; rebase first
unless the merge-commit exception applies.

### Do not substitute `origin/<target>` for the local target

Remote-tracking refs are not the landing branch. If local `<target>` is stale,
surface that as a decision for the user instead of declaring the branch current
because it contains `origin/<target>`.

### Rebase: `--ours` and `--theirs` are swapped

During `git rebase`, `--ours` is the branch you're rebasing onto (`<target>`)
and `--theirs` is your feature branch. This is the opposite of `git merge`.
Double-check every time.

- Want the target branch version during rebase? Use `git checkout --ours <file>`.
- Want your branch's version during rebase? Use `git checkout --theirs <file>`.

### Amend for review fixes

When fixing small issues from code review, amend the previous commit with
`git commit --amend` instead of creating a new commit. Only create a new commit
if the fixes are substantial enough to warrant their own history entry.

Only amend if the commit has not been merged to the target branch yet, or if you
can safely rebase afterward without losing other work.

## Verification

- `git log --oneline <target>..HEAD` shows only meaningful commits before
  landing.
- `git merge-base --is-ancestor <target> HEAD` is checked against the local
  target, not `origin/<target>`.
- `git merge --ff-only <branch>` advances the target when the branch is rebased.
- `git rev-parse HEAD` on the feature branch matches `git rev-parse <target>`
  after a successful fast-forward merge.
- For the merge-commit exception, `git merge-base --is-ancestor <branch>
  <target>` succeeds after landing.
