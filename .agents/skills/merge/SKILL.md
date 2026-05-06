---
name: merge
description: "Use when the user asks to merge, land, rebase before landing, resolve landing conflicts, or advance an integration branch such as main, master, or m3."
allowed-tools: Bash(git:*)
user-invocable: true
---

# Merge Workflow

Read `~/dotfiles/docs/ai/git.md` first when available. It is the canonical
contract for Git history, squash, rebase, and merge-commit exceptions.

Clean up branch history, rebase the current branch onto the target branch, and
fast-forward the target to include the new commits. The target may be `main`,
`master`, or a feature integration branch such as `m3`.

## Steps

1. **Identify context**: Determine the current branch name, target branch, and
   target worktree path.
   ```bash
   BRANCH=$(git rev-parse --abbrev-ref HEAD)
   git worktree list
   TARGET_BRANCH="<target branch>"  # e.g. main, master, m3
   TARGET_REPO=$(git worktree list | awk -v target="[$TARGET_BRANCH]" 'index($0, target) {print $1; exit}')
   test -n "$TARGET_REPO"
   ```
   If the target branch is unclear, ask the user. Do not assume `main`: some
   repos use `master`, and some work lands into integration branches like `m3`.
   Do not use `origin/$TARGET_BRANCH` to decide whether the branch is current;
   the landing target is the local target branch.

2. **Inspect branch-only commits**:
   ```bash
   if git merge-base --is-ancestor "$TARGET_BRANCH" HEAD; then
     echo "Branch contains local $TARGET_BRANCH"
   else
     echo "Branch needs rebase onto local $TARGET_BRANCH"
   fi
   git log --oneline --decorate "$TARGET_BRANCH"..HEAD
   ```
   These checks must use the local target branch, not `origin/$TARGET_BRANCH`.
   If the branch contains noisy workstream, checkpoint, review-fix, or fixup
   commits, squash them before advancing the target. Make this judgment
   yourself; do not stop for user approval on routine cleanup. User-facing
   ramification: the target branch history stays readable, so future debugging
   shows the feature that landed instead of every intermediate agent pass.
   - Use `git rebase -i "$TARGET_BRANCH"` when keeping multiple meaningful
     commits.
   - Use `git reset --soft "$TARGET_BRANCH" && git commit` when the branch
     should land as one commit.
   - Do not rewrite published/shared branch history silently. If rewriting would
     surprise someone else, tell the user the ramification and ask first.

3. **Capture landing learnings, then run the before-landing learning check**
   from `docs/ai/git.md`. First identify any durable bug class, review finding,
   failed-command lesson, merge conflict pattern, or workflow issue from this
   branch that is not already captured in the last five active learnings or
   same-session learning memory. Invoke `/learn` capture for relevant new
   learnings, or update/skip existing entries when already covered. Announce
   each result with the required `🧠 Captured learning:` or
   `🧠 Learning already captured:` one-liner. Then run the check. If it
   reports high-confidence open learnings, stop and ask the user which action to
   take before landing: create prevention artifact, defer with follow-up, or
   acknowledge landing without the artifact.

4. **Rebase onto the local target branch**:
   ```bash
   git rebase "$TARGET_BRANCH"
   ```
   All operations use the **local** target branch, not `origin/<target>`. Do not fetch from origin.
   - If there are conflicts, resolve them file by file, then `git add <file>` and `git rebase --continue`.
   - **CRITICAL: During rebase, `--ours` and `--theirs` are SWAPPED compared to merge.** `--ours` = target branch (the branch you're rebasing onto). `--theirs` = your feature branch. So to keep the target version: `git checkout --ours <file>`. To keep your branch's version: `git checkout --theirs <file>`. This is counterintuitive; double-check every time.
   - Prefer rebase. If conflicts remain too risky even after squashing, abort
     the rebase, tell the user the ramification, and use the merge-commit
     exception from `docs/ai/git.md`.

5. **Advance the target branch**:

   Normal path: fast-forward the target to the current branch tip.
   ```bash
   git -C "$TARGET_REPO" merge --ff-only "$BRANCH"
   ```

   Merge-commit exception: if you already told the user the ramification and
   aborted a too-risky rebase, merge the feature branch into the target once.
   ```bash
   git -C "$TARGET_REPO" merge --no-ff "$BRANCH"
   ```

6. **Verify** the landing:

   Normal fast-forward path: both branches should point to the same commit.
   ```bash
   echo "Current branch ($BRANCH): $(git rev-parse HEAD)"
   echo "Target ($TARGET_BRANCH): $(git -C "$TARGET_REPO" rev-parse HEAD)"
   ```

   Merge-commit exception: the branch should be an ancestor of the target.
   ```bash
   git -C "$TARGET_REPO" merge-base --is-ancestor "$BRANCH" "$TARGET_BRANCH"
   ```

7. **Report** the result: which commits were added, whether noisy commits were
   squashed, any conflicts resolved, final commit hash.

## Rules

- **Keep target history meaningful.** Squash workstream/checkpoint/review-fix
  commits before landing.
- **Prefer rebase after squashing.** Create a merge commit only for the
  documented exception: replaying the already-cleaned branch is more error-prone
  than resolving conflicts once.
- **Resolve conflicts interactively.** If a rebase conflict occurs, show the user what conflicted and fix it. Don't abort unless explicitly asked.
- **Local only.** All operations and readiness checks use the local target
  branch, not `origin/<target>`. Do not `git fetch` or `git pull`. Do not push
  unless the user explicitly asks.
