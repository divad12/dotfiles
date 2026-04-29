# Per-Task Integrity Gate

After filling BOTH Outcome slots for a task (end of review-and-fix loop in step F for the standard combined path, or end of step F for `Review: separate` tasks), fly MUST invoke the integrity-check script before moving on. This is mandatory, not optional.

## Why this exists

Under context pressure, the orchestrator can forge review artifact files directly (write a plausible file with a `findings-count: 0` YAML header and a `No issues.` body) without ever dispatching a reviewer subagent. All the existing mtime, size, and YAML-header checks pass because the orchestrator is the one writing the file. Self-report cannot catch this failure mode; on-disk evidence from Claude Code's own per-subagent JSONL transcripts can.

The integrity-check script reads the CC subagent transcripts at `~/.claude/projects/<encoded-cwd>/<session>/subagents/agent-*.jsonl` and verifies:

1. A real subagent actually authored the review file (matched by prompt-text containing the review path).
2. The subagent did non-trivial work (at least 3 tool calls, consistent with reading the diff and writing the review).
3. **The subagent ran on the EXACT model the checklist annotated** for that task and review type. Reads `message.model` from the JSONL, normalizes to a family (haiku/sonnet/opus), and compares against the `(reviewer: <model>)` annotation from the checklist. Catches silent model downgrades (e.g., sonnet checklist annotation but haiku-dispatched reviewer to save cost) - the post-hoc enforcement of the dispatch-reviewer.sh contract.

## Invocation

Use `$SCRIPT_DIR` resolved per the SKILL.md "Helper Scripts" section. Invoke via single Bash tool call:

```
bash $SCRIPT_DIR/integrity-check.sh <task-id> <plan-dir> <task-sha>
```

Output is one line on stdout:

- `PASS` (exit 0) - integrity verified. Proceed to the next task.
- `HALT: <reason>` (exit 1) - integrity failed. STOP immediately. Do NOT try to patch the symptom (e.g., re-dispatching the reviewer, re-writing the file, tweaking slots). Surface the HALT reason to the user verbatim. This is drift detection; the user needs to see it.

## Phase-deferred (`Review: phase`) tasks

For tasks annotated `Review: phase`: no per-task review files are expected. The script returns `PASS` silently. Run the integrity gate against the LAST task in the phase that DOES have a per-task review, plus the phase normal review at end-of-phase.

## Agent-agnostic caveat

The script is Claude Code specific. It depends on the `~/.claude/projects/.../subagents/agent-*.jsonl` layout. On non-CC agents it will HALT with `cannot locate CC project dir`; that is acceptable because the entire subagent dispatch mechanism `/fly` uses is already CC-specific.
