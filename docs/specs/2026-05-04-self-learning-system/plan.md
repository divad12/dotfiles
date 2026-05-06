# Self-Learning Project System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the v0 self-learning loop: repo-local learning stores, idempotent capture, interactive dashboard decisions, low-risk decision execution, and review/merge capture checkpoints.

**Architecture:** Add a small Python stdlib CLI (`bin/learn`) as the shared capture/dashboard/executor primitive, then wire skills to call or follow that primitive. Markdown files under `docs/learnings/` remain canonical; generated dashboard HTML and decision JSONL are review/input surfaces. Dotfiles owns the global tooling and skills, while Journology exercises the project-local store.

**Tech Stack:** Python 3 stdlib, pytest, POSIX shell structural checks, Markdown files, skill `SKILL.md` contracts, existing git/merge guidance.

---

## File Structure

- Create `bin/learn`: executable Python CLI with `init`, `capture`, `dashboard`, `execute`, and `check-merge` subcommands.
- Create `setup/tests/test_learn_cli.py`: pytest coverage for store initialization, idempotent capture, dashboard generation, decision execution, and merge check summaries.
- Create `.agents/skills/learn/SKILL.md`: explicit `/learn` workflow for capture, dashboard, and executor actions.
- Create `.agents/skills/learn/tests/structural-check.sh`: protects the `/learn` skill's load-bearing sections.
- Delete the older capture skill surface after moving its trigger phrases and abstraction ladder into `.agents/skills/learn/SKILL.md` and `docs/ai/learning-system.md`.
- Modify `.agents/skills/task-observer/SKILL.md`: route project-specific observations into `docs/learnings/` and keep agent-system observations in dotfiles.
- Modify `.agents/skills/deep-review/SKILL.md`: add durable-learning closeout after review/fix synthesis.
- Modify `.agents/skills/qa-test/SKILL.md`: add FAIL/CONCERN learning closeout with plain-English ramification.
- Modify `.agents/skills/bugfix-tdd/SKILL.md`: replace shakedown-specific learning routing with canonical `docs/learnings/` capture.
- Modify `.agents/skills/merge/SKILL.md`: add before-landing learning check after squash audit.
- Modify `docs/ai/git.md`: make before-landing learning check part of the git contract.
- Create or initialize `/Users/david/Dropbox (Personal)/code/dotfiles/docs/learnings/` using `bin/learn init`.
- Create or initialize `/Users/david/Dropbox (Personal)/code/journology/docs/learnings/` using `bin/learn init`.

## Task 1: CLI Test Skeleton

**Files:**
- Create: `setup/tests/test_learn_cli.py`
- Modify: none
- Test: `setup/tests/test_learn_cli.py`

- [ ] **Step 1: Write failing tests for learning-store initialization and capture**

Create `setup/tests/test_learn_cli.py` with this content:

```python
import json
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
LEARN = ROOT / "bin" / "learn"


def run_learn(repo: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(LEARN), "--repo", str(repo), *args],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )


def test_init_creates_learning_store(tmp_path: Path) -> None:
    result = run_learn(tmp_path, "init")

    assert result.returncode == 0, result.stderr
    learning_dir = tmp_path / "docs" / "learnings"
    assert (learning_dir / "README.md").is_file()
    assert (learning_dir / "inbox.md").is_file()
    assert (learning_dir / "candidates.md").is_file()
    assert (learning_dir / "dashboard.md").is_file()
    assert (learning_dir / "calibration.md").is_file()
    assert (learning_dir / "auto-actions.md").is_file()
    assert (learning_dir / "decisions.jsonl").is_file()
    assert (learning_dir / "archive").is_dir()


def test_capture_writes_plain_english_entry(tmp_path: Path) -> None:
    run_learn(tmp_path, "init")

    result = run_learn(
        tmp_path,
        "capture",
        "--source",
        "QA",
        "--summary",
        "Preview guest picker is painful on large events",
        "--evidence",
        "On a 500-guest event, the dropdown requires long manual scrolling.",
        "--ramification",
        "Users waste time finding a guest and may think preview is broken.",
        "--recommended-fix",
        "Use the shared searchable picker for large guest collections.",
        "--candidate-artifact",
        "helper",
        "--technical-ref",
        "PreviewSimulator",
        "--confidence",
        "high",
    )

    assert result.returncode == 0, result.stderr
    inbox = (tmp_path / "docs" / "learnings" / "inbox.md").read_text()
    assert "- Sources: QA" in inbox
    assert "- User-facing summary: Preview guest picker is painful on large events" in inbox
    assert "- Ramification: Users waste time finding a guest and may think preview is broken." in inbox
    assert "- Recommended fix: Use the shared searchable picker for large guest collections." in inbox
    assert "- Candidate artifact: helper" in inbox
    assert "- Status: inbox" in inbox
```

