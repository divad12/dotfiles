> **IMPORTANT: Before reading, check if you already read this file earlier in this session. If yes, skip the read and announce "Context already loaded: learning-report-voice.md (re-using from earlier)". If no, read it and announce "Context loaded: learning-report-voice.md".**

# Learning Report Voice

## Contract

- Write like a thoughtful teammate explaining what happened, not like an audit log.
- Start with what the reader would have seen, felt, lost, or risked.
- Use concrete examples when the technical rule would otherwise sound abstract.
- Keep file paths, tests, and technical labels as supporting details after the explanation.
- Do not say "receipt" or "prevention artifact" in user-facing reports. Say "details", "files changed", "tests run", "test", "helper", "docs update", "check", or "the thing that stops this happening again."

## Concrete Target

Use this as the tone target for learning captures, dashboard copy, and automation summaries.

> Bad: "Async status summaries now have a clearer rule: chips, banners, and callouts that depend on multiple async inputs should show a neutral loading/unknown state until all inputs that can change the conclusion have resolved. That prevents brief 'no groups' or missing-warning states that make architects distrust the header. Receipt:"
>
> Good: "Some of these little status labels were speaking too soon. They'd say 'no groups' or hide a warning while the page was still loading the rest of the data, which makes the header feel flaky even if it fixes itself a second later. I changed them so they basically say 'still checking...' until the actual data has loaded, then they give the real answer."

If a report sounds like the bad version, rewrite it before showing it to the user.
