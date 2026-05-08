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

## Before Merging to the Target

Inspect the commits that would land:

```bash
git log --oneline --decorate <target>..HEAD
```

If the list is riddled with agent workstream commits, squash before advancing
the target branch. Good final history should answer "what changed?" rather than
"how many review passes happened?"

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

## Worktree Recovery

When work has accidentally landed in the main checkout, resist the reflex to
create another worktree. First, check whether a clean, suitable worktree
already exists:

```bash
git worktree list
```

If an existing worktree has no branch-only commits and is otherwise clean,
prefer it over creating a new one:

1. Checkpoint the accidental work on the main checkout (commit to a throwaway
   branch or stash).
2. Fast-forward the existing worktree's branch to the target:
   ```bash
   git -C <worktree-path> fetch origin <target>
   git -C <worktree-path> checkout <target>
   ```
3. Cherry-pick or re-apply the checkpointed work there.

Creating a new worktree when a clean one already exists adds sprawl and
leaves abandoned branches. A clean existing worktree is the safest landing
zone after recovering from accidental main-checkout edits.

## The Merge Workflow

When the user says "merge" or uses the `/merge` skill:

1. Identify the target branch.
2. Inspect `<target>..HEAD` and squash noisy workstream commits.
3. Rebase the feature branch onto local `<target>`.
4. If the rebase is practical, fast-forward the target with
   `git merge --ff-only`.
5. If the rebase becomes too error-prone even after squashing, abort it and
   merge the feature branch into the target with `git merge --no-ff`.
6. Verify the target contains the feature branch changes.

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
- `git merge --ff-only <branch>` advances the target when the branch is rebased.
- `git rev-parse HEAD` on the feature branch matches `git rev-parse <target>`
  after a successful fast-forward merge.
- For the merge-commit exception, `git merge-base --is-ancestor <branch>
  <target>` succeeds after landing.
