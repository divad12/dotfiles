# Codex-browser-verify Synthetic Task

Inject `[SYNTHETIC: codex-browser-verify]` ONLY when THIS checklist's session has actual browser-verifiable work - i.e., at least one task in this checklist mounts UI, modifies UI flow, or has a verification step that involves clicking/navigating/observing UI behavior. If this session is backend-only / foundations / data-layer / pure infra (no UI mounted, no flows to click), DO NOT inject the task at all - omit it from the checklist entirely.

Per-checklist, not feature-level. Multi-session plans where Session 1 = backend foundations and Session 2 = UI wire-up: Session 1's checklist has NO codex-browser-verify task; Session 2's does.

Skip entirely if `codex_browser_enabled = false`. When skipped, residual manual stuff falls back to Try-it-yourself.

Codex has native browser execution; when injected, this task dispatches codex to do the real-browser equivalent of what the integration test covers in jsdom plus any visual fidelity / runtime concerns jsdom can't catch.

## Task body to inject

```markdown
### Task final.codex-browser-verify [SYNTHETIC: codex-browser-verify] | Model: codex (external) | Mode: subagent | LOC: ~0 | Review: skip

Goal: dispatch codex with native browser to click through this session's user flows and report critiques (not just PASS/FAIL). Orchestrator fixes the critiques.

For each phase in this session that has browser-verifiable work, codex should:
- Start (or use already-running) dev server.
- Navigate to the relevant page/route.
- Perform the user flow (click, fill, navigate).
- Compare against design intent (if a mockup reference exists in design.md or the plan, codex compares).
- Capture screenshot.
- Return a STRUCTURED LIST of critiques: each entry is `{file_or_area, what's_wrong, suggested_fix}`. PASS = empty critique list.

Codex prompt (orchestrator composes from this session's plan + diff):
"You have native browser. Dev server URL: <url>. For each flow below, click through and report any critiques. Critique format: numbered list, each with location + what's wrong + suggested fix. End with `No critiques.` if everything is fine. Flows: <list extracted per phase>"

Plan steps:
- [ ] Step 1: dispatch codex with browser-verify prompt
- [ ] Step 2: parse codex's critique list
- [ ] Step 3: for each critique, dispatch implementer (sonnet) to fix; commit
- [ ] Step 4: re-dispatch codex to verify fixes (loop until `No critiques.` or 2 rounds max - then surface remaining to user)
- [ ] Step 5: append final pass/critique summary to checklist
```

`Review: skip` because codex IS the reviewer and the orchestrator's fix-loop IS the resolution.
