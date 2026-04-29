# Final Verify Output Handling

After all tasks, phase regression checks, and the session gate are processed, run the verification block at the bottom of the checklist:

```
bash $SCRIPT_DIR/final-verify.sh <checklist-path>
```

## Output cases

### `PASS`

All checks passed. Proceed to tick each verification checkbox in the checklist (via Edit) and emit the Completion message.

### `HALT: <summary>`

The preceding lines enumerate specific failures (unticked boxes, unfilled slots, mismatched findings counts, missing phase regression check prefix, etc.). Do NOT tick verification checkboxes. Surface the full failure list to the user.

### `WARN: ...`

Soft signals (e.g., fabrication-pattern rate exceeded). Surface to the user but do not HALT.

### `DEFERRED:`

Block contains the full `<plan>-deferred.md` contents.

**Do NOT dump verbatim to the user.** The preflight checklist's final `[SYNTHETIC: deferred-resolution]` task handles it: a fresh subagent resolves what it can (dispatches implementer, commits) and returns ONLY items that need the user's input, each with a recommendation + options (or do-now / spawn / skip if it's a follow-up). Surface that return value to the user as-is.

For any item the user picks "spawn" on, invoke `mcp__ccd_session__spawn_task` from your main context with the item's title + tldr + a self-contained prompt from the deferred.md §N entry. (Subagents lack access to that tool.)

## Why this lives in the script

The previous bulleted list of individual checks is preserved in the script itself for maintainers. Fly's job here is to invoke, parse, and react.