- [ ] **Step 2: Run tests and verify they fail because `bin/learn` does not exist**

Run:

```bash
python3 -m pytest setup/tests/test_learn_cli.py -q
```

Expected: failure with an error showing Python cannot open `bin/learn`.

- [ ] **Step 3: Commit the failing tests**

Run:

```bash
git add setup/tests/test_learn_cli.py
git commit -m "test: cover learning CLI initialization"
```

## Task 2: Implement `bin/learn` Init And Capture

**Files:**
- Create: `bin/learn`
- Modify: none
- Test: `setup/tests/test_learn_cli.py`

- [ ] **Step 1: Create executable CLI with init and capture**

Create `bin/learn` with this content:

```python
#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import html
import json
from dataclasses import dataclass, field
from pathlib import Path


STORE_FILES = {
    "README.md": "# Project Learnings\n\nCold evidence and promotion state for durable project learnings.\n",
    "inbox.md": "# Learning Inbox\n\n",
    "candidates.md": "# Learning Candidates\n\n",
    "dashboard.md": "# Learning Dashboard\n\n",
    "calibration.md": "# Learning Calibration\n\n",
    "auto-actions.md": "# Learning Auto-Actions\n\n",
    "decisions.jsonl": "",
}

VALID_CONFIDENCE = {"low", "medium", "high"}


@dataclass
class LearningEntry:
    sources: list[str]
    summary: str
    evidence: str
    ramification: str
    recommended_fix: str
    candidate_artifact: str
    technical_refs: list[str] = field(default_factory=list)
    confidence: str = "medium"
    scope: str = "project"
    status: str = "inbox"
    source_events: list[str] = field(default_factory=list)
    suspected_pattern: str = ""

    @property
    def fingerprint(self) -> str:
        base = "|".join(
            [
                normalize(self.summary),
                normalize(self.suspected_pattern),
                normalize(" ".join(sorted(self.technical_refs))),
            ]
        )
        return hashlib.sha1(base.encode("utf-8")).hexdigest()[:12]


def normalize(value: str) -> str:
    return " ".join(value.lower().strip().split())


def store_dir(repo: Path) -> Path:
    return repo / "docs" / "learnings"


def init_store(repo: Path) -> Path:
    root = store_dir(repo)
    root.mkdir(parents=True, exist_ok=True)
    (root / "archive").mkdir(exist_ok=True)
    for name, content in STORE_FILES.items():
        path = root / name
        if not path.exists():
            path.write_text(content)
    return root


def parse_fingerprints(markdown: str) -> set[str]:
    fingerprints: set[str] = set()
    for line in markdown.splitlines():
        if line.startswith("- Fingerprint: "):
            fingerprints.add(line.split(": ", 1)[1].strip())
    return fingerprints


def append_entry(repo: Path, entry: LearningEntry) -> str:
    root = init_store(repo)
    inbox = root / "inbox.md"
    current = inbox.read_text()
    fingerprints = parse_fingerprints(current)
    if entry.fingerprint in fingerprints:
        append_audit(root, f"dedupe: {entry.fingerprint} already captured")
        return entry.fingerprint

    inbox.write_text(current + format_entry(entry) + "\n")
    return entry.fingerprint


def append_audit(root: Path, message: str) -> None:
    auto_actions = root / "auto-actions.md"
    auto_actions.write_text(auto_actions.read_text() + f"- {message}\n")


def format_entry(entry: LearningEntry) -> str:
    refs = ", ".join(entry.technical_refs) if entry.technical_refs else "None"
    events = ", ".join(entry.source_events) if entry.source_events else "None"
    pattern = entry.suspected_pattern if entry.suspected_pattern else "Unknown"
    return "\n".join(
        [
            f"### {entry.fingerprint}-{slugify(entry.summary)}",
            f"- Fingerprint: {entry.fingerprint}",
            f"- Sources: {', '.join(entry.sources)}",
            f"- Source events: {events}",
            f"- Scope: {entry.scope}",
            f"- User-facing summary: {entry.summary}",
            f"- Evidence: {entry.evidence}",
            f"- Technical refs: {refs}",
            f"- Ramification: {entry.ramification}",
            f"- Suspected pattern: {pattern}",
            f"- Recommended fix: {entry.recommended_fix}",
            f"- Candidate artifact: {entry.candidate_artifact}",
            f"- Confidence: {entry.confidence}",
            f"- Status: {entry.status}",
        ]
    )


def slugify(value: str) -> str:
    chars = [c.lower() if c.isalnum() else "-" for c in value]
    return "-".join("".join(chars).split("-"))[:64]


def generate_dashboard(repo: Path) -> None:
    root = init_store(repo)
    inbox = root / "inbox.md"
    body = inbox.read_text()
    (root / "dashboard.md").write_text("# Learning Dashboard\n\n## Needs Review\n\n" + body)
    (root / "dashboard.html").write_text(
        "<!doctype html><meta charset='utf-8'><title>Learning Dashboard</title>"
        "<h1>Learning Dashboard</h1><p>Interactive decisions are recorded through the CLI executor in v0.</p>"
        f"<pre>{html.escape(body)}</pre>"
    )


def execute_decisions(repo: Path) -> None:
    root = init_store(repo)
    decisions = root / "decisions.jsonl"
    auto_actions = root / "auto-actions.md"
    for line in decisions.read_text().splitlines():
        if not line.strip():
            continue
        event = json.loads(line)
        auto_actions.write_text(
            auto_actions.read_text()
            + f"- decision: {event.get('action')} {event.get('fingerprint')} {event.get('note', '')}\n"
        )
    decisions.write_text("")


def check_merge(repo: Path) -> int:
    root = init_store(repo)
    text = (root / "inbox.md").read_text() + "\n" + (root / "candidates.md").read_text()
    high = [line for line in text.splitlines() if line == "- Confidence: high"]
    if high:
        print(f"Learning check: {len(high)} high-confidence item(s) need review before landing.")
        return 1
    print("Learning check: no high-confidence open items found.")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="learn")
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("init")

    capture = sub.add_parser("capture")
    capture.add_argument("--source", required=True)
    capture.add_argument("--source-event", action="append", default=[])
    capture.add_argument("--summary", required=True)
    capture.add_argument("--evidence", required=True)
    capture.add_argument("--ramification", required=True)
    capture.add_argument("--recommended-fix", required=True)
    capture.add_argument("--candidate-artifact", required=True)
    capture.add_argument("--technical-ref", action="append", default=[])
    capture.add_argument("--confidence", choices=sorted(VALID_CONFIDENCE), default="medium")
    capture.add_argument("--scope", default="project")
    capture.add_argument("--suspected-pattern", default="")

    sub.add_parser("dashboard")
    sub.add_parser("execute")
    sub.add_parser("check-merge")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    repo = args.repo.resolve()
    if args.command == "init":
        init_store(repo)
        print(f"Initialized {store_dir(repo)}")
        return 0
    if args.command == "capture":
        fingerprint = append_entry(
            repo,
            LearningEntry(
                sources=[args.source],
                source_events=args.source_event,
                summary=args.summary,
                evidence=args.evidence,
                ramification=args.ramification,
                recommended_fix=args.recommended_fix,
                candidate_artifact=args.candidate_artifact,
                technical_refs=args.technical_ref,
                confidence=args.confidence,
                scope=args.scope,
                suspected_pattern=args.suspected_pattern,
            ),
        )
        print(f"Captured {fingerprint}")
        return 0
    if args.command == "dashboard":
        generate_dashboard(repo)
        print(f"Updated {store_dir(repo) / 'dashboard.md'}")
        return 0
    if args.command == "execute":
        execute_decisions(repo)
        print("Executed dashboard decisions")
        return 0
    if args.command == "check-merge":
        return check_merge(repo)
    raise AssertionError(args.command)


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 2: Make the CLI executable**

Run:

```bash
chmod +x bin/learn
```

- [ ] **Step 3: Run the CLI tests**

Run:

```bash
python3 -m pytest setup/tests/test_learn_cli.py -q
```

Expected: `2 passed`.

- [ ] **Step 4: Commit init and capture implementation**

Run:

```bash
git add bin/learn setup/tests/test_learn_cli.py
git commit -m "feat: add learning capture CLI"
```

## Task 3: Dedupe, Dashboard, Execute, And Merge Check Tests

**Files:**
- Modify: `setup/tests/test_learn_cli.py`
- Test: `setup/tests/test_learn_cli.py`

- [ ] **Step 1: Add tests for duplicate capture, dashboard, decision execution, and merge check**

Append these tests to `setup/tests/test_learn_cli.py`:

```python

