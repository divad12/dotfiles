# ask-intern: Cheap Model Delegation

Load this file only when maintaining or troubleshooting `ask-intern`. For ordinary delegation, use the rules already in `AGENTS.md` so the cost-saving path stays cheap.

Route token-heavy grunt work to `ask-intern` (DeepSeek v4 Flash via OpenRouter, ~$0.002/call) to preserve Claude/Codex limits for reasoning.

## When to Delegate

- Reading files >400 lines, or when you'd otherwise read 3+ files for context
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
| `--stats` | Print usage dashboard and exit |

## Debugging

- Success stats: `~/.config/ask-intern/stats.tsv`
- Outcome log: `~/.config/ask-intern/events.tsv`
- Claude Code read-guard log: `~/.config/ask-intern/read-guard/events.jsonl`
- `ask-intern --stats` includes recent failure counts by reason, such as `missing_file`, `missing_api_key`, `api_error`, or `empty_response`.
- The event log records source (`claude`, `codex`, or `unknown`), status, reason, model, cwd, file paths, target path, latency, and the exact `ask-intern` invocation for early debugging.
- Source is inferred from `ASK_INTERN_SOURCE`, agent-specific environment variables, working directory, and process ancestry; old rows are backfilled from `cwd` when obvious and otherwise remain `unknown`.
- The invocation field may include prompt text. Keep this while tuning adoption, then remove or redact it once common failure modes are understood.
- Missing temp/log files are treated as stale optional context and skipped with a warning; missing project/source files still fail so the agent corrects guessed paths.
- Adoption audit: `ask-intern-audit` scans the event log plus Claude/Codex JSONL logs and reports suspicious direct reads and likely missed delegations. Use `ask-intern-audit --since-days 1` for recent sessions, or `ask-intern-audit --log path/to/session.jsonl` to inspect a specific session.

## Claude Code Read Guard

`~/bin/ask-intern-guard` is installed as a `PreToolUse` hook for `Read|Bash` in `~/.claude/settings.json`. It blocks broad direct reads before Claude Code spends context:

- whole-file reads of any non-instruction file over 400 lines
- the 3rd distinct non-instruction context file in a session
- Bash commands that directly read 3+ files, such as `cat a b c`

The hook allows narrow `Read` chunks with `offset`/`limit`, ignores required instruction files (`AGENTS.md`, `CLAUDE.md`, `PROGRESS.md`, `SKILL.md`, `docs/ai/`), and resets the session counter when Claude runs `ask-intern`. Set `ASK_INTERN_GUARD_DISABLED=1` to bypass it, or `ASK_INTERN_GUARD_MODE=warn` to allow reads with an advisory while tuning.

Direct-read control docs are exempt because summarizing them can lose execution order or exact instructions:

- Standard instruction docs: `AGENTS.md`, `CLAUDE.md`, `PROGRESS.md`, `SKILL.md`, `docs/ai/*`
- Markdown plans/checklists/queues under `docs/specs/**`
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

## Alternative Models

| Model | Cost (in/out per M) | Notes |
|---|---|---|
| `deepseek/deepseek-v4-flash` | $0.14 / $0.28 | Default. Fast, doesn't overthink |
| `deepseek/deepseek-v4-pro` | $0.44 / $0.87 | Better quality, still very cheap |
| `google/gemini-2.5-flash` | varies | Good at summarization |
| `deepseek/deepseek-chat-v3.1` | $0.15 / $0.75 | Older but solid |
