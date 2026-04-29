# Synthetic Integration-Test Task

Injected by the manual-test convertibility analysis (see SKILL.md "Manual-test convertibility analysis") when a phase has multi-task glue worth asserting in jsdom-style tests.

When to skip injection (default = SKIP if in doubt):
- Phase already has an end-to-end test of the wire-up (unit tests of pieces don't count).
- Phase is single-task or single-component (no glue between task outputs to test).
- Phase is pure backend / pure data-layer (no jsdom-observable composition).
- Phase end-state is "looks right visually" (handoff to codex-browser-verify, jsdom blind to it).
- Per-task TDD already wrote integration-style tests across the pieces.

False-green synthetic tests look like coverage but aren't; better to under-inject and let user request than over-inject and dilute the audit trail.

## Task body to inject

```
Synthetic task: "Write integration test for Phase <N> end-state verification"
- Model: sonnet (DEFAULT) — upgrade to opus if any of the convertible steps require subtle setup (e.g., multi-process worker harness, complex mock graph).
- Review: combined.
- Files: implementer decides based on existing test conventions.
- Steps:
  * Step 1: READ the phase's actual implementation files + existing tests FIRST. Ground the synthetic test in real code, not the plan prose. The plan describes intent; the impl is the contract being tested. Mirror the existing tests' mock/fake/fixture style so the synthetic test contract matches production wiring (avoid mock-graph drift = false greens).
  * Step 2: write failing test covering: <list each convertible step verbatim, with the mock/fake/fixture noted>
  * Step 3: verify test fails for the right reason
  * Step 4: implement (only if test fails because the production code is missing the behavior; usually the production code already exists and the test just confirms it - in which case skip to step 5)
  * Step 5: verify test passes
  * Step 6: commit
```

This synthetic task gets treated EXACTLY like any plan task by fly: dispatched by an implementer subagent, reviewed by spec + code reviewers, etc. It's distinguished in the checklist with `[SYNTHETIC: integration-test]` prefix on the task title so reviewers know its provenance.

## Surface to user before injecting

Like the consolidation pass:

```
Phases proposing synthetic integration tests: [<list>]
Phases skipped (reason): [<list with reason: existing-e2e | single-task | pure-backend | visual-only>]
Confirm? (y / n / edit per-phase)
```

On `n`, drop all synthetic-integration injections. On `edit`, let user toggle per phase.
