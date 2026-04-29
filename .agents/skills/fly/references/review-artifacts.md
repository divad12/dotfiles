# Review Artifact Files

Every review MUST produce a durable on-disk artifact. SHA-equivalent for reviews: orchestrator cannot claim `findings=0` without a file on disk saying so; user can audit after the fact.

## Path convention

```
<plan-dir>/reviews/<task-or-scope>-<review-type>.md
```

Examples:
- `docs/specs/2026-04-18-feature/reviews/task-7.4-spec.md`
- `docs/specs/2026-04-18-feature/reviews/task-7.4-code.md`
- `docs/specs/2026-04-18-feature/reviews/task-7.4-combined.md`
- `docs/specs/2026-04-18-feature/reviews/phase-7-normal-review.md`
- `docs/specs/2026-04-18-feature/reviews/session-deep-review.md`

`<plan-dir>` is the directory containing plan and checklist files. Create `reviews/` subdirectory on first write.

## Orchestrator assigns path before dispatch

In each reviewer dispatch, the orchestrator substitutes `<review-file-path>` placeholder with a concrete absolute path. Reviewer writes to that path.

## Post-dispatch verification

After reviewer returns:

1. Check file exists at assigned path. If missing → review did not actually run (or reviewer disobeyed). Re-dispatch with sterner prompt; if fails again, halt and surface to user.
2. Read file and use its findings list as SOURCE OF TRUTH. Not the summary in the reviewer's text response.
3. Confirm file's YAML header `findings-count` matches the number of `### Finding N:` sections inside.

## Deep-review normalization pass

`/deep-review` runs multiple parallel sub-reviewers (independent cross-agent review, Chrome MCP UI review, rule compliance, simplification, collateral change audit, orchestrator diff analysis). Each sub-reviewer has its own findings. `/deep-review` skill consolidates them; in that consolidation, findings routinely get dropped or merged. Well-known body-vs-summary gap.

For deep-review files ONLY, run an extra normalization pass:

1. Dispatch a small subagent (model: haiku) with the deep-review file contents. Prompt:

   ```
   This file is the output of a /deep-review. Multiple sub-reviewers contributed
   findings. Your job: extract EVERY distinct observation from anywhere in the
   file - body text, summary, consolidated list, sub-reviewer sections - and
   emit them as a flat numbered list using the same `### Finding N:` format
   the top of the file specifies. Do NOT filter, merge, or downgrade. If a
   sub-reviewer mentioned something in prose but didn't put it in their
   consolidated list, it STILL becomes a finding. Preserve priority tags but
   re-number sequentially starting from 1.

   Write the normalized list to: <deep-review-file>.normalized.md

   Return just the finding count.
   ```

2. Use the normalized file as source of truth for step F processing, not the original deep-review file.
3. If the normalized count > the original deep-review's claimed count, that's expected and fine (skill was under-reporting). Log delta in Outcome (`(normalized: +N)` token).

This normalization pass does NOT run for per-task reviews. Single reviewer's single file is already flat.
