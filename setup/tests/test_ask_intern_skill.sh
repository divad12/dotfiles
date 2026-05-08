#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL="$ROOT/.agents/skills/ask-intern/SKILL.md"
AGENTS="$ROOT/.claude/AGENTS.md"
SETTINGS="$ROOT/.claude/settings.json"

test -f "$SKILL" || { echo "missing ask-intern skill" >&2; exit 1; }

grep -q '^name: ask-intern$' "$SKILL" || { echo "ask-intern skill name missing" >&2; exit 1; }
grep -q '^description: "Use when ' "$SKILL" || { echo "ask-intern skill description must be trigger-only" >&2; exit 1; }
grep -q 'Token Delegation' "$SKILL" || { echo "ask-intern skill must point at canonical Token Delegation rule" >&2; exit 1; }
grep -q '~/.claude/AGENTS.md' "$SKILL" || { echo "ask-intern skill must point at global AGENTS source" >&2; exit 1; }

if grep -q 'You MUST use `ask-intern` before reading' "$SKILL"; then
  echo "ask-intern skill duplicated the canonical threshold; keep it in AGENTS.md only" >&2
  exit 1
fi

grep -q 'superpowers:subagent-driven-development' "$AGENTS" || {
  echo "global subagent rule must cover direct subagent-driven-development use" >&2
  exit 1
}
grep -q 'Use the `ask-intern` skill if helpful' "$AGENTS" || {
  echo "session-start ask-intern reminder missing from AGENTS" >&2
  exit 1
}
grep -q 'Do NOT spend Codex/Claude work on' "$AGENTS" || {
  echo "Token Delegation needs deny-list framing for primary-model work" >&2
  exit 1
}
grep -q 'Never route to `ask-intern`' "$AGENTS" || {
  echo "Token Delegation needs explicit never-route guardrails" >&2
  exit 1
}
grep -q 'Max 2 sequential `ask-intern` calls' "$AGENTS" || {
  echo "Token Delegation needs chaining guardrail" >&2
  exit 1
}
grep -q 'ask-intern-shaped' "$SETTINGS" || {
  echo "Claude SessionStart ask-intern reminder missing" >&2
  exit 1
}

python3 -m json.tool "$SETTINGS" >/dev/null

echo "ok"