def capture_scale_picker(repo: Path, source: str) -> subprocess.CompletedProcess[str]:
    return run_learn(
        repo,
        "capture",
        "--source",
        source,
        "--summary",
        "Preview guest picker is painful on large events",
        "--evidence",
        f"{source} saw long manual scrolling on a 500-guest event.",
        "--ramification",
        "Users waste time finding a guest and may think preview is broken.",
        "--recommended-fix",
        "Use the shared searchable picker for large guest collections.",
        "--candidate-artifact",
        "helper",
        "--technical-ref",
        "PreviewSimulator",
        "--confidence",
        "high",
    )


def test_capture_dedupes_repeated_sources(tmp_path: Path) -> None:
    run_learn(tmp_path, "init")

    first = capture_scale_picker(tmp_path, "QA")
    second = capture_scale_picker(tmp_path, "before-merge")

    assert first.returncode == 0, first.stderr
    assert second.returncode == 0, second.stderr
    inbox = (tmp_path / "docs" / "learnings" / "inbox.md").read_text()
    assert inbox.count("Preview guest picker is painful on large events") == 1
    auto_actions = (tmp_path / "docs" / "learnings" / "auto-actions.md").read_text()
    assert "dedupe:" in auto_actions


def test_dashboard_generates_review_surfaces(tmp_path: Path) -> None:
    run_learn(tmp_path, "init")
    capture_scale_picker(tmp_path, "QA")

    result = run_learn(tmp_path, "dashboard")

    assert result.returncode == 0, result.stderr
    dashboard = (tmp_path / "docs" / "learnings" / "dashboard.md").read_text()
    html = (tmp_path / "docs" / "learnings" / "dashboard.html").read_text()
    assert "Learning Dashboard" in dashboard
    assert "Preview guest picker is painful" in dashboard
    assert "<h1>Learning Dashboard</h1>" in html
    assert "Users waste time finding a guest" in html


