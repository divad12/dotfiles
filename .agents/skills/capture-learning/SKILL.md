---
name: capture-learning
description: "Use when the user says 'document this', 'capture this', 'remember this for next time', 'update the docs', or after fixing bugs and discovering patterns worth preserving. Also triggered by /save."
user-invocable: true
argument-hint: "[what was learned]"
---

# Capture Learning

Turn a specific fix, feedback, or discovery into a durable, generalized principle in the project's documentation. The goal: **never fix the same class of bug twice.**

## What to capture

Review the session for:

- **Bug fixes** - what went wrong, why, and the fix (as a code comment AND as a principle in docs)
- **Conventions** discovered or established during implementation
- **Architecture decisions** with rationale that would prevent re-debating
- **"We tried X and it didn't work"** insights that would prevent re-attempting
- **Validation rules, edge cases, or integration patterns** learned the hard way
- **Workflow improvements** or tool usage patterns

## Before writing anything: check existing rules

**Most "new learnings" are just examples of existing rules.** Before adding anything, search CLAUDE.md and docs/ai/ for principles that already cover this case. If the codebase was written before the rule existed, the fix is to make the code comply with the existing rule - not to add a new rule.

Ask: "If someone had followed the existing rules perfectly, would this bug still have happened?"
- **Yes** - you've found a genuine gap. Proceed to capture a new principle.
- **No** - the rule exists but wasn't followed. The fix is the code change, not a new doc entry. At most, add the specific case as an example under the existing rule if it's a non-obvious application.

## The Abstraction Ladder

If you've confirmed this is genuinely new, climb the abstraction ladder. Start with what happened, then ask "why" repeatedly to find the underlying principle.

**Example:**

```
Specific fix:   Walk time number picker allowed negative values
     ↑ Why?
Class of bug:   Form inputs lacked min/max constraints
     ↑ Why?
Pattern:        Validate at the boundary - constrain inputs to valid values
     ↑ Why?
Principle:      Every user-facing input must make invalid states unrepresentable
```

Write the **principle** as the main rule. Use the specific fix as an illustrative example underneath.

### How to climb

1. **What happened?** The specific bug, feedback, or discovery.
2. **What class does this belong to?** What other bugs share the same root cause?
3. **What principle, if followed, would have prevented all of them?** This is what goes in the docs.
4. **Is there an even higher principle?** Stop when the next level up becomes too vague to be actionable.

The sweet spot is the highest level that's still **actionable** - concrete enough that a developer would know what to do differently. "Be careful" is too vague. "Every form input must have min/max bounds matching the domain model" is actionable.

**One more level.** Once you think you've found the principle, try climbing one more rung. Ask: "Is there an even more general rule that subsumes this?" Often there is. Example: "Every form input must have min/max bounds" generalizes to "Make invalid states unrepresentable at the input layer." The more general version covers more future cases. Only stop when the next level becomes too vague to act on.

## Format

Write the learning as:

```markdown
**Principle statement** (1-2 sentences, actionable)

Example: [specific case that prompted this, 1-2 sentences]
```

Keep it short. If the principle needs more than 3 sentences, it's too complex - split it or simplify.

## Where to route it

### If the project has `docs/ai/`

1. Read `docs/ai/README.md` (or `docs/ai/writing-docs.md` if it exists) for the file inventory and routing guidance
2. Find the right file by topic from the inventory - match the learning to the doc that covers that area
3. If no file fits, consider: does this warrant a new file? If not, it might belong in root `CLAUDE.md` (only if truly universal) or as a code comment (if specific to one location).
4. **Also add a code comment** at the fix site if the "why" isn't obvious from the code.

### If the project has no `docs/ai/`

Route to `CLAUDE.md` (or `AGENTS.md`). Keep it brief - every line costs instruction budget.

### Update indexes

After adding to a doc, check if any indexes need updating. Common index locations:
- Root `CLAUDE.md` reference table (if it has one)
- Root `AGENTS.md` reference table (if it exists)
- `docs/ai/README.md` file table (if it exists)
- Skill descriptions in `.agents/skills/` or `.claude/skills/`
- Nested `AGENTS.md` or `CLAUDE.md` files in source directories

Usually the indexes don't need changing (the learning goes into an existing doc). Only update indexes if you created a new file or significantly changed a file's scope.

## Writing principles

- **One canonical location.** Never write the same principle in two docs. Other docs can reference it.
- **Actionable over descriptive.** "Do X" beats "X is important." "Check Y before Z" beats "Y and Z are related."
- **Examples ground principles.** A principle without an example is a platitude. An example without a principle is an anecdote. Include both.
- **Delete to improve.** If the target doc is getting long, look for entries that are now redundant, outdated, or subsumed by the new principle. Consolidate.
- **Instruction budget matters.** These docs are read by LLMs. Every line competes for attention. A 50-line doc with 10 sharp principles beats a 200-line doc that covers everything.

## Present to user

After writing, show the user what you captured and where:

```
📝 Learning captured:

Principle: [the generalized principle]
Example: [the specific case]
Location: [target doc file path] (under "[section heading]")
Code comment: [source file path:line] (if applicable)

Want me to adjust the wording or move it somewhere else?
```

## Anti-patterns

- **Adding a rule that already exists.** The most common mistake. Search existing docs first. If the principle is already there, the learning is "fix the code to follow the rule" - not "add another rule."
- **Too specific.** "Walk time picker must not allow negatives" - this only prevents one bug, not the class.
- **Too vague.** "Always validate inputs" - everyone knows this. What specifically should they check?
- **Duplicating.** Writing the same principle in two docs. Pick one, reference from the other.
- **Stuffing root CLAUDE.md.** Only truly universal principles go there. Topic-specific learnings go in topic-specific docs.
- **Skipping the code comment.** The docs capture the principle. The code comment captures the "why" at the exact location where someone will encounter the code.
