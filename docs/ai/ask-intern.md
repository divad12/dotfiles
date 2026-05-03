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