def test_execute_records_dashboard_decisions(tmp_path: Path) -> None:
    run_learn(tmp_path, "init")
    decisions = tmp_path / "docs" / "learnings" / "decisions.jsonl"
    decisions.write_text(
        json.dumps(
            {
                "fingerprint": "abc123",
                "action": "archive",
                "note": "Duplicate of searchable picker candidate",
            }
        )
        + "\n"
    )

    result = run_learn(tmp_path, "execute")

    assert result.returncode == 0, result.stderr
    assert decisions.read_text() == ""
    auto_actions = (tmp_path / "docs" / "learnings" / "auto-actions.md").read_text()
    assert "decision: archive abc123 Duplicate of searchable picker candidate" in auto_actions


def test_check_merge_flags_high_confidence_items(tmp_path: Path) -> None:
    run_learn(tmp_path, "init")
    capture_scale_picker(tmp_path, "QA")

    result = run_learn(tmp_path, "check-merge")

    assert result.returncode == 1
    assert "high-confidence item" in result.stdout
```

- [ ] **Step 2: Run the expanded tests**

Run:

```bash
python3 -m pytest setup/tests/test_learn_cli.py -q
```

Expected: all existing tests pass except `test_capture_dedupes_repeated_sources` if Task 2 kept the simple dedupe audit without merging sources.

- [ ] **Step 3: Update `bin/learn` dedupe behavior if the duplicate-source test fails**

In `append_entry`, replace the duplicate branch with logic that rewrites the matching entry's `Sources` line and appends evidence when the new source is not already present. Use this exact replacement for the duplicate branch:

```python
    if entry.fingerprint in fingerprints:
        updated = merge_existing_entry(current, entry)
        inbox.write_text(updated)
        append_audit(root, f"dedupe: {entry.fingerprint} merged source {entry.sources[0]}")
        return entry.fingerprint
