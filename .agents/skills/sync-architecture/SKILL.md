---
name: sync-architecture
description: "Use when the user says 'sync architecture', 'update the architecture diagram', 'refresh architecture', or 'audit the diagram'. Also auto-invoked by /save and /deep-review, or after adding, removing, or renaming a top-level module."
user-invocable: true
---

# Sync Architecture Diagram

Detect architecture drift and **apply the fix directly** to `docs/ai/architecture.md`. No approval prompt - just edit the file and leave it unstaged so the user sees the diff in `git status` before the next commit. If the edit is wrong, `git checkout docs/ai/architecture.md` reverts in one command.

The goal: keep the diagram in sync with zero friction. Asking for approval on every run turns this into a chore; just updating + trusting git-as-review is the right ratio.

## Prerequisites

```bash
test -f docs/ai/architecture.md || { echo "No architecture.md - run /adaptive-docs-init first or create one manually"; exit 1; }
```

The diagram must contain a `## This diagram covers` section listing the paths it represents. Without that, the skill can't scope the check.

## Steps

### 1. Read the diagram and its coverage

Read `docs/ai/architecture.md`. Extract:
- The `mermaid` fenced block (the diagram itself)
- The `## This diagram covers` section (the list of paths)

If there's no coverage section, stop and tell the user to add one. The format is:

```markdown
## This diagram covers

- `src/app/api/**` - description
- `src/lib/foo/**` - description
```

Without coverage metadata, there's no principled way to decide what "in sync" means.

### 2. Find when the diagram last changed

```bash
LAST_ARCH_COMMIT=$(git log -1 --format=%H -- docs/ai/architecture.md)
LAST_ARCH_DATE=$(git log -1 --format=%ai -- docs/ai/architecture.md)
```

If the file has never been committed, use the working directory as the baseline and compare to `main`.

### 3. Find what's changed in the covered paths since then

For each path in the coverage section:

```bash
git log --since="$LAST_ARCH_DATE" --name-status -- <path>
```

Collect:
- **New files** (`A` status) - might mean a new component
- **Deleted files** (`D` status) - might mean a removed component
- **Renamed files** (`R` status) - might mean a reorganization
- **Modified files** (`M` status) - usually internal changes, NOT architecture-affecting

The key signal is **structural change** (add/delete/rename), not line-level edits. Modifications to internals of an existing module rarely need diagram updates.

### 4. Classify the changes

For each structural change, ask:

- Does this add a **new top-level module** (e.g. a whole new `src/lib/billing/` directory)? → diagram likely needs a new box
- Does this **remove a top-level module**? → diagram likely needs to remove a box
- Does this **move files between modules** (e.g. `src/lib/timing/recalculate.ts` → `src/lib/cascade/recalculate.ts`)? → diagram label or arrow probably needs updating
- Is it just a **new file inside an existing module** (e.g. `src/app/api/events/[id]/archive/route.ts` when `src/app/api/events/**` already exists)? → no diagram change needed

**If no structural changes found, tell the user the diagram is still in sync and exit.** Don't propose cosmetic edits.

### 5. Apply the update directly

If structural changes exist, **edit `docs/ai/architecture.md` now**. Do not ask for approval.

What to update:
- **The mermaid block** - add boxes/arrows for new top-level modules, remove boxes for deleted ones, rename labels for moved modules
- **The `## This diagram covers` list** - if code changed under a path not in the coverage list, expand the list to include it (paths are additive by default)
- **The prose below the diagram** - only touch if a prose sentence directly contradicts the new shape (e.g. prose says "two modules" but diagram now shows three). Don't rewrite prose for style.

What to preserve:
- The banner header (line 1) - never touch
- Section ordering
- Any "For deeper detail" pointers at the bottom

### 6. Report what changed

In your skill output, tell the user:

```
Updated docs/ai/architecture.md:
  - Added box for `src/lib/billing/` (new top-level module since last diagram update)
  - Removed box for `src/lib/legacy-timing/` (deleted this session)
  - Expanded coverage list to include `src/lib/billing/**`

Left unstaged. Review with `git diff docs/ai/architecture.md`. Revert with
`git checkout docs/ai/architecture.md` if the update is wrong.
```

Be specific. Every bullet should reference the structural change that triggered it.

### 7. Don't commit

Leave the edit as an unstaged change. The user commits it bundled with the code change that triggered the drift, or with the next `/save`.

## When to say "no drift, all good"

Resist the urge to suggest changes for the sake of it. A good outcome is often "the diagram is still accurate - no action needed." Look for these **non-signals**:

- Lots of modifications to internals (normal feature work, doesn't change shape)
- New tests in `__tests__/` directories (tests don't appear in the diagram)
- Bug fixes (usually don't change shape)
- Refactors within a single module

And these **real signals**:

- New directory at `src/lib/<x>/` that isn't in the coverage list
- Deleted directory that WAS represented as a box
- A module split (one directory became two)
- A module merged (two directories became one)
- A new external service (new Supabase feature, new third-party API)
- Data flow change (e.g. introducing a queue between two components)

## Scope discipline

- **Architecture is about shape.** This skill updates the shape. It does not rewrite prose unless a prose sentence directly contradicts the new shape.
- **Don't re-litigate design decisions.** If the user chose to represent something a certain way in the original diagram, respect that. Make the minimal patch - add/remove/rename boxes, don't redesign the layout.
- **Expand coverage automatically.** If code changed under a path NOT in the coverage list but clearly belongs (new top-level module), add it to the coverage list. Note what was added in the skill output. The user can trim it back if they disagree.
- **One shot, not a loop.** Make the update, report what changed, done. Don't iterate trying to perfect it.

## Failure modes to avoid

- **Suggesting edits for every session.** The diagram is stable by nature. Most sessions produce zero proposed changes. That's success, not failure.
- **Hallucinating files.** Before claiming "the diagram doesn't mention `src/lib/X/`", verify `src/lib/X/` actually exists as a top-level module with substantive content - not a single utility file.
- **Over-fitting to the code.** The diagram is a useful abstraction, not a 1:1 inventory. Don't propose adding every new directory. Ask: "does a new reader of the diagram benefit from knowing this box exists?"

## If `docs/ai/architecture.md` doesn't exist

Don't create it in this skill. That's the job of `/adaptive-docs-init` step 8b (or manual creation). Bail with a clear message.
