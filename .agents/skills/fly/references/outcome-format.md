# Outcome Slot Format

When filling `Outcome: \`<fill>\`` slot, use the structured single-line format:

```
findings=N fixed=N deferred=N (review: <path>); <one-sentence summary>
```

## Tokens

- `findings=N` - total admissible findings (numbered, prioritized, disposition-tagged, cited).
- `fixed=N` - findings fixed by fix-implementer loop. Includes any priority; disposition is `[fix]`.
- `deferred=N` - findings written to `-deferred.md`. Only legitimately `[defer]` dispositions (user decision / phase-sized / extremely risky), plus any `[fix]` findings that genuinely BLOCKED after model upgrade.
- `review: <path>` - MANDATORY reference to the review artifact file (e.g. `review: reviews/task-7.4-code.md`). SHA-equivalent: no artifact = no review happened. For deep-reviews, use the normalized file path: `review: reviews/session-deep-review.normalized.md`.
- `<summary>` - one sentence describing the outcome.
- Optional priority breakdown: `(crit=N maj=N min=N cos=N)`.
- Optional: `inadmissible=N` for findings discarded for missing number/priority/disposition/citation.
- Optional: `(normalized: +N)` for deep-review outcomes where normalization pass surfaced more findings than the consolidated list.

## Invariants

- `findings == fixed + deferred`. If mismatch, the orchestrator lost a finding. Halt.
- `review:` path points to a file that exists, has matching YAML header, and contains exactly `findings` `### Finding N:` sections.

## Examples

- `findings=0 fixed=0 deferred=0 (review: reviews/task-7.4-code.md); No issues.`
- `findings=12 fixed=11 deferred=1 (review: reviews/session-deep-review.normalized.md, normalized: +4); 11 inline; §5 deferred (user UX decision).`
- `findings=3 fixed=3 deferred=0 (review: reviews/task-3.1-combined.md) (crit=0 maj=1 min=2 cos=0); fixed in c4f9a2b.`

Prose-only Outcomes (no `findings=` token OR no `review:` token) fail Final Verification.
