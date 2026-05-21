#!/usr/bin/env python3

import importlib.machinery
import importlib.util
import json
import os
import subprocess
import tempfile
import time
import unittest
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "bin" / "ask-intern-audit"


def load_audit_module():
    loader = importlib.machinery.SourceFileLoader("ask_intern_audit_under_test", str(SCRIPT))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


class AskInternAuditTest(unittest.TestCase):
    def test_event_log_timestamps_are_utc(self):
        module = load_audit_module()

        expected = datetime(2026, 5, 9, 4, 30, tzinfo=timezone.utc).timestamp()

        self.assertEqual(module.event_epoch("2026-05-09 04:30:00"), expected)

    def test_since_until_filter_events_with_iso_offsets(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmpdir = Path(tmp)
            events = tmpdir / "events.tsv"
            events.write_text(
                "\n".join(
                    [
                        "timestamp\tsource\tstatus\treason\tmodel\tfile_count\ttarget\tlatency_s\tcwd\tfiles\tinvocation",
                        "2026-05-09 04:29:59\tclaude\tsuccess\tok\tdeepseek/deepseek-v4-flash\t1\t\t1.00\t/repo\tbefore.md\task-intern -f before.md prompt",
                        "2026-05-09 04:30:00\tclaude\tsuccess\tok\tdeepseek/deepseek-v4-flash\t1\t\t1.00\t/repo\tinside.md\task-intern -f inside.md prompt",
                        "2026-05-12 03:03:01\tclaude\tsuccess\tok\tdeepseek/deepseek-v4-flash\t1\t\t1.00\t/repo\tafter.md\task-intern -f after.md prompt",
                    ]
                )
                + "\n",
                encoding="utf-8",
            )

            result = subprocess.run(
                [
                    str(SCRIPT),
                    "--events",
                    str(events),
                    "--log-root",
                    str(tmpdir / "missing-logs"),
                    "--since",
                    "2026-05-09T01:30:00-03:00",
                    "--until",
                    "2026-05-12T00:03:00-03:00",
                ],
                check=False,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("ask-intern calls: 1 (success 1, failure 0)", result.stdout)
        self.assertNotIn("before.md", result.stdout)
        self.assertNotIn("after.md", result.stdout)

    def test_since_last_requires_recorded_state(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmpdir = Path(tmp)
            events = tmpdir / "events.tsv"
            state = tmpdir / "audit-state.json"
            events.write_text(
                "timestamp\tsource\tstatus\treason\tmodel\tfile_count\ttarget\tlatency_s\tcwd\tfiles\tinvocation\n",
                encoding="utf-8",
            )

            result = subprocess.run(
                [
                    str(SCRIPT),
                    "--events",
                    str(events),
                    "--log-root",
                    str(tmpdir / "missing-logs"),
                    "--state",
                    str(state),
                    "--since-last",
                ],
                check=False,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("No previous ask-intern audit state", result.stderr)

    def test_record_run_and_since_last_state(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmpdir = Path(tmp)
            events = tmpdir / "events.tsv"
            state = tmpdir / "audit-state.json"
            events.write_text(
                "\n".join(
                    [
                        "timestamp\tsource\tstatus\treason\tmodel\tfile_count\ttarget\tlatency_s\tcwd\tfiles\tinvocation",
                        "2026-05-12 03:02:59\tclaude\tsuccess\tok\tdeepseek/deepseek-v4-flash\t1\t\t1.00\t/repo\tbefore.md\task-intern -f before.md prompt",
                        "2026-05-12 03:03:01\tcodex\tsuccess\tok\tdeepseek/deepseek-v4-flash\t1\t\t1.00\t/repo\tafter.md\task-intern -f after.md prompt",
                    ]
                )
                + "\n",
                encoding="utf-8",
            )

            seed_until = datetime(2026, 5, 12, 3, 3, tzinfo=timezone.utc).timestamp()
            state.write_text(
                json.dumps({"last_run": {"until_epoch": seed_until, "until": "2026-05-12T03:03:00Z"}}),
                encoding="utf-8",
            )

            result = subprocess.run(
                [
                    str(SCRIPT),
                    "--events",
                    str(events),
                    "--log-root",
                    str(tmpdir / "missing-logs"),
                    "--state",
                    str(state),
                    "--since-last",
                    "--until",
                    "2026-05-12T00:04:00-03:00",
                    "--record-run",
                ],
                check=False,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )

            stored = json.loads(state.read_text(encoding="utf-8"))

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("ask-intern calls: 1 (success 1, failure 0)", result.stdout)
        self.assertIn("since last recorded audit", result.stdout)
        self.assertNotIn("before.md", result.stdout)
        self.assertEqual(stored["last_run"]["until"], "2026-05-12T03:04:00Z")
        self.assertEqual(stored["last_run"]["sources"], {"codex": 1})

    def test_reports_failures_direct_reads_and_missed_sessions(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmpdir = Path(tmp)
            events = tmpdir / "events.tsv"
            now = time.strftime("%Y-%m-%d %H:%M:%S")
            events.write_text(
                "\n".join(
                    [
                        "timestamp\tsource\tstatus\treason\tmodel\tfile_count\ttarget\tlatency_s\tcwd\tfiles\tinvocation",
                        f"{now}\tclaude\tsuccess\tok\tdeepseek/deepseek-v4-flash\t2\t\t1.00\t/repo\ta.md,b.md\task-intern -f a.md -f b.md prompt",
                        f"{now}\tcodex\tfailure\tmissing_file\tdeepseek/deepseek-v4-flash\t1\t\t0.00\t/repo\tAGENTS.md\task-intern -f AGENTS.md prompt",
                    ]
                )
                + "\n",
                encoding="utf-8",
            )

            good_log = tmpdir / "session-with-intern.jsonl"
            good_log.write_text(
                "\n".join(
                    [
                        '{"type":"response_item","payload":{"type":"function_call","name":"exec_command","arguments":"{\\"cmd\\":\\"sed -n \'1,80p\' a.md\\"}"}}',
                        '{"type":"response_item","payload":{"type":"function_call","name":"exec_command","arguments":"{\\"cmd\\":\\"ask-intern -f a.md -f b.md summarize\\"}"}}',
                    ]
                )
                + "\n",
                encoding="utf-8",
            )

            missed_log = tmpdir / "session-missed.jsonl"
            missed_log.write_text(
                "\n".join(
                    [
                        '{"type":"response_item","payload":{"type":"function_call","name":"exec_command","arguments":"{\\"cmd\\":\\"sed -n \'1,220p\' alpha.md\\"}"}}',
                        '{"type":"response_item","payload":{"type":"function_call","name":"exec_command","arguments":"{\\"cmd\\":\\"cat beta.md\\"}"}}',
                        '{"type":"response_item","payload":{"type":"function_call","name":"exec_command","arguments":"{\\"cmd\\":\\"nl -ba gamma.md | sed -n \'1,120p\'\\"}"}}',
                    ]
                )
                + "\n",
                encoding="utf-8",
            )

            old_log = tmpdir / "old-session.jsonl"
            old_log.write_text(
                '{"type":"response_item","payload":{"type":"function_call","name":"exec_command","arguments":"{\\"cmd\\":\\"cat stale.md\\"}"}}\n',
                encoding="utf-8",
            )
            old_time = time.time() - 10 * 24 * 60 * 60
            os.utime(old_log, (old_time, old_time))

            result = subprocess.run(
                [
                    str(SCRIPT),
                    "--events",
                    str(events),
                    "--log",
                    str(good_log),
                    "--log",
                    str(missed_log),
                    "--log",
                    str(old_log),
                    "--min-direct-reads",
                    "3",
                    "--since-days",
                    "1",
                ],
                check=False,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("ask-intern calls: 2 (success 1, failure 1)", result.stdout)
        self.assertIn("sources:", result.stdout)
        self.assertIn("- claude: 1", result.stdout)
        self.assertIn("- codex: 1", result.stdout)
        self.assertIn("missing_file: 1", result.stdout)
        self.assertIn("suspicious direct reads: 4", result.stdout)
        self.assertIn("likely missed delegations: 1", result.stdout)
        self.assertIn("session-missed.jsonl", result.stdout)
        self.assertIn("alpha.md", result.stdout)

    def test_negated_exact_source_prompt_is_not_reported_as_over_delegation(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmpdir = Path(tmp)
            events = tmpdir / "events.tsv"
            now = time.strftime("%Y-%m-%d %H:%M:%S")
            events.write_text(
                "\n".join(
                    [
                        "timestamp\tsource\tstatus\treason\tmodel\tfile_count\ttarget\tlatency_s\tcwd\tfiles\tinvocation",
                        f"{now}\tclaude\tsuccess\tok\tdeepseek/deepseek-v4-flash\t1\t\t1.00\t/repo\treview.html\task-intern -f review.html 'Don'\"'\"'t reproduce exact code; just describe it'",
                        f"{now}\tclaude\tsuccess\tok\tdeepseek/deepseek-v4-flash\t1\t\t1.00\t/repo\tqueue.md\task-intern -f queue.md \"Do not quote exact code or full source; line numbers are not needed.\"",
                        f"{now}\tclaude\tsuccess\tok\tdeepseek/deepseek-v4-flash\t1\t\t1.00\t/repo\tcodex-review.output\task-intern -f codex-review.output \"This is the output of codex review. Extract ONLY the review FINDINGS, not the diff. For each finding: severity, file:line, and what the issue is. List every finding verbatim-enough that I can act on it. Ignore the streamed code diff.\"",
                        f"{now}\tcodex\tfailure\texact_source_request\tdeepseek/deepseek-v4-flash\t1\t\t0.00\t/repo\tapp.ts\task-intern -f app.ts \"Show me the exact code\"",
                    ]
                )
                + "\n",
                encoding="utf-8",
            )

            result = subprocess.run(
                [
                    str(SCRIPT),
                    "--events",
                    str(events),
                    "--log-root",
                    str(tmpdir / "missing-logs"),
                    "--since-days",
                    "1",
                ],
                check=False,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("- exact/verbatim prompts: 1", result.stdout)
        self.assertIn("Show me the exact code", result.stdout)
        self.assertNotIn("reproduce exact code", result.stdout)
        self.assertNotIn("verbatim-enough", result.stdout)

    def test_filters_docs_generated_binary_and_temp_direct_reads(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmpdir = Path(tmp)
            events = tmpdir / "events.tsv"
            now = time.strftime("%Y-%m-%d %H:%M:%S")
            events.write_text(
                "timestamp\tsource\tstatus\treason\tmodel\tfile_count\ttarget\tlatency_s\tcwd\tfiles\tinvocation\n",
                encoding="utf-8",
            )
            session = tmpdir / "session-noise.jsonl"
            session.write_text(
                "\n".join(
                    [
                        '{"type":"response_item","payload":{"type":"function_call","name":"exec_command","arguments":"{\\"cmd\\":\\"cat docs/spec.md\\"}"}}',
                        '{"type":"response_item","payload":{"type":"function_call","name":"exec_command","arguments":"{\\"cmd\\":\\"cat /Users/david/.codex/RTK.md\\"}"}}',
                        '{"type":"response_item","payload":{"type":"function_call","name":"exec_command","arguments":"{\\"cmd\\":\\"cat graphify-out/wiki/index.md\\"}"}}',
                        '{"type":"response_item","payload":{"type":"function_call","name":"exec_command","arguments":"{\\"cmd\\":\\"cat assets/screenshot.png\\"}"}}',
                        '{"type":"response_item","payload":{"type":"function_call","name":"exec_command","arguments":"{\\"cmd\\":\\"cat /tmp/generated.txt\\"}"}}',
                        '{"type":"response_item","payload":{"type":"function_call","name":"exec_command","arguments":"{\\"cmd\\":\\"cat .git/rebase-merge/done\\"}"}}',
                        '{"type":"response_item","payload":{"type":"function_call","name":"exec_command","arguments":"{\\"cmd\\":\\"cat ~/.agents/observations/project/log.md\\"}"}}',
                        '{"type":"response_item","payload":{"type":"function_call","name":"exec_command","arguments":"{\\"cmd\\":\\"git commit -m \\\\\\"fix grep|head under pipefail\\\\\\"\\"}"}}',
                        '{"type":"response_item","payload":{"type":"function_call","name":"exec_command","arguments":"{\\"cmd\\":\\"cat src/large.ts\\"}"}}',
                    ]
                )
                + "\n",
                encoding="utf-8",
            )

            result = subprocess.run(
                [
                    str(SCRIPT),
                    "--events",
                    str(events),
                    "--log",
                    str(session),
                    "--since-days",
                    "1",
                    "--min-direct-reads",
                    "1",
                ],
                check=False,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("suspicious direct reads: 1", result.stdout)
        self.assertIn("src/large.ts", result.stdout)
        self.assertNotIn("RTK.md", result.stdout)
        self.assertNotIn("screenshot.png", result.stdout)

    def test_filters_session_records_by_record_timestamp_not_only_file_mtime(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmpdir = Path(tmp)
            events = tmpdir / "events.tsv"
            now = time.time()
            old_iso = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(now - 3 * 24 * 60 * 60))
            recent_iso = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(now))
            events.write_text(
                "timestamp\tsource\tstatus\treason\tmodel\tfile_count\ttarget\tlatency_s\tcwd\tfiles\tinvocation\n",
                encoding="utf-8",
            )
            session = tmpdir / "recently-touched-old-session.jsonl"
            session.write_text(
                "\n".join(
                    [
                        json_line({"timestamp": old_iso, "type": "response_item", "payload": {"type": "function_call", "name": "exec_command", "arguments": "{\"cmd\":\"cat src/old-a.ts\"}"}}),
                        json_line({"timestamp": old_iso, "type": "response_item", "payload": {"type": "function_call", "name": "exec_command", "arguments": "{\"cmd\":\"cat src/old-b.ts\"}"}}),
                        json_line({"timestamp": old_iso, "type": "response_item", "payload": {"type": "function_call", "name": "exec_command", "arguments": "{\"cmd\":\"cat src/old-c.ts\"}"}}),
                        json_line({"timestamp": recent_iso, "type": "response_item", "payload": {"type": "function_call", "name": "exec_command", "arguments": "{\"cmd\":\"cat src/recent.ts\"}"}}),
                    ]
                )
                + "\n",
                encoding="utf-8",
            )
            os.utime(session, None)

            result = subprocess.run(
                [
                    str(SCRIPT),
                    "--events",
                    str(events),
                    "--log",
                    str(session),
                    "--since-days",
                    "1",
                    "--min-direct-reads",
                    "1",
                ],
                check=False,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("suspicious direct reads: 1", result.stdout)
        self.assertIn("src/recent.ts", result.stdout)
        self.assertNotIn("src/old-a.ts", result.stdout)

    def test_reports_possible_chunk_read_bypasses_from_guard_logs(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmpdir = Path(tmp)
            events = tmpdir / "events.tsv"
            guard_events = tmpdir / "guard.jsonl"
            now = int(time.time())
            events.write_text(
                "timestamp\tsource\tstatus\treason\tmodel\tfile_count\ttarget\tlatency_s\tcwd\tfiles\tinvocation\n",
                encoding="utf-8",
            )
            guard_events.write_text(
                "\n".join(
                    [
                        json_line({"ts": now, "session": "abc", "action": "tracked", "paths": ["/repo/src/app.tsx"], "read_lines": 450}),
                        json_line({"ts": now, "session": "abc", "action": "tracked", "paths": ["/repo/src/app.tsx"], "read_lines": 420}),
                        json_line({"ts": now, "session": "abc", "action": "tracked", "paths": ["/repo/docs/plan.md"], "read_lines": 900}),
                    ]
                )
                + "\n",
                encoding="utf-8",
            )

            result = subprocess.run(
                [
                    str(SCRIPT),
                    "--events",
                    str(events),
                    "--guard-events",
                    str(guard_events),
                    "--log-root",
                    str(tmpdir / "missing-logs"),
                    "--since-days",
                    "1",
                ],
                check=False,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("possible chunk-read bypasses: 1", result.stdout)
        self.assertIn("/repo/src/app.tsx", result.stdout)
        self.assertNotIn("/repo/docs/plan.md", result.stdout)

    def test_reports_raw_git_diff_reads_without_ask_intern(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmpdir = Path(tmp)
            events = tmpdir / "events.tsv"
            now = time.strftime("%Y-%m-%d %H:%M:%S")
            events.write_text(
                "timestamp\tsource\tstatus\treason\tmodel\tfile_count\ttarget\tlatency_s\tcwd\tfiles\tinvocation\n",
                encoding="utf-8",
            )
            missed = tmpdir / "diff-missed.jsonl"
            missed.write_text(
                "\n".join(
                    [
                        json_line({"timestamp": now, "type": "response_item", "payload": {"type": "function_call", "name": "exec_command", "arguments": "{\"cmd\":\"git diff -- src/a.ts | sed -n '1,260p'\"}"}}),
                        json_line({"timestamp": now, "type": "response_item", "payload": {"type": "function_call", "name": "exec_command", "arguments": "{\"cmd\":\"git diff -- src/b.ts\"}"}}),
                        json_line({"timestamp": now, "type": "response_item", "payload": {"type": "function_call", "name": "exec_command", "arguments": "{\"cmd\":\"git diff -- src/tiny.ts | head -40\"}"}}),
                        json_line({"timestamp": now, "type": "response_item", "payload": {"type": "function_call", "name": "exec_command", "arguments": "{\"cmd\":\"git diff --stat\"}"}}),
                        json_line({"timestamp": now, "type": "response_item", "payload": {"type": "function_call", "name": "exec_command", "arguments": "{\"cmd\":\"rtk git diff -- src/filtered.ts\"}"}}),
                    ]
                )
                + "\n",
                encoding="utf-8",
            )
            delegated = tmpdir / "diff-delegated.jsonl"
            delegated.write_text(
                json_line({"timestamp": now, "type": "response_item", "payload": {"type": "function_call", "name": "exec_command", "arguments": "{\"cmd\":\"git diff -- src/c.ts | ask-intern 'summarize'\"}"}})
                + "\n",
                encoding="utf-8",
            )

            result = subprocess.run(
                [
                    str(SCRIPT),
                    "--events",
                    str(events),
                    "--log",
                    str(missed),
                    "--log",
                    str(delegated),
                    "--since-days",
                    "1",
                ],
                check=False,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("possible raw diff missed delegations: 2", result.stdout)
        self.assertIn("diff-missed.jsonl: 2 raw diff reads, no ask-intern", result.stdout)
        self.assertIn("src/a.ts", result.stdout)
        self.assertNotIn("filtered.ts", result.stdout)
        self.assertNotIn("src/c.ts", result.stdout)

    def test_reports_slow_calls_and_abandoned_attempts(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmpdir = Path(tmp)
            events = tmpdir / "events.tsv"
            attempts = tmpdir / "attempts.jsonl"
            now_label = time.strftime("%Y-%m-%d %H:%M:%S")
            now = int(time.time())
            events.write_text(
                "\n".join(
                    [
                        "timestamp\tsource\tstatus\treason\tmodel\tfile_count\ttarget\tlatency_s\tcwd\tfiles\tinvocation",
                        f"{now_label}\tclaude\tsuccess\tok\tdeepseek/deepseek-v4-flash\t1\t\t245.00\t/repo\tbig.ts\task-intern -f big.ts summarize",
                        f"{now_label}\tcodex\tfailure\ttimeout\tdeepseek/deepseek-v4-flash\t2\t\t240.00\t/repo\ta.ts,b.ts\task-intern -f a.ts -f b.ts summarize",
                    ]
                )
                + "\n",
                encoding="utf-8",
            )
            attempts.write_text(
                "\n".join(
                    [
                        json_line({"ts": now - 600, "event": "start", "attempt_id": "open", "source": "claude", "model": "deepseek/deepseek-v4-flash", "files": ["lost.ts"], "invocation": "ask-intern -f lost.ts summarize"}),
                        json_line({"ts": now - 500, "event": "start", "attempt_id": "done", "source": "codex", "model": "deepseek/deepseek-v4-flash", "files": ["done.ts"], "invocation": "ask-intern -f done.ts summarize"}),
                        json_line({"ts": now - 450, "event": "end", "attempt_id": "done", "status": "success", "reason": "ok", "elapsed_s": 50.0}),
                    ]
                )
                + "\n",
                encoding="utf-8",
            )

            result = subprocess.run(
                [
                    str(SCRIPT),
                    "--events",
                    str(events),
                    "--attempts",
                    str(attempts),
                    "--log-root",
                    str(tmpdir / "missing-logs"),
                    "--since-days",
                    "1",
                    "--slow-call-seconds",
                    "180",
                ],
                check=False,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("slow/hang-shaped calls: 2 over 180s", result.stdout)
        self.assertIn("claude success ok 245.0s", result.stdout)
        self.assertIn("codex failure timeout 240.0s", result.stdout)
        self.assertIn("abandoned attempts: 1", result.stdout)
        self.assertIn("lost.ts", result.stdout)


def json_line(value):
    import json

    return json.dumps(value, sort_keys=True)


if __name__ == "__main__":
    unittest.main()
