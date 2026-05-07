#!/usr/bin/env python3

import os
import subprocess
import tempfile
import time
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "bin" / "ask-intern-audit"


class AskInternAuditTest(unittest.TestCase):
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
        self.assertNotIn("screenshot.png", result.stdout)

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


def json_line(value):
    import json

    return json.dumps(value, sort_keys=True)


if __name__ == "__main__":
    unittest.main()
