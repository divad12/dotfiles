# ask-intern: Cheap Model Delegation

Load this file only when maintaining or troubleshooting `ask-intern`. For ordinary delegation, use the rules already in `AGENTS.md` so the cost-saving path stays cheap.

Route token-heavy grunt work to `ask-intern` (DeepSeek v4 Flash via OpenRouter, ~$0.002/call) to preserve Claude/Codex limits for reasoning.

## When to Delegate

- Reading files >400 lines, or cumulative medium/large file sets for context
- Boilerplate: tests, config files, docstrings, repetitive patterns
- Summarizing diffs, logs, or large documentation
- Generating fixtures, sample data, format conversions

## When NOT to Delegate

- Tasks under ~2000 tokens total (delegation overhead isn't worth it)
- Architecture decisions, debugging, safety-critical code
- Anything requiring conversation context or careful reasoning
- When exact line numbers are needed for subsequent editing

## Usage

### Reading mode (returns summary to stdout)

```bash
# Summarize files without reading them yourself
ask-intern -f src/models.py -f src/api.py "how does the auth flow work?"

# Piped input
git diff HEAD~5 | ask-intern "summarize these changes"
cat long-spec.md | ask-intern "extract all requirements as a checklist"

# Simple questions
ask-intern "write a regex that matches ISO 8601 dates with optional timezone"
```

### Write-to-file mode (output goes directly to disk)

Use `--target` / `-t` for boilerplate generation. The output is written directly to the file — it never enters your context window, saving tokens twice.

```bash
# Generate tests
ask-intern -t tests/test_user.py -f src/user.py "write pytest tests for all public methods"

# Generate types from schema
ask-intern -t src/types.ts -f schema.prisma "generate TypeScript interfaces for each model"

# Config boilerplate
ask-intern -t docker-compose.yml "docker compose for postgres + redis + node app on port 3000"

# Docstrings
ask-intern -t src/api_documented.py -f src/api.py "add Google-style docstrings to all public functions"
```

After `--target`, review the output and edit only what needs fixing.

### Flags

| Flag | Purpose |
|---|---|
| `-f FILE` | Include file as context (repeatable) |
| `-t PATH` | Write output to file instead of stdout |
| `-m MODEL` | Override model (e.g. `deepseek/deepseek-v4-pro`) |
| `-s PROMPT` | Override system prompt |
| `-v` | Verbose: dump full request/response to stderr |
| `--allow-exact-source` | Bypass the exact-source guard for rare manual debugging |
| `--allow-broad-review` | Bypass the broad-review timeout guard for rare manual debugging |
| `--stats` | Print usage dashboard and exit |

## Debugging

- Success stats: `~/.config/ask-intern/stats.tsv`
- Outcome log: `~/.config/ask-intern/events.tsv`
- Attempt log: `~/.config/ask-intern/attempts.jsonl`
- Claude Code read-guard log: `~/.config/ask-intern/read-guard/events.jsonl`
- `ask-intern --stats` includes recent failure counts by reason, such as `missing_file`, `missing_api_key`, `api_error`, or `empty_response`.
- The event log records source (`claude`, `codex`, or `unknown`), status, reason, model, cwd, file paths, target path, latency, and the exact `ask-intern` invocation for early debugging.
- The attempt log records one `start` row before the API request and one `end` row after success or handled failure. If an agent kills a stale `ask-intern` process, the start row remains without an end row and `ask-intern-audit` reports it as an abandoned attempt.
- The read-guard log records every catch with reason, paths, inferred agent source (`claude`, `codex`, or `unknown`), source tool, original hook input (`Read` `file_path`/`offset`/`limit` or Bash `command`), and computed line/count estimates when available.
- Source is inferred from `ASK_INTERN_SOURCE`, agent-specific environment variables, working directory, and process ancestry; old rows are backfilled from `cwd` when obvious and otherwise remain `unknown`.
- The invocation field may include prompt text. Keep this while tuning adoption, then remove or redact it once common failure modes are understood.
- `ask-intern-audit` flags likely over-delegation patterns such as exact/verbatim-code prompts, single small-file calls, and docs/control-only calls. It filters docs/control/generated/temp/binary reads and also reports possible chunk-read bypasses when one session reads the same non-exempt file in repeated large chunks. Exact source text should come from direct small reads or narrow snippets, not from `ask-intern`.
- `ask-intern` hard-denies exact/verbatim source requests before any API call and logs `exact_source_request`; the matcher is negation-aware, so prompts like "do not quote exact code" are allowed. Use direct `rg`/`sed`/narrow `Read` snippets for exact text; set `--allow-exact-source` or `ASK_INTERN_ALLOW_EXACT_SOURCE=1` only for deliberate manual debugging.
- `ask-intern` hard-denies broad review-shaped requests that are likely to time out before any API call and logs `high_risk_review`. This targets prompts like "review this uncommitted diff" or "deep-review this patch" when paired with a large piped diff or too many files. Split these into subsystem-sized reviews: one diff slice or about 3-5 related files per call. Use `--allow-broad-review` or `ASK_INTERN_ALLOW_BROAD_REVIEW=1` only for deliberate manual debugging.
- Successful read-mode calls print a short stderr reminder that exact code and line numbers should come from direct narrow snippets after the summary.
- API calls have a total wall-clock timeout (`INTERN_TIMEOUT_SECONDS`, default 240s) in addition to the socket inactivity timeout (`INTERN_SOCKET_TIMEOUT_SECONDS`, default 120s). Timeout failures are logged as `timeout`; narrow the prompt/file set or override the timeout only when the long run is intentional.
- Missing temp/log files are treated as stale optional context and skipped with a warning; missing project/source files still fail so the agent corrects guessed paths.
- Adoption audit: `ask-intern-audit` scans the event log, attempt log, read-guard catches, and Claude/Codex JSONL logs. It reports slow/hang-shaped calls, abandoned attempts, recent guard blocks, suspicious direct reads, and likely missed delegations. Use `ask-intern-audit --since-days 1` for recent sessions, or `ask-intern-audit --log path/to/session.jsonl` to inspect a specific session.

## Daily Adoption Audit Runbook

Run this when tuning `ask-intern` adoption or reviewing the last day of Claude/Codex behavior.

1. Capture the dashboard:

```bash
ask-intern --stats
ask-intern-audit --since-days 1 --guard-limit 20
```

For hang investigations, check:

```bash
ask-intern-audit --since-days 1 --slow-call-seconds 180
```

2. Review false positives:

- `exact_source_request` failures where the prompt said not to quote exact code.
- `high_risk_review` failures where the guard correctly asked the agent to split a broad review, or where the thresholds are too aggressive.
- `read-guard` blocks on docs/control files, small exact snippets, or generated/temp files that should be exempt.
- `possible over-delegations` where the work was a single small file, docs/control-only, or needed exact text rather than a summary.
- `slow/hang-shaped calls` where the prompt or file set should be narrowed, or where the timeout should remain capped.
- `abandoned attempts` where an agent probably killed or interrupted `ask-intern` before it produced a terminal outcome.

3. Review false negatives:

- `likely missed delegations` sessions with 3+ broad direct reads and no `ask-intern`.
- `possible chunk-read bypasses` where one file was read in repeated large chunks.
- Top direct-read paths that are real source files rather than docs, hooks, generated output, `.git`, or observation/control files.

4. Inspect the transcript only after the dashboard points to a concrete candidate:

```bash
ask-intern-audit --since-days 1 --log path/to/session.jsonl --guard-limit 20
```

Classify each candidate as:

- False positive: the guard/audit pushed delegation when direct reading was better.
- False negative: the agent read broad context that should have been delegated.
- Expected: the direct read was docs/control/exact-snippet work, or `ask-intern` was correctly used first.

5. Improve in this order:

- Add or update a regression test that captures the failure mode.
- Prefer hook/audit fixes over prose when the pattern is mechanically detectable.
- Update `AGENTS.md` or skill prompts only for judgment/routing problems that tooling cannot see.
- Re-run the focused tests and `ask-intern-audit --since-days 1` before committing.

Daily summary format:

```text
ask-intern daily audit
- calls: <total> (<claude>, <codex>)
- false positives fixed/proposed: <count> - <one-line examples>
- false negatives fixed/proposed: <count> - <one-line examples>
- slow/abandoned ask-intern calls: <count> - <one-line examples>
- noisy diagnostics still ignored: <count> - <why>
- next tooling/doc change: <concrete recommendation>
```

## Claude Code Read Guard

`~/bin/ask-intern-guard` is installed as a `PreToolUse` hook for `Read|Bash` in `~/.claude/settings.json`. It blocks broad direct reads before Claude Code spends context:

- whole-file reads of any non-instruction file over 400 lines
- cumulative broad reads over 800 lines across 3+ distinct non-instruction context files, counting only files/ranges of roughly 200+ lines
- Bash commands that directly read enough file content to cross that cumulative budget

The hook allows small files, narrow `Read` chunks with `offset`/`limit`, and shape probes such as `wc -l` or small `head`/`tail` reads. It ignores required instruction/project documentation files (`AGENTS.md`, `CLAUDE.md`, `PROGRESS.md`, `SKILL.md`, any path segment named `docs`) and resets the session counter when Claude runs `ask-intern`. Tune the cumulative budget with `ASK_INTERN_GUARD_MAX_CUMULATIVE_LINES` and the small-file floor with `ASK_INTERN_GUARD_MIN_CUMULATIVE_FILE_LINES`. Set `ASK_INTERN_GUARD_DISABLED=1` to bypass it, or `ASK_INTERN_GUARD_MODE=warn` to allow reads with an advisory while tuning.

Direct-read control docs are exempt because summarizing them can lose execution order or exact instructions:

- Standard instruction docs: `AGENTS.md`, `CLAUDE.md`, `PROGRESS.md`, `SKILL.md`
- Any file under a `docs/` directory, including specs, implementation plans, checklists, and reference docs
- Any file whose first 40 lines include `<!-- agent-control: direct-read -->`

For arbitrary existing files that should be read verbatim once, run:

```bash
ask-intern-guard --allow-next path/to/file.md "verbatim user request"
```

The allowance is one-shot and expires after one hour. Use it when the user explicitly asks for a direct read and the file is not already marked.

## Configuration

- API key: `~/.config/ask-intern/env` (`export OPENROUTER_API_KEY=...`)
- The CLI loads that env file itself before reading defaults, so Claude/Codex shells do not need to inherit the key.
- Default model: `deepseek/deepseek-v4-flash` ($0.14/M in, $0.28/M out)
- Override model: `INTERN_MODEL` env var or `-m` flag
- Max tokens: `INTERN_MAX_TOKENS` for read mode (default 8192), `INTERN_MAX_TOKENS_WRITE` for write mode (default 16384)
- Total timeout: `INTERN_TIMEOUT_SECONDS` (default 240). Set to `0` only for deliberate manual debugging.
- Socket inactivity timeout: `INTERN_SOCKET_TIMEOUT_SECONDS` (default 120).
- Broad-review file guard: `INTERN_HIGH_RISK_REVIEW_FILE_COUNT` (default 8). Set to `0` to disable the file-count branch.
- Broad-review stdin guard: `INTERN_HIGH_RISK_REVIEW_STDIN_CHARS` (default 50000). Set to `0` to disable the piped-input branch.

## Alternative Models

| Model | Cost (in/out per M) | Notes |
|---|---|---|
| `deepseek/deepseek-v4-flash` | $0.14 / $0.28 | Default. Fast, doesn't overthink |
| `deepseek/deepseek-v4-pro` | $0.44 / $0.87 | Better quality, still very cheap |
| `google/gemini-2.5-flash` | varies | Good at summarization |
| `deepseek/deepseek-chat-v3.1` | $0.15 / $0.75 | Older but solid |