```

Add this helper below `parse_fingerprints`:

```python
def merge_existing_entry(markdown: str, entry: LearningEntry) -> str:
    lines = markdown.splitlines()
    output: list[str] = []
    inside = False
    source_added = False
    evidence_added = False
    for line in lines:
        if line == f"- Fingerprint: {entry.fingerprint}":
            inside = True
        elif inside and line.startswith("### "):
            if not evidence_added:
                output.append(f"- Additional evidence: {entry.evidence}")
            inside = False

        if inside and line.startswith("- Sources: "):
            existing = [part.strip() for part in line.split(": ", 1)[1].split(",")]
            for source in entry.sources:
                if source not in existing:
                    existing.append(source)
            output.append(f"- Sources: {', '.join(existing)}")
            source_added = True
            continue

        output.append(line)

    if inside and not evidence_added:
        output.append(f"- Additional evidence: {entry.evidence}")
    if inside and not source_added:
        output.append(f"- Sources: {', '.join(entry.sources)}")
    return "\n".join(output) + "\n"
```

- [ ] **Step 4: Re-run tests**

Run:

```bash
python3 -m pytest setup/tests/test_learn_cli.py -q
```

Expected: `6 passed`.

- [ ] **Step 5: Commit dashboard and dedupe behavior**

Run:

```bash
git add bin/learn setup/tests/test_learn_cli.py
git commit -m "feat: add learning dashboard primitives"
```

## Task 4: `/learn` Skill And Old Capture Surface Removal

**Files:**
- Create: `.agents/skills/learn/SKILL.md`
- Create: `.agents/skills/learn/tests/structural-check.sh`
- Delete: the older standalone capture skill after migrating its useful content into `/learn`
- Test: `.agents/skills/learn/tests/structural-check.sh`

- [ ] **Step 1: Create the `/learn` skill**

Create `.agents/skills/learn/SKILL.md`:

````markdown
---
name: learn
description: "Use when the user says '/learn', 'learn this', 'capture this', 'open the learning dashboard', 'what did we learn', or when a review/QA/bugfix/merge checkpoint needs to capture or act on durable project learnings."
user-invocable: true
argument-hint: "[capture|dashboard|execute|check-merge] [plain-English learning]"
---

# Learn

Capture raw evidence broadly, promote sparingly, and enforce durable learnings through the closest prevention artifact.

## Store

Use the current repo's `docs/learnings/` store. If it does not exist, run:

```bash
bin/learn --repo "$PWD" init
```

## Capture

When capturing a learning, write plain English first. Include what the user sees, loses, feels, or risks.

Use:

```bash
bin/learn --repo "$PWD" capture \
  --source "<QA|review|bugfix|agent-discovery|user-feedback|failed-command|before-merge|task-observer|learn>" \
  --summary "<plain-English one-liner>" \
  --evidence "<plain-English evidence>" \
  --ramification "<user-facing impact>" \
  --recommended-fix "<one-line prevention action>" \
  --candidate-artifact "<test|lint|helper|skill|docs|nested-AGENTS|automation|archive>" \
  --confidence "<low|medium|high>" \
  --technical-ref "<file/function/test/log/screenshot>"
```

The CLI dedupes overlapping captures. If task-observer, review closeout, and before-merge all find the same issue, they should update one entry instead of creating parallel dashboard rows.

## Dashboard

When the user asks for the dashboard, run:

```bash
bin/learn --repo "$PWD" dashboard
```

Open or show `docs/learnings/dashboard.html` for review. The dashboard is interactive by default when a local server is available; static markdown/HTML is a read-only fallback for diffs and automation artifacts.

## Execute

When the user records dashboard decisions or asks to execute them, run:

```bash
bin/learn --repo "$PWD" execute
```

Learning-file updates and low-risk docs can be applied directly. Code, shared skill, enforcement, and architecture changes must become TDD/review tasks.

## Before Merge

At merge or landing checkpoints, run:

```bash
bin/learn --repo "$PWD" check-merge
```

Surface high-confidence open items in plain English. If a prevention artifact is missing, ask whether to create it, defer it, or acknowledge landing with a follow-up.
````

- [ ] **Step 2: Create structural check**

Create `.agents/skills/learn/tests/structural-check.sh`:

```bash
#!/bin/bash
set -e

