# Session Breakdown Prompt

For plans with total tasks exceeding `single_file_cap` (default 20), present the user with a session breakdown before writing any files. For plans with 20 or fewer tasks, skip this step entirely (single session, no split needed).

## Prompt to present

```
Plan has <N> tasks across <M> phases:

| Phase | Tasks | Focus |
|---|---|---|
| 0 | 8 | <phase name/goal> |
| 1 | 10 | <phase name/goal> |
...

Default split (cap = 20 tasks/session) -> <K> sessions:
| Session | Phases | Tasks |
|---|---|---|
| 1 | 0-1 | 18 |
| 2 | 2-3 | 20 |
...

<Alternative split> -> <J> sessions:
| Session | Phases | Tasks | Why split here |
|---|---|---|---|
| 1 | 0 | 8 | Clean boundary before UI work |
| 2 | 1-2 | 15 | Related backend + API |
...

Tradeoffs:
| Axis | <K> sessions | <J> sessions |
|---|---|---|
| Per-session blast radius | ... | ... |
| Context budget per session | ... | ... |
| Ship-ability of each PR | ... | ... |

Recommend <one> because: <1-2 sentences>.

Pick: default (<K>), recommended (<J>), or specify your own grouping?
```

The alternative split should be computed by analyzing phase boundaries, domain concerns, and natural ship-points (where a PR would make sense). It may have more or fewer sessions than the default.

Wait for the user's response. Then proceed to write files matching the chosen split.
