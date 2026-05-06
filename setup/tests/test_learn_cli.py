import json
import subprocess
import sys
import time
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
LEARN = ROOT / "bin" / "learn"


def run_learn(repo: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(LEARN), "--repo", str(repo), *args],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )


def capture_scale_picker(repo: Path, source: str) -> subprocess.CompletedProcess[str]:
    return run_learn(
        repo,
        "capture",
        "--source",
        source,
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


def capture_learning(
    repo: Path,
    *,
    summary: str,
    artifact: str,
    confidence: str = "high",
    technical_ref: str = "docs/learnings/example.md",
) -> subprocess.CompletedProcess[str]:
    return run_learn(
        repo,
        "capture",
        "--source",
        "review",
        "--summary",
        summary,
        "--evidence",
        f"Observed during review: {summary}.",
        "--ramification",
        "Users lose a durable guardrail if this learning is forgotten.",
        "--recommended-fix",
        "Route the learning to the closest durable prevention artifact.",
        "--candidate-artifact",
        artifact,
        "--technical-ref",
        technical_ref,
        "--confidence",
        confidence,
    )


def capture_multiline_evidence(repo: Path) -> subprocess.CompletedProcess[str]:
    return run_learn(
        repo,
        "capture",
        "--source",
        "review",
        "--summary",
        "Multiline evidence can contain markdown headings",
        "--evidence",
        "First observed line.\n### This is evidence, not a learning entry\nSecond observed line.",
        "--ramification",
        "Users lose evidence if markdown headings split the learning entry.",
        "--recommended-fix",
        "Only split stored entries on real learning headings.",
        "--candidate-artifact",
        "docs",
        "--technical-ref",
        "docs/learnings/evidence.md",
        "--confidence",
        "high",
    )


def fingerprint_from(markdown: str) -> str:
    for line in markdown.splitlines():
        if line.startswith("- Fingerprint: "):
            return line.removeprefix("- Fingerprint: ")
    raise AssertionError("missing fingerprint")


def test_init_creates_learning_store(tmp_path: Path) -> None:
    result = run_learn(tmp_path, "init")

    assert result.returncode == 0, result.stderr
    store = tmp_path / "docs" / "learnings"
    for name in [
        "README.md",
        "inbox.md",
        "candidates.md",
        "dashboard.md",
        "calibration.md",
        "auto-actions.md",
        "decisions.jsonl",
    ]:
        assert (store / name).exists()
    assert (store / "archive").is_dir()
    readme = (store / "README.md").read_text()
    assert "Canonical operating contract" in readme
    assert "Do not duplicate workflow rules here" in readme
    assert "Normal front doors" not in readme


def test_learn_init_alias_creates_learning_store(tmp_path: Path) -> None:
    result = run_learn(tmp_path, "learn-init")

    assert result.returncode == 0, result.stderr
    assert (tmp_path / "docs" / "learnings" / "README.md").exists()


def test_bare_learn_command_opens_dashboard_surface(tmp_path: Path) -> None:
    assert capture_learning(tmp_path, summary="Dashboard should be one command", artifact="docs").returncode == 0

    result = run_learn(tmp_path)

    assert result.returncode == 0, result.stderr
    assert "Learning Dashboard" in (tmp_path / "docs" / "learnings" / "dashboard.md").read_text()
    assert "Dashboard should be one command" in (
        tmp_path / "docs" / "learnings" / "dashboard.html"
    ).read_text()


def test_capture_writes_plain_english_entry(tmp_path: Path) -> None:
    assert run_learn(tmp_path, "init").returncode == 0

    result = capture_scale_picker(tmp_path, "QA")

    assert result.returncode == 0, result.stderr
    inbox = (tmp_path / "docs" / "learnings" / "inbox.md").read_text()
    assert "- Sources: QA" in inbox
    assert "- Captured: " in inbox
    assert "- User-facing summary: Preview guest picker is painful on large events" in inbox
    assert "- Ramification: Users waste time finding a guest and may think preview is broken." in inbox
    assert "- Recommended fix: Use the shared searchable picker for large guest collections." in inbox
    assert "- Candidate artifact: helper" in inbox
    assert "- Status: inbox" in inbox


def test_capture_merges_exact_fingerprint_replays(tmp_path: Path) -> None:
    assert run_learn(tmp_path, "init").returncode == 0
    first = capture_scale_picker(tmp_path, "QA")
    assert first.returncode == 0
    assert first.stdout.startswith("captured ")

    result = capture_scale_picker(tmp_path, "before-merge")

    assert result.returncode == 0, result.stderr
    assert result.stdout.startswith("updated ")
    store = tmp_path / "docs" / "learnings"
    inbox = (store / "inbox.md").read_text()
    assert inbox.count("Preview guest picker is painful on large events") == 1
    assert "- Sources: QA, before-merge" in inbox
    assert "- Additional evidence: On a 500-guest event, the dropdown requires long manual scrolling." in inbox
    assert "exact-replay:" in (store / "auto-actions.md").read_text()


def test_capture_merges_exact_fingerprint_candidate_replays(tmp_path: Path) -> None:
    assert run_learn(tmp_path, "init").returncode == 0
    assert capture_scale_picker(tmp_path, "QA").returncode == 0
    store = tmp_path / "docs" / "learnings"
    candidate_entry = (store / "inbox.md").read_text().removeprefix("# Learning Inbox\n\n")
    (store / "candidates.md").write_text("# Learning Candidates\n\n" + candidate_entry)
    (store / "inbox.md").write_text("# Learning Inbox\n\n")

    result = capture_scale_picker(tmp_path, "before-merge")

    assert result.returncode == 0, result.stderr
    inbox = (store / "inbox.md").read_text()
    candidates = (store / "candidates.md").read_text()
    assert "Preview guest picker is painful on large events" not in inbox
    assert candidates.count("Preview guest picker is painful on large events") == 1
    assert "- Sources: QA, before-merge" in candidates
    assert "- Additional evidence: On a 500-guest event, the dropdown requires long manual scrolling." in candidates


def test_repo_argument_resolves_to_git_root(tmp_path: Path) -> None:
    (tmp_path / ".git").mkdir()
    nested = tmp_path / "packages" / "web"
    nested.mkdir(parents=True)

    result = run_learn(nested, "init")

    assert result.returncode == 0, result.stderr
    assert (tmp_path / "docs" / "learnings" / "README.md").is_file()
    assert not (nested / "docs" / "learnings").exists()


def test_dashboard_generates_review_surfaces(tmp_path: Path) -> None:
    assert run_learn(tmp_path, "init").returncode == 0
    assert capture_scale_picker(tmp_path, "QA").returncode == 0

    result = run_learn(tmp_path, "dashboard")

    assert result.returncode == 0, result.stderr
    store = tmp_path / "docs" / "learnings"
    markdown = (store / "dashboard.md").read_text()
    html = (store / "dashboard.html").read_text()
    for surface in [markdown, html]:
        assert "Learning Dashboard" in surface
        assert "Preview guest picker is painful on large events" in surface
        assert "Users waste time finding a guest and may think preview is broken." in surface
    assert "<h1>Learning Dashboard</h1>" in html


def test_dashboard_html_is_interactive_decision_app(tmp_path: Path) -> None:
    assert run_learn(tmp_path, "init").returncode == 0
    assert capture_scale_picker(tmp_path, "QA").returncode == 0

    result = run_learn(tmp_path, "dashboard")

    assert result.returncode == 0, result.stderr
    html = (tmp_path / "docs" / "learnings" / "dashboard.html").read_text()
    assert 'data-action="archive"' in html
    assert 'data-action="candidate"' in html
    assert 'data-action="defer"' in html
    assert 'data-action="calibration"' in html
    assert "<details" in html
    assert "Technical refs" in html
    assert "Evidence" in html
    assert "Calibration" in html
    assert "fetch(" in html
    assert "decisions.jsonl" in html
    assert "Export JSONL" in html


def test_dashboard_finish_waits_for_pending_decision_saves(tmp_path: Path) -> None:
    assert run_learn(tmp_path, "init").returncode == 0
    assert capture_scale_picker(tmp_path, "QA").returncode == 0

    result = run_learn(tmp_path, "dashboard")

    assert result.returncode == 0, result.stderr
    html = (tmp_path / "docs" / "learnings" / "dashboard.html").read_text()
    assert "const pendingSaves = []" in html
    assert "pendingSaves.push(save)" in html
    assert "await Promise.allSettled(pendingSaves)" in html
    assert "await finishReview()" in html


def test_dashboard_server_records_decision_post(tmp_path: Path) -> None:
    assert run_learn(tmp_path, "init").returncode == 0
    assert capture_scale_picker(tmp_path, "QA").returncode == 0
    store = tmp_path / "docs" / "learnings"
    fingerprint = fingerprint_from((store / "inbox.md").read_text())
    proc = subprocess.Popen(
        [
            sys.executable,
            str(LEARN),
            "--repo",
            str(tmp_path),
            "dashboard",
            "--serve",
            "--host",
            "127.0.0.1",
            "--port",
            "0",
        ],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    try:
        assert proc.stdout is not None
        url = proc.stdout.readline().strip()
        assert url.startswith("http://127.0.0.1:"), url
        payload = json.dumps(
            {
                "fingerprint": fingerprint,
                "action": "archive",
                "note": "Duplicate of existing searchable picker note",
            }
        ).encode()
        request = urllib.request.Request(
            url + "/decisions",
            data=payload,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        for _ in range(30):
            try:
                with urllib.request.urlopen(request, timeout=1) as response:
                    assert response.status == 200
                break
            except OSError:
                time.sleep(0.05)
        else:
            raise AssertionError("dashboard server did not accept decision post")
    finally:
        proc.terminate()
        proc.wait(timeout=5)

    decisions = (store / "decisions.jsonl").read_text().splitlines()
    assert len(decisions) == 1
    assert json.loads(decisions[0]) == {
        "fingerprint": fingerprint,
        "action": "archive",
        "note": "Duplicate of existing searchable picker note",
    }


def test_dashboard_server_finish_executes_decisions_and_exits(tmp_path: Path) -> None:
    assert run_learn(tmp_path, "init").returncode == 0
    assert capture_learning(tmp_path, summary="Archive reviewed dashboard note", artifact="archive").returncode == 0
    store = tmp_path / "docs" / "learnings"
    fingerprint = fingerprint_from((store / "inbox.md").read_text())
    proc = subprocess.Popen(
        [
            sys.executable,
            str(LEARN),
            "--repo",
            str(tmp_path),
            "dashboard",
            "--serve",
            "--execute-on-finish",
            "--host",
            "127.0.0.1",
            "--port",
            "0",
        ],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    try:
        assert proc.stdout is not None
        url = proc.stdout.readline().strip()
        assert url.startswith("http://127.0.0.1:"), url
        decision_payload = json.dumps(
            {"fingerprint": fingerprint, "action": "archive", "note": "review complete"}
        ).encode()
        decision_request = urllib.request.Request(
            url + "/decisions",
            data=decision_payload,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(decision_request, timeout=2) as response:
            assert response.status == 200
        finish_request = urllib.request.Request(
            url + "/finish",
            data=b"{}",
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(finish_request, timeout=2) as response:
            assert response.status == 200
        proc.wait(timeout=5)
    finally:
        if proc.poll() is None:
            proc.terminate()
            proc.wait(timeout=5)

    assert proc.returncode == 0
    assert (store / "decisions.jsonl").read_text() == ""
    assert "Archive reviewed dashboard note" not in (store / "inbox.md").read_text()
    archived = "\n".join(path.read_text() for path in (store / "archive").glob("*.md"))
    assert "Archive reviewed dashboard note" in archived
    assert f"archive: {fingerprint} review complete" in (store / "auto-actions.md").read_text()


def test_dashboard_includes_direct_learning_entries(tmp_path: Path) -> None:
    assert run_learn(tmp_path, "init").returncode == 0
    assert capture_scale_picker(tmp_path, "QA").returncode == 0
    store = tmp_path / "docs" / "learnings"
    direct = store / "promoted.md"
    direct.write_text("# Promoted Learnings\n\n" + (store / "inbox.md").read_text())
    (store / "inbox.md").write_text("# Learning Inbox\n\n")

    result = run_learn(tmp_path, "dashboard")

    assert result.returncode == 0, result.stderr
    dashboard = (store / "dashboard.md").read_text()
    assert "## promoted.md" in dashboard
    assert "Preview guest picker is painful on large events" in dashboard


def test_dashboard_keeps_markdown_headings_inside_multiline_evidence(tmp_path: Path) -> None:
    assert run_learn(tmp_path, "init").returncode == 0
    assert capture_multiline_evidence(tmp_path).returncode == 0
    assert capture_learning(
        tmp_path,
        summary="Second learning remains separate",
        artifact="docs",
        technical_ref="docs/learnings/second.md",
    ).returncode == 0

    result = run_learn(tmp_path, "dashboard")

    assert result.returncode == 0, result.stderr
    dashboard = (tmp_path / "docs" / "learnings" / "dashboard.md").read_text()
    html = (tmp_path / "docs" / "learnings" / "dashboard.html").read_text()
    assert "### This is evidence, not a learning entry" in dashboard
    assert "Second observed line." in dashboard
    assert "Second learning remains separate" in dashboard
    assert dashboard.count("- Fingerprint: ") == 2
    assert "This is evidence, not a learning entry" in html
    assert "Second observed line." in html


def test_dashboard_shows_required_triage_signals(tmp_path: Path) -> None:
    assert run_learn(tmp_path, "init").returncode == 0
    assert capture_learning(tmp_path, summary="Docs candidate needs review", artifact="docs").returncode == 0
    assert capture_learning(
        tmp_path,
        summary="Blocked helper needs TDD",
        artifact="helper",
        technical_ref="bin/helper",
    ).returncode == 0
    store = tmp_path / "docs" / "learnings"
    fingerprints = [
        line.removeprefix("- Fingerprint: ")
        for line in (store / "inbox.md").read_text().splitlines()
        if line.startswith("- Fingerprint: ")
    ]
    (store / "decisions.jsonl").write_text(
        json.dumps({"fingerprint": fingerprints[0], "action": "candidate", "note": "docs candidate"})
        + "\n"
        + json.dumps({"fingerprint": fingerprints[1], "action": "block", "note": "needs TDD"})
        + "\n"
        + json.dumps({"fingerprint": "global", "action": "calibration", "note": "Prefer docs candidates"})
        + "\n"
    )
    assert run_learn(tmp_path, "execute").returncode == 0

    result = run_learn(tmp_path, "dashboard")

    assert result.returncode == 0, result.stderr
    dashboard = (store / "dashboard.html").read_text()
    for label in [
        "Needs Review",
        "Open Items",
        "Auto Done",
        "Raw Inbox",
        "Candidates",
        "Aging/Stale",
        "Likely Duplicates",
        "Calibration Learned",
        "Blocked Decisions",
        "Ask Agent Prompts",
    ]:
        assert label in dashboard
    assert "Prefer docs candidates" in dashboard
    assert "needs TDD" in dashboard


def test_dashboard_renders_additional_evidence_from_exact_replay_entries(tmp_path: Path) -> None:
    assert run_learn(tmp_path, "init").returncode == 0
    assert capture_scale_picker(tmp_path, "QA").returncode == 0
    assert capture_scale_picker(tmp_path, "before-merge").returncode == 0

    result = run_learn(tmp_path, "dashboard")

    assert result.returncode == 0, result.stderr
    dashboard = (tmp_path / "docs" / "learnings" / "dashboard.html").read_text()
    assert "Additional evidence" in dashboard
    assert "On a 500-guest event, the dropdown requires long manual scrolling." in dashboard


def test_dashboard_counts_old_captured_entries_as_aging_without_keyword(tmp_path: Path) -> None:
    assert run_learn(tmp_path, "init").returncode == 0
    assert capture_learning(
        tmp_path,
        summary="Old docs learning needs review",
        artifact="docs",
        technical_ref="docs/learnings/old.md",
    ).returncode == 0
    store = tmp_path / "docs" / "learnings"
    inbox_path = store / "inbox.md"
    inbox_path.write_text(inbox_path.read_text().replace("- Captured: ", "- Captured: 2000-01-01 # "))

    result = run_learn(tmp_path, "dashboard")

    assert result.returncode == 0, result.stderr
    dashboard = (store / "dashboard.html").read_text()
    assert "Aging/Stale" in dashboard
    assert "<strong>Aging/Stale</strong>: 1" in dashboard


def test_dashboard_details_render_prior_decisions_and_drafts(tmp_path: Path) -> None:
    assert run_learn(tmp_path, "init").returncode == 0
    assert capture_learning(
        tmp_path,
        summary="Dashboard should preserve decision history",
        artifact="docs",
        technical_ref="docs/learnings/dashboard.md",
    ).returncode == 0
    store = tmp_path / "docs" / "learnings"
    fingerprint = fingerprint_from((store / "inbox.md").read_text())
    (store / "decisions.jsonl").write_text(
        json.dumps({"fingerprint": fingerprint, "action": "note", "note": "Keep this visible"})
        + "\n"
        + json.dumps({"fingerprint": fingerprint, "action": "follow-up", "note": "Ask reviewer for wording"})
        + "\n"
        + json.dumps({"fingerprint": fingerprint, "action": "draft-plan", "note": "plan dashboard detail"})
        + "\n"
        + json.dumps({"fingerprint": fingerprint, "action": "draft-patch", "note": "patch dashboard detail"})
        + "\n"
    )
    assert run_learn(tmp_path, "execute").returncode == 0

    result = run_learn(tmp_path, "dashboard")

    assert result.returncode == 0, result.stderr
    dashboard = (store / "dashboard.html").read_text()
    assert "Previous decisions" in dashboard
    assert "Decision note" in dashboard
    assert "Keep this visible" in dashboard
    assert "Follow-up task" in dashboard
    assert "Ask reviewer for wording" in dashboard
    assert "Draft plan" in dashboard
    assert f"drafts/{fingerprint}-plan.md" in dashboard
    assert "Draft patch" in dashboard
    assert f"drafts/{fingerprint}-patch.md" in dashboard


def test_execute_records_dashboard_decisions(tmp_path: Path) -> None:
    assert run_learn(tmp_path, "init").returncode == 0
    store = tmp_path / "docs" / "learnings"
    (store / "decisions.jsonl").write_text(
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
    assert (store / "decisions.jsonl").read_text() == ""
    assert (
        "decision: archive abc123 Duplicate of searchable picker candidate"
        in (store / "auto-actions.md").read_text()
    )


def test_execute_archive_decision_removes_open_entry(tmp_path: Path) -> None:
    assert run_learn(tmp_path, "init").returncode == 0
    assert capture_scale_picker(tmp_path, "QA").returncode == 0
    store = tmp_path / "docs" / "learnings"
    fingerprint = fingerprint_from((store / "inbox.md").read_text())
    (store / "decisions.jsonl").write_text(
        json.dumps({"fingerprint": fingerprint, "action": "archive", "note": "covered elsewhere"})
        + "\n"
    )

    result = run_learn(tmp_path, "execute")
    dashboard = run_learn(tmp_path, "dashboard")

    assert result.returncode == 0, result.stderr
    assert dashboard.returncode == 0, dashboard.stderr
    assert "Preview guest picker is painful on large events" not in (store / "inbox.md").read_text()
    assert "Preview guest picker is painful on large events" not in (store / "dashboard.md").read_text()
    archived_files = list((store / "archive").glob(f"{fingerprint}*.md"))
    assert len(archived_files) == 1
    assert "- Status: archived" in archived_files[0].read_text()
    assert f"archive: {fingerprint} covered elsewhere" in (store / "auto-actions.md").read_text()


def test_capture_reopens_archived_fingerprint_as_open_learning(tmp_path: Path) -> None:
    assert run_learn(tmp_path, "init").returncode == 0
    assert capture_scale_picker(tmp_path, "QA").returncode == 0
    store = tmp_path / "docs" / "learnings"
    fingerprint = fingerprint_from((store / "inbox.md").read_text())
    (store / "decisions.jsonl").write_text(
        json.dumps({"fingerprint": fingerprint, "action": "archive", "note": "not current"})
        + "\n"
    )
    assert run_learn(tmp_path, "execute").returncode == 0

    result = capture_scale_picker(tmp_path, "before-merge")
    dashboard = run_learn(tmp_path, "dashboard")
    merge_check = run_learn(tmp_path, "check-merge")

    assert result.returncode == 0, result.stderr
    assert dashboard.returncode == 0, dashboard.stderr
    inbox = (store / "inbox.md").read_text()
    assert "Preview guest picker is painful on large events" in inbox
    assert "- Sources: QA, before-merge" in inbox
    assert "- Status: inbox" in inbox
    assert "Preview guest picker is painful on large events" in (store / "dashboard.md").read_text()
    assert merge_check.returncode == 1
    assert f"reopen: {fingerprint} merged source before-merge" in (store / "auto-actions.md").read_text()


def test_capture_reopens_archive_with_new_dashboard_metadata(tmp_path: Path) -> None:
    assert run_learn(tmp_path, "init").returncode == 0
    assert capture_learning(
        tmp_path,
        summary="Archived learning should return with fresh metadata",
        artifact="archive",
        confidence="medium",
        technical_ref="docs/learnings/reopen.md",
    ).returncode == 0
    store = tmp_path / "docs" / "learnings"
    fingerprint = fingerprint_from((store / "inbox.md").read_text())
    (store / "decisions.jsonl").write_text(
        json.dumps({"fingerprint": fingerprint, "action": "archive", "note": "old archive"})
        + "\n"
    )
    assert run_learn(tmp_path, "execute").returncode == 0

    result = capture_learning(
        tmp_path,
        summary="Archived learning should return with fresh metadata",
        artifact="docs",
        confidence="high",
        technical_ref="docs/learnings/reopen.md",
    )
    merge_check = run_learn(tmp_path, "check-merge")
    dashboard = run_learn(tmp_path, "dashboard")

    assert result.returncode == 0, result.stderr
    assert merge_check.returncode == 1
    assert dashboard.returncode == 0, dashboard.stderr
    inbox = (store / "inbox.md").read_text()
    html = (store / "dashboard.html").read_text()
    assert "- Candidate artifact: docs" in inbox
    assert "- Confidence: high" in inbox
    assert "- Recommended fix: Route the learning to the closest durable prevention artifact." in inbox
    assert "- Status: inbox" in inbox
    assert "docs" in html
    assert "high" in html
    assert f"reopen: {fingerprint} merged source review" in (store / "auto-actions.md").read_text()


def test_execute_candidate_and_promote_decisions_move_open_entry(tmp_path: Path) -> None:
    assert run_learn(tmp_path, "init").returncode == 0
    assert capture_learning(tmp_path, summary="Docs should name the shared picker", artifact="docs").returncode == 0
    assert capture_learning(
        tmp_path,
        summary="Merge guard should mention dashboard review",
        artifact="docs",
        technical_ref="docs/learnings/merge.md",
    ).returncode == 0
    store = tmp_path / "docs" / "learnings"
    fingerprints = [
        line.removeprefix("- Fingerprint: ")
        for line in (store / "inbox.md").read_text().splitlines()
        if line.startswith("- Fingerprint: ")
    ]
    (store / "decisions.jsonl").write_text(
        json.dumps({"fingerprint": fingerprints[0], "action": "candidate", "note": "good docs guardrail"})
        + "\n"
        + json.dumps({"fingerprint": fingerprints[1], "action": "promote", "note": "approved docs guardrail"})
        + "\n"
    )

    result = run_learn(tmp_path, "execute")

    assert result.returncode == 0, result.stderr
    inbox = (store / "inbox.md").read_text()
    candidates = (store / "candidates.md").read_text()
    assert "Docs should name the shared picker" not in inbox
    assert "Merge guard should mention dashboard review" not in inbox
    assert "- Status: candidate" in candidates
    assert "- Status: promoted" in candidates
    assert f"candidate: {fingerprints[0]} good docs guardrail" in (store / "auto-actions.md").read_text()
    assert f"promote: {fingerprints[1]} approved docs guardrail" in (store / "auto-actions.md").read_text()


def test_execute_code_related_promote_creates_tdd_followup_and_keeps_open(tmp_path: Path) -> None:
    assert run_learn(tmp_path, "init").returncode == 0
    assert capture_learning(
        tmp_path,
        summary="Shared picker helper should enforce scale",
        artifact="helper",
        technical_ref="bin/preview-helper",
    ).returncode == 0
    assert capture_learning(
        tmp_path,
        summary="Skill should block unsafe dashboard execution",
        artifact="skill",
        technical_ref=".agents/skills/learn/SKILL.md",
    ).returncode == 0
    store = tmp_path / "docs" / "learnings"
    fingerprints = [
        line.removeprefix("- Fingerprint: ")
        for line in (store / "inbox.md").read_text().splitlines()
        if line.startswith("- Fingerprint: ")
    ]
    (store / "decisions.jsonl").write_text(
        json.dumps({"fingerprint": fingerprints[0], "action": "promote", "note": "implement helper guard"})
        + "\n"
        + json.dumps({"fingerprint": fingerprints[1], "action": "candidate", "note": "update skill docs"})
        + "\n"
    )

    result = run_learn(tmp_path, "execute")

    assert result.returncode == 0, result.stderr
    inbox = (store / "inbox.md").read_text()
    candidates = (store / "candidates.md").read_text()
    audit = (store / "auto-actions.md").read_text()
    assert "Shared picker helper should enforce scale" in inbox
    assert "Skill should block unsafe dashboard execution" in inbox
    assert "Shared picker helper should enforce scale" not in candidates
    assert "Skill should block unsafe dashboard execution" not in candidates
    assert "- Follow-up task: TDD/review required before promote: implement helper guard" in inbox
    assert "- Follow-up task: TDD/review required before candidate: update skill docs" in inbox
    assert f"follow-up: {fingerprints[0]} TDD/review required before promote" in audit
    assert f"follow-up: {fingerprints[1]} TDD/review required before candidate" in audit


def test_execute_preserves_code_risk_when_artifact_changed_before_promote(tmp_path: Path) -> None:
    assert run_learn(tmp_path, "init").returncode == 0
    assert capture_learning(
        tmp_path,
        summary="Helper risk should not be laundered through docs",
        artifact="helper",
        technical_ref="bin/learn-helper",
    ).returncode == 0
    store = tmp_path / "docs" / "learnings"
    fingerprint = fingerprint_from((store / "inbox.md").read_text())
    (store / "decisions.jsonl").write_text(
        json.dumps(
            {
                "fingerprint": fingerprint,
                "action": "candidate-artifact",
                "value": "docs",
                "note": "try docs first",
            }
        )
        + "\n"
        + json.dumps({"fingerprint": fingerprint, "action": "promote", "note": "promote after docs"})
        + "\n"
    )

    result = run_learn(tmp_path, "execute")

    assert result.returncode == 0, result.stderr
    inbox = (store / "inbox.md").read_text()
    candidates = (store / "candidates.md").read_text()
    audit = (store / "auto-actions.md").read_text()
    assert "Helper risk should not be laundered through docs" in inbox
    assert "Helper risk should not be laundered through docs" not in candidates
    assert "- Candidate artifact: docs" in inbox
    assert "- Requires TDD/review: yes" in inbox
    assert "- Follow-up task: TDD/review required before promote: promote after docs" in inbox
    assert f"follow-up: {fingerprint} TDD/review required before promote" in audit


def test_execute_metadata_decisions_update_learning_files(tmp_path: Path) -> None:
    assert run_learn(tmp_path, "init").returncode == 0
    assert capture_scale_picker(tmp_path, "QA").returncode == 0
    store = tmp_path / "docs" / "learnings"
    fingerprint = fingerprint_from((store / "inbox.md").read_text())
    (store / "decisions.jsonl").write_text(
        json.dumps({"fingerprint": fingerprint, "action": "confidence", "value": "low", "note": "not recurring"})
        + "\n"
        + json.dumps({"fingerprint": fingerprint, "action": "candidate-artifact", "value": "docs", "note": "docs only"})
        + "\n"
        + json.dumps({"fingerprint": fingerprint, "action": "note", "note": "Revisit after next preview QA"})
        + "\n"
        + json.dumps({"fingerprint": fingerprint, "action": "calibration", "note": "High confidence was too strong"})
        + "\n"
    )

    result = run_learn(tmp_path, "execute")

    assert result.returncode == 0, result.stderr
    inbox = (store / "inbox.md").read_text()
    assert "- Confidence: low" in inbox
    assert "- Candidate artifact: docs" in inbox
    assert "- Decision note: Revisit after next preview QA" in inbox
    assert f"- {fingerprint}: High confidence was too strong" in (store / "calibration.md").read_text()
    assert (store / "decisions.jsonl").read_text() == ""


def test_execute_revision_followup_and_draft_decisions_update_canonical_records(
    tmp_path: Path,
) -> None:
    assert run_learn(tmp_path, "init").returncode == 0
    assert capture_learning(tmp_path, summary="Docs wording is vague", artifact="docs").returncode == 0
    store = tmp_path / "docs" / "learnings"
    fingerprint = fingerprint_from((store / "inbox.md").read_text())
    (store / "decisions.jsonl").write_text(
        json.dumps(
            {
                "fingerprint": fingerprint,
                "action": "revise-wording",
                "value": "Docs wording should name dashboard finish flow",
                "note": "make the learning specific",
            }
        )
        + "\n"
        + json.dumps({"fingerprint": fingerprint, "action": "follow-up", "note": "write regression test"})
        + "\n"
        + json.dumps({"fingerprint": fingerprint, "action": "draft-plan", "note": "plan docs update"})
        + "\n"
        + json.dumps({"fingerprint": fingerprint, "action": "draft-patch", "note": "patch docs wording"})
        + "\n"
    )

    result = run_learn(tmp_path, "execute")

    assert result.returncode == 0, result.stderr
    inbox = (store / "inbox.md").read_text()
    audit = (store / "auto-actions.md").read_text()
    assert "- User-facing summary: Docs wording should name dashboard finish flow" in inbox
    assert "- Follow-up task: write regression test" in inbox
    assert "- Follow-up task: Draft plan requested: plan docs update" in inbox
    assert "- Follow-up task: Draft patch requested: patch docs wording" in inbox
    assert f"revise-wording: {fingerprint}" in audit
    assert f"follow-up: {fingerprint} write regression test" in audit
    assert f"draft-plan: {fingerprint} TDD/review task marker created" in audit
    assert f"draft-patch: {fingerprint} TDD/review task marker created" in audit


def test_execute_draft_decisions_create_draft_artifacts_and_link_entry(tmp_path: Path) -> None:
    assert run_learn(tmp_path, "init").returncode == 0
    assert capture_learning(
        tmp_path,
        summary="Shared skill needs dashboard finish docs",
        artifact="skill",
        technical_ref=".agents/skills/learn/SKILL.md",
    ).returncode == 0
    store = tmp_path / "docs" / "learnings"
    fingerprint = fingerprint_from((store / "inbox.md").read_text())
    (store / "decisions.jsonl").write_text(
        json.dumps({"fingerprint": fingerprint, "action": "draft-plan", "note": "plan skill update"})
        + "\n"
        + json.dumps({"fingerprint": fingerprint, "action": "draft-patch", "note": "patch skill update"})
        + "\n"
    )

    result = run_learn(tmp_path, "execute")

    assert result.returncode == 0, result.stderr
    plan = store / "drafts" / f"{fingerprint}-plan.md"
    patch = store / "drafts" / f"{fingerprint}-patch.md"
    assert plan.is_file()
    assert patch.is_file()
    for draft in [plan.read_text(), patch.read_text()]:
        assert "Shared skill needs dashboard finish docs" in draft
        assert "Observed during review: Shared skill needs dashboard finish docs." in draft
        assert "Users lose a durable guardrail if this learning is forgotten." in draft
        assert "Route the learning to the closest durable prevention artifact." in draft
        assert ".agents/skills/learn/SKILL.md" in draft
        assert "TDD/review required before code, shared skill, enforcement, or architecture changes." in draft
    inbox = (store / "inbox.md").read_text()
    audit = (store / "auto-actions.md").read_text()
    assert f"- Draft plan: drafts/{fingerprint}-plan.md" in inbox
    assert f"- Draft patch: drafts/{fingerprint}-patch.md" in inbox
    assert f"draft-plan: {fingerprint} wrote drafts/{fingerprint}-plan.md" in audit
    assert f"draft-patch: {fingerprint} wrote drafts/{fingerprint}-patch.md" in audit


def test_promote_pass_archives_docs_candidates_and_code_followups(tmp_path: Path) -> None:
    assert run_learn(tmp_path, "init").returncode == 0
    assert capture_learning(tmp_path, summary="Archive duplicate picker note", artifact="archive").returncode == 0
    assert capture_learning(tmp_path, summary="Document preview picker threshold", artifact="docs").returncode == 0
    assert capture_learning(
        tmp_path,
        summary="Shared picker helper should enforce scale",
        artifact="helper",
        technical_ref="bin/preview-helper",
    ).returncode == 0
    store = tmp_path / "docs" / "learnings"

    result = run_learn(tmp_path, "promote")

    assert result.returncode == 0, result.stderr
    inbox = (store / "inbox.md").read_text()
    candidates = (store / "candidates.md").read_text()
    archive_text = "\n".join(path.read_text() for path in (store / "archive").glob("*.md"))
    audit = (store / "auto-actions.md").read_text()
    assert "Archive duplicate picker note" not in inbox
    assert "Archive duplicate picker note" in archive_text
    assert "Document preview picker threshold" in candidates
    assert "Shared picker helper should enforce scale" in candidates
    assert "- Status: candidate" in candidates
    assert "auto-promote: candidate" in audit
    assert "auto-promote: archive" in audit
    assert "follow-up required before code changes" in audit


def test_promote_pass_respects_persistent_tdd_review_marker(tmp_path: Path) -> None:
    assert run_learn(tmp_path, "init").returncode == 0
    assert capture_learning(
        tmp_path,
        summary="Docs-looking learning still needs code review",
        artifact="docs",
        technical_ref="docs/learnings/code-risk.md",
    ).returncode == 0
    store = tmp_path / "docs" / "learnings"
    inbox_path = store / "inbox.md"
    inbox_path.write_text(
        inbox_path.read_text().replace(
            "- Confidence: high",
            "- Requires TDD/review: yes\n- Confidence: high",
        )
    )

    result = run_learn(tmp_path, "promote")

    assert result.returncode == 0, result.stderr
    inbox = (store / "inbox.md").read_text()
    candidates = (store / "candidates.md").read_text()
    audit = (store / "auto-actions.md").read_text()
    assert "Docs-looking learning still needs code review" not in inbox
    assert "Docs-looking learning still needs code review" in candidates
    assert "- Requires TDD/review: yes" in candidates
    assert "- Follow-up task: follow-up required before code changes" in candidates
    assert "auto-promote: candidate" in audit
    assert "follow-up required before code changes" in audit


def test_check_merge_flags_high_confidence_items(tmp_path: Path) -> None:
    assert run_learn(tmp_path, "init").returncode == 0
    assert capture_scale_picker(tmp_path, "QA").returncode == 0

    result = run_learn(tmp_path, "check-merge")

    assert result.returncode == 1
    assert "high-confidence item" in result.stdout


def test_check_merge_flags_direct_learning_entries(tmp_path: Path) -> None:
    assert run_learn(tmp_path, "init").returncode == 0
    assert capture_scale_picker(tmp_path, "QA").returncode == 0
    store = tmp_path / "docs" / "learnings"
    direct = store / "promoted.md"
    direct.write_text("# Promoted Learnings\n\n" + (store / "inbox.md").read_text())
    (store / "inbox.md").write_text("# Learning Inbox\n\n")

    result = run_learn(tmp_path, "check-merge")

    assert result.returncode == 1
    assert "high-confidence item" in result.stdout