SKILL=.agents/skills/learn/SKILL.md

test -f "$SKILL" || { echo "FAIL: learn skill missing"; exit 1; }
grep -q "^name: learn$" "$SKILL" || { echo "FAIL: learn name"; exit 1; }
grep -q "^user-invocable: true$" "$SKILL" || { echo "FAIL: learn user-invocable"; exit 1; }
grep -q "^## Store$" "$SKILL" || { echo "FAIL: Store section"; exit 1; }
grep -q "^## Capture$" "$SKILL" || { echo "FAIL: Capture section"; exit 1; }
grep -q "^## Dashboard$" "$SKILL" || { echo "FAIL: Dashboard section"; exit 1; }
grep -q "^## Execute$" "$SKILL" || { echo "FAIL: Execute section"; exit 1; }
grep -q "^## Before Merge$" "$SKILL" || { echo "FAIL: Before Merge section"; exit 1; }
grep -q "plain-English" "$SKILL" || { echo "FAIL: plain-English contract"; exit 1; }
grep -q "dedupes overlapping captures" "$SKILL" || { echo "FAIL: dedupe contract"; exit 1; }
grep -q "TDD/review tasks" "$SKILL" || { echo "FAIL: TDD/review executor contract"; exit 1; }

echo "OK: learn structural check passed"
```

Run:

```bash
chmod +x .agents/skills/learn/tests/structural-check.sh
```

- [ ] **Step 3: Remove the older standalone capture surface**

Move the useful abstraction-ladder guidance into `.agents/skills/learn/SKILL.md` and `docs/ai/learning-system.md`, then remove the older standalone capture skill. The `/learn` description must include the old trigger phrases directly: "document this", "capture this", "remember this for next time", and "update the docs".

The canonical abstraction-ladder text should include this sentence:

```markdown
Before writing to `docs/learnings/`, climb one rung higher than the first principle that comes to mind. If the next rung is still actionable, capture that higher principle.
```

- [ ] **Step 4: Run structural check and CLI tests**

Run:

```bash
.agents/skills/learn/tests/structural-check.sh
python3 -m pytest setup/tests/test_learn_cli.py -q
```

Expected: structural check prints `OK: learn structural check passed`; pytest prints `6 passed`.

- [ ] **Step 5: Commit learn skill**

Run:

```bash
git add .agents/skills/learn docs/ai/learning-system.md
git commit -m "feat: add learn skill workflow"
```

## Task 5: Capture Checkpoints In Existing Skills

**Files:**
- Modify: `.agents/skills/task-observer/SKILL.md`
- Modify: `.agents/skills/deep-review/SKILL.md`
- Modify: `.agents/skills/qa-test/SKILL.md`
- Modify: `.agents/skills/bugfix-tdd/SKILL.md`
- Test: `.agents/skills/learn/tests/structural-check.sh`, `setup/tests/test_learn_cli.py`

- [ ] **Step 1: Update task-observer routing**

In `.agents/skills/task-observer/SKILL.md`, add this subsection under "Where To Log":

```markdown
## Project Learning Routing

If the observation is about the current project's codebase, QA/review pattern, test command, cache behavior, architecture guardrail, or repo-specific workflow, capture it in the project's `docs/learnings/` store through `/learn` instead of only writing to `~/.agents/observations/<project-slug>/log.md`.

Keep agent-system observations in dotfiles when they concern skills, hooks, global docs, task-observer itself, or cross-project agent behavior.

Before writing a project learning, dedupe against active inbox, candidates, promoted entries, and recent archives. Multiple sources for the same issue should update one learning entry's `Sources` and evidence trail.
```

- [ ] **Step 2: Update deep-review closeout**

In `.agents/skills/deep-review/SKILL.md`, add this closeout rule near the final summary instructions:

```markdown
## Learning Closeout

Before final response, identify review findings or auto-fixes that reveal a reusable bug class, missing guardrail, repeated workflow issue, or architecture gap. For each durable pattern, invoke `/learn` capture with:

- source: `review`
- plain-English evidence and ramification
- technical refs for files/tests/functions
- recommended fix naming the prevention artifact
- confidence based on evidence strength

