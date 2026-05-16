# RTK - Rust Token Killer (Codex CLI)

**Usage**: Token-optimized CLI proxy for shell commands.

## Rule

Always prefix shell commands with `rtk`.

Examples:

```bash
rtk git status
rtk cargo test
rtk npm run build
rtk pytest -q
```

## Broad-Read Guard

The dotfiles RTK wrapper runs `ask-intern-guard` before the real RTK binary for obvious broad-read misses:

- `rtk read` on large files or several medium files
- broad `rtk sed` / `rtk cat` / `rtk head` / `rtk tail` reads
- raw `rtk proxy git diff` output

If it blocks, use `ask-intern` for the first-pass summary, then inspect exact snippets with bounded reads.

Use bounded RTK reads directly when exact snippets are needed:

```bash
rtk read --max-lines 120 src/file.ts
rtk git diff --stat
```

## Meta Commands

```bash
rtk gain            # Token savings analytics
rtk gain --history  # Recent command savings history
rtk proxy <cmd>     # Run raw command without filtering, still tracked and guarded
```

## Verification

```bash
rtk --version
rtk gain
which rtk
```
