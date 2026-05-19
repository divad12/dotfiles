---
name: merge
description: "Use when the user asks to merge, land, rebase before landing, resolve landing conflicts, or advance an integration branch such as main, master, or m3."
allowed-tools: Bash(git:*)
user-invocable: true
---

# Merge Workflow

Read `~/dotfiles/docs/ai/git.md` first. It is the canonical contract for target
selection, squash audits, local-target-only landing, rebase conflict handling,
and merge-commit exceptions.

Default path: inspect `<target>..HEAD`, squash noisy commits when needed,
rebase onto the local target branch, fast-forward the target worktree with
`git merge --ff-only <branch>`, then verify both refs.

## Capture landing learnings

Do not run `learn --repo "$PWD" check-merge` as a required merge gate.
Branch-relevant learnings can be captured during normal closeout without
blocking unrelated landings.