Do not create duplicate learning entries for issues already captured by bugfix, QA, task-observer, or before-merge checks; update the existing entry's `Sources` and evidence trail.
```

- [ ] **Step 3: Update QA closeout**

In `.agents/skills/qa-test/SKILL.md`, add this under "Act on the results":

```markdown
4. **Capture durable learnings.** For each FAIL or CONCERN that reveals a reusable bug class, missing guardrail, scale issue, or workflow problem, invoke `/learn` capture. Lead with the user-facing experience, not test jargon. If a FAIL is fixed immediately, still capture the pattern so the prevention artifact can be tracked.
```

- [ ] **Step 4: Update bugfix TDD learning routing**

In `.agents/skills/bugfix-tdd/SKILL.md`, replace references that route durable lessons directly to `BUG_PATTERNS.md`, `LESSONS_LEARNED.md`, or `BUGS_FIXED.md` with:

```markdown
After the fix passes verification, invoke `/learn` capture for any reusable bug class, missing guardrail, or project-specific workflow lesson. The canonical record is `docs/learnings/`; legacy files such as `BUG_PATTERNS.md` and `LESSONS_LEARNED.md` may be candidate artifacts when a project still uses them.
```

- [ ] **Step 5: Run checks**

Run:

```bash
.agents/skills/learn/tests/structural-check.sh
python3 -m pytest setup/tests/test_learn_cli.py -q
```

Expected: structural check prints `OK: learn structural check passed`; pytest prints `6 passed`.

- [ ] **Step 6: Commit skill checkpoint updates**

Run:

```bash
git add .agents/skills/task-observer/SKILL.md .agents/skills/deep-review/SKILL.md .agents/skills/qa-test/SKILL.md .agents/skills/bugfix-tdd/SKILL.md
git commit -m "feat: capture learnings from review and QA"
```

## Task 6: Before-Landing Learning Check

**Files:**
- Modify: `.agents/skills/merge/SKILL.md`
- Modify: `docs/ai/git.md`
- Test: `setup/tests/test_learn_cli.py`

- [ ] **Step 1: Update git contract**

In `docs/ai/git.md`, add this section after "The Squash Audit Checkpoint":

````markdown
## Before-Landing Learning Check

After the squash audit is signed off and before rebasing or fast-forwarding the target, run:

```bash
bin/learn --repo "$PWD" check-merge
```

If high-confidence open learnings are reported, surface them in plain English with the user-facing ramification. Ask whether to create the prevention artifact, defer with an explicit follow-up, or acknowledge landing without the artifact.

This checkpoint prevents a branch from landing with only chat memory of a bug class or review finding. It does not replace TDD or code review; it decides whether a prevention artifact is needed before landing.
````

- [ ] **Step 2: Update merge skill workflow**

In `.agents/skills/merge/SKILL.md`, add a step after squash-audit signoff and before rebase:

```markdown
Run the before-landing learning check from `docs/ai/git.md`. If it reports high-confidence open learnings, stop and ask the user which action to take before landing: create prevention artifact, defer with follow-up, or acknowledge landing without the artifact.
```

- [ ] **Step 3: Run CLI and structural tests**

Run:

```bash
python3 -m pytest setup/tests/test_learn_cli.py -q
.agents/skills/learn/tests/structural-check.sh
```

Expected: pytest prints `6 passed`; structural check prints `OK: learn structural check passed`.

- [ ] **Step 4: Commit merge checkpoint**

Run:

```bash
git add .agents/skills/merge/SKILL.md docs/ai/git.md
git commit -m "feat: add learning check before landing"
```

## Task 7: Bootstrap Dotfiles And Journology Stores

**Files:**
- Create: `docs/learnings/README.md`
- Create: `docs/learnings/inbox.md`
- Create: `docs/learnings/candidates.md`
- Create: `docs/learnings/dashboard.md`
- Create: `docs/learnings/dashboard.html`
- Create: `docs/learnings/calibration.md`
- Create: `docs/learnings/auto-actions.md`
- Create: `docs/learnings/decisions.jsonl`
- Create: `docs/learnings/archive/`
- Create in Journology: `/Users/david/Dropbox (Personal)/code/journology/docs/learnings/...`
- Test: `setup/tests/test_learn_cli.py`

- [ ] **Step 1: Initialize dotfiles learning store**

Run from `/Users/david/Dropbox (Personal)/code/dotfiles`:

```bash
bin/learn --repo "$PWD" init
bin/learn --repo "$PWD" dashboard
```

Expected: `docs/learnings/` exists and `docs/learnings/dashboard.html` is generated.

- [ ] **Step 2: Initialize Journology learning store**

Run:

```bash
bin/learn --repo "/Users/david/Dropbox (Personal)/code/journology" init
bin/learn --repo "/Users/david/Dropbox (Personal)/code/journology" dashboard
```

Expected: `/Users/david/Dropbox (Personal)/code/journology/docs/learnings/` exists and dashboard files are generated.

- [ ] **Step 3: Capture seed learning in Journology**

Run:

```bash
bin/learn --repo "/Users/david/Dropbox (Personal)/code/journology" capture \
  --source "learn" \
  --summary "Large QA findings need cold evidence and curated promotion" \
  --evidence "The old long PROGRESS.md captured useful problem-solution lines, but it also became too large to load every session." \
  --ramification "Agents can forget useful fixes or overload future sessions with stale context." \
  --recommended-fix "Keep raw QA/review evidence in docs/learnings and promote only durable prevention artifacts." \
  --candidate-artifact "docs" \
  --technical-ref "docs/specs/2026-05-04-self-learning-system/design.md" \
  --confidence "high"
