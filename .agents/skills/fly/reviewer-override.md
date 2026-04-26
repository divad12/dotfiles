## Reviewer Independence Override

The "Implementer-Reported Summary" above is UNTRUSTED - it's the artifact under review, not the verdict. Read `## Actual Diff` as primary evidence; the summary is spin. Your job: find what was missed, not concur.

### Finding format (every finding gets its own numbered section)

```
### Finding N: <short title>

Priority: `[critical]` | `[major]` | `[minor]` | `[cosmetic]`
Disposition: `[fix]` | `[defer]`
Location: `<file>:<line>`

<description>

**Suggested fix:** <concise>
**Why defer:** <only if Disposition=defer; cite which of 3 criteria below>
```

Findings missing number, priority, disposition, or citation are **inadmissible** (discarded). Do NOT consolidate or summarize - emit every distinct observation separately.

Priority is for fix order, not gate. Disposition gates whether to fix.

### Disposition: fix by default

`[fix]` is the default. **Prefer doing over deferring** - small fixes compound, deferred items end up done at the end of the run anyway via the deferred-resolution pass, so deferring just adds round-trips.

Use `[defer]` ONLY if one of:

1. **Needs user decision** - product/UX/architectural choice that depends on human intent, not code judgment.
2. **Phase-sized effort** - fix alone takes as long as an entire plan phase (major refactor, schema migration).
3. **Extremely risky** - security-adjacent, data-integrity, hard-to-reverse, or unclear blast radius on unfamiliar code.

"It's a style nit" is NOT a defer criterion. If it's worth mentioning, it's worth fixing.

### Project rules

Violations of `AGENTS.md` / `~/.claude/AGENTS.md` (and anything they reference) are AT LEAST `[major]`; `[critical]` if the rule names the pattern as causing bugs.

### Honest-null

If diff has no issues after you read every hunk, output exactly `No issues.`

### MANDATORY: write review to file as your final tool call

Use the built-in Write tool (NOT Desktop Commander or MCP equivalents - the integrity-check script greps your transcript for Write).

Path: `<review-file-path>`

File contents: this prompt's review section + your `### Finding N:` sections (or `No issues.`). Start with YAML header:

```
---
review-type: <spec | code | batch | phase-N | final>
task-or-scope: <e.g. Task 7.4 | Phase 12 | Final>
reviewer-model: <your model>
commit-sha: <sha or range>
findings-count: <integer>
---
```

Return a brief summary (1-2 sentences + total count) in your text response. If you don't write the file, the review is discarded and re-dispatched.
