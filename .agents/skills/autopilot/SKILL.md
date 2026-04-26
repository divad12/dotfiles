---
name: autopilot
description: "Take a list of independent tasks, spin up parallel worktree agents for each, and run them through implement -> critique -> deep-review -> ship cycles autonomously. Present a checkpoint summary before final merge. Use when the user says 'autopilot', 'batch these tasks', 'run these in parallel', 'do all of these', or gives you a todo list and wants them done autonomously."
user-invocable: true
---

# Autopilot

Take a list of independent tasks, run them in parallel worktree agents, and drive each through a full implement-critique-review-ship cycle. The user reviews a checkpoint summary before anything merges to main.

## Why this works

Each task gets its own worktree, so agents can't step on each other. The critique loop catches issues early (cheaper than finding them in deep-review). The checkpoint before merge keeps the human in the loop on what actually lands. Tasks merge sequentially to avoid conflicts.

## Steps

### 1. Parse and validate the task list

The user provides a list of tasks. For each task, identify:
- **What** needs to be done (one clear deliverable per task)
- **Where** the work lives (which files/areas of the codebase)
- **Dependencies** between tasks (do any tasks touch the same files?)

If two tasks would modify the same files, flag them to the user and suggest running them sequentially rather than in parallel. Independent tasks run in parallel.

Present the parsed task list back to the user for confirmation before proceeding:

> "Here's what I'll run in parallel:
> 1. [Task summary] - [files affected]
> 2. [Task summary] - [files affected]
>
> [Any dependency warnings]
>
> Ready to go?"

### 2. Launch worktree agents in parallel

For each task, spawn a subagent with `isolation: "worktree"`. Each agent runs the following pipeline autonomously (steps 2a through 2d).

Give each agent a detailed prompt that includes:
- The specific task to implement
- Relevant context from CLAUDE.md and PROGRESS.md
- The full pipeline it should follow (below)
- Instructions to read the project's CLAUDE.md for conventions

#### 2a. Implement

The agent implements the task. It should:
- Read relevant existing code first to understand patterns
- Follow project conventions from CLAUDE.md
- Write tests if the project has a testing setup
- Run the type checker and linter after implementation

#### 2b. Critique loop (UI/UX focused)

After implementation, the agent steps back and critiques its own work from a user experience perspective. The deep-review step (2c) handles code correctness and quality - this step is about making sure the feature actually looks and feels right.

If the task has no frontend changes, skip this step entirely.

**Each round follows this structure:**

1. Start the dev server if not running
2. Use `playwright-cli` (or preview tools) to navigate to the affected pages
3. Take screenshots
4. Answer two questions honestly:
   - **What do I like about this?** - What's working well, what looks good, what feels right
   - **What could be improved?** - Be specific. Evaluate against: visual hierarchy, layout/spacing, states (empty, loading, error), interactions, consistency with existing design language, accessibility (contrast, keyboard nav, focus indicators)
5. Produce a numbered list of improvements. For each item, decide:
   - **Act on it** - clear improvement, low risk, worth doing now
   - **Skip** - subjective, high-effort, or would require rethinking the approach
6. Implement all "act on it" items
7. Take new screenshots to verify fixes

**Round 1:** Always runs for frontend work.

**Round 2 (conditional):** If round 1 acted on 3+ items, do another round - there are likely more things to catch now that the obvious issues are fixed. If round 1 acted on 0-2 items, the UI is in good shape - skip.

**Round 3 (rare):** Only if round 2 still acted on 3+ items. After 3 rounds, stop regardless.

**Tracking:** Keep a running log across all rounds:
- Items acted on (what was changed and why)
- Items skipped (what was left and why)
- Items that could still be improved (not worth doing autonomously, but worth mentioning)

Include this log in the agent's final report (step 2d). This gives the user visibility into what design decisions the agent made and what polish opportunities remain.

#### 2c. Deep review

Run the `/deep-review` skill (collateral audit, correctness, simplify, Codex, UI review).

- Auto-fix all must-fix and easy-win items
- For suggestions: apply anything that's clearly better and low-risk. Skip anything subjective or high-effort.
- Run a verification round (re-review after fixes)
- If the verification round surfaces new must-fix items, fix them. One verification round only.

#### 2d. Commit

Stage and commit all changes with a clear commit message. Do NOT merge yet - that happens after the checkpoint.

The agent should report back with:
- What was implemented
- How many critique rounds ran and what was found
- Deep review summary (what was fixed, what was skipped)
- The commit hash
- Any concerns or open questions

### 3. Checkpoint - present results to user

Once all agents complete, present a consolidated summary:

```
## Autopilot Results

### Task 1: [name]
Branch: [branch]
Commits: [count]
Critique rounds: [N] ([X] issues found and fixed)
Deep review: [Y] must-fix, [Z] easy-wins fixed. [W] suggestions skipped.
Status: Ready to merge / Needs attention

[Brief summary of what was done]
[Any open questions or concerns from the agent]

### Task 2: [name]
...

### Merge order
1. Task X (no dependencies)
2. Task Y (no dependencies)
3. Task Z (touches files near Task X - merge after X)
```

For each task, the user can:
- **Approve** - merge it to main
- **Review first** - look at the diff before deciding
- **Reject** - discard the worktree

Ask the user: "Which tasks should I merge? You can say 'all', list specific numbers, or ask to review any of them first."

### 4. Merge approved tasks sequentially

For each approved task, in the specified order:
1. Run `/merge` to rebase onto main and fast-forward
2. If there's a merge conflict (because an earlier task changed the same area), stop and tell the user. Don't auto-resolve cross-task conflicts.
3. Clean up the worktree after successful merge

Report the final state: which tasks merged, final commit on main, any that were skipped or had issues.

## Handling failures

- **Agent hits a wall** (can't figure out the task, blocked by a bug, needs clarification): The agent should stop, document what it tried and where it got stuck, commit whatever partial work exists, and report back. Don't spin wheels.
- **Critique loop not converging**: If round 2 finds as many issues as round 1, stop the loop and flag the task as needing human attention at the checkpoint.
- **Deep review finds architectural issues**: If deep-review surfaces suggestions that would require rethinking the approach, skip them and flag at checkpoint. Don't chase architectural rewrites autonomously.
- **Merge conflict**: Stop and present both sides to the user. Cross-task conflicts require human judgment about which approach wins.

## Rules

- **Never merge without checkpoint approval.** The whole point is the human reviews before anything lands on main.
- **Tasks merge sequentially, not in parallel.** Parallel merges cause race conditions on main.
- **Don't auto-resolve cross-task conflicts.** Within a single task's critique/review loop, auto-fix is fine. Across tasks, the user decides.
- **Respect the critique loop limits.** 3 rounds max. Diminishing returns are real.
- **Flag uncertainty.** If an agent isn't confident in its approach, it should say so in the report rather than shipping something dubious.