bin/learn --repo "/Users/david/Dropbox (Personal)/code/journology" dashboard
```

Expected: Journology `inbox.md` has one seed entry and `dashboard.md` shows it.

- [ ] **Step 4: Run final tests**

Run:

```bash
python3 -m pytest setup/tests/test_learn_cli.py -q
.agents/skills/learn/tests/structural-check.sh
```

Expected: pytest prints `6 passed`; structural check prints `OK: learn structural check passed`.

- [ ] **Step 5: Commit dotfiles bootstrap**

Run from dotfiles:

```bash
git add docs/learnings
git commit -m "chore: initialize dotfiles learning store"
```

- [ ] **Step 6: Commit Journology bootstrap**

Run from Journology:

```bash
cd "/Users/david/Dropbox (Personal)/code/journology"
git add docs/learnings
git commit -m "chore: initialize project learning store"
```

## Task 8: Final Verification And Review

**Files:**
- Read: `docs/specs/2026-05-04-self-learning-system/design.md`
- Read: `docs/specs/2026-05-04-self-learning-system/plan.md`
- Test: `setup/tests/test_learn_cli.py`, `.agents/skills/learn/tests/structural-check.sh`

- [ ] **Step 1: Run dotfiles verification**

Run from dotfiles:

```bash
python3 -m pytest setup/tests/test_learn_cli.py -q
.agents/skills/learn/tests/structural-check.sh
bin/learn --repo "$PWD" check-merge
```

Expected:

```text
6 passed
OK: learn structural check passed
Learning check: no high-confidence open items found.
```

If dotfiles has high-confidence open items because Task 7 captured seed data there, report the exact output and ask whether to resolve, archive, or defer before landing.

- [ ] **Step 2: Run Journology smoke check**

Run:

```bash
bin/learn --repo "/Users/david/Dropbox (Personal)/code/journology" dashboard
test -f "/Users/david/Dropbox (Personal)/code/journology/docs/learnings/dashboard.html"
```

Expected: command exits 0 and the Journology dashboard file exists.

- [ ] **Step 3: Self-review against design acceptance criteria**

Check each item in the design's "Version 0 Acceptance Criteria" and write a short terminal summary:

```text
Acceptance criteria:
- QA finding capture: covered by test_capture_writes_plain_english_entry
- Promotion/archive primitive: execute records decisions; archive status mutation deferred to executor task output
- Low-risk auto-promotion log: covered by auto-actions decision log
- Risky dashboard review: dashboard renders needs-review source data
- Dashboard decision execution: covered by test_execute_records_dashboard_decisions
- Duplicate captures: covered by test_capture_dedupes_repeated_sources
- Code-related decisions: skill docs require TDD/review tasks
- Always-loaded docs tiny: root AGENTS unchanged
```

- [ ] **Step 4: Request review**

Run:

```bash
git log --oneline --decorate -8
git status --short
```

Then ask for review of the implementation before merging or pushing.
