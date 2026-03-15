---
name: ship
description: "Save progress, commit all changes, and merge into main in one go. Use when the user says 'ship', 'ship it', 'save and merge', 'wrap up', 'finalize', or 'done - commit and merge'."
user-invocable: true
---

# Ship

Save progress, commit, and merge into main. This chains three operations in sequence, stopping if any step fails.

## Steps

1. **Run the `/save` skill.**
   This updates PROGRESS.md (and TECH_DEBT.md if relevant) to reflect the current session's work.

2. **Commit all changes.**
   - Run `git status` and `git diff` to see what's changed (staged and unstaged).
   - Run `git log --oneline -5` to match the repo's commit message style.
   - Stage all relevant files. Be deliberate about what you stage - don't blindly `git add -A`. Skip files that look like secrets (`.env`, credentials, etc.).
   - Write a concise commit message summarizing the work. Focus on the "why" not the "what".
   - If the user provided a commit message, use that instead.
   - If there are no changes to commit, skip to step 3.

3. **Run the `/merge` skill.**
   This rebases onto main and fast-forwards main to include the new commits. If there are conflicts, resolve them before continuing.

4. **Report** the result:
   - What was saved (PROGRESS.md updates)
   - What was committed (summary + commit hash)
   - Merge result (main now at which commit)

## Rules

- **Stop on failure.** If save, commit, or merge fails, stop and tell the user what went wrong. Don't continue to the next step.
- **Don't push.** Just like `/merge`, this only updates local branches. The user pushes when ready.
- **Don't skip the save step.** Even if the user says "just commit and merge", run save first. PROGRESS.md should always reflect the latest state before a commit.
- **Ask before committing untracked files you don't recognize.** If there are untracked files that weren't created in this session, ask the user before staging them.
