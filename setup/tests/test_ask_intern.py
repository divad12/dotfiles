#!/usr/bin/env python3

import importlib.machinery
import importlib.util
import io
import json
import os
import sys
import tempfile
import unittest
from datetime import datetime
from pathlib import Path
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "bin" / "ask-intern"


def load_ask_intern(home):
    loader = importlib.machinery.SourceFileLoader("ask_intern_under_test", str(SCRIPT))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    with patch.dict(os.environ, {"HOME": str(home)}, clear=True):
        loader.exec_module(module)
    return module


class AskInternConfigTest(unittest.TestCase):
    def test_config_env_is_loaded_before_defaults_are_read(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            config_dir = home / ".config" / "ask-intern"
            config_dir.mkdir(parents=True)
            (config_dir / "env").write_text(
                "\n".join(
                    [
                        "export OPENROUTER_API_KEY=file-key",
                        'export INTERN_MODEL="test/model"',
                        "export INTERN_MAX_TOKENS=123",
                        "export INTERN_MAX_TOKENS_WRITE=456",
                    ]
                ),
                encoding="utf-8",
            )

            module = load_ask_intern(home)

        self.assertEqual(module.DEFAULT_MODEL, "test/model")
        self.assertEqual(module.MAX_TOKENS_READ, 123)
        self.assertEqual(module.MAX_TOKENS_WRITE, 456)

    def test_request_uses_api_key_from_config_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            config_dir = home / ".config" / "ask-intern"
            config_dir.mkdir(parents=True)
            (config_dir / "env").write_text(
                "export OPENROUTER_API_KEY=file-key\n",
                encoding="utf-8",
            )
            module = load_ask_intern(home)
            module.STATS_FILE = str(config_dir / "stats.tsv")
            module.EVENTS_FILE = str(config_dir / "events.tsv")
            module.ATTEMPTS_FILE = str(config_dir / "attempts.jsonl")
            captured = {}

            class FakeResponse:
                def __enter__(self):
                    return self

                def __exit__(self, exc_type, exc, tb):
                    return False

                def read(self):
                    return json.dumps(
                        {
                            "choices": [{"message": {"content": "ok"}}],
                            "usage": {"prompt_tokens": 10, "completion_tokens": 1},
                        }
                    ).encode("utf-8")

            def fake_urlopen(req, timeout):
                captured["authorization"] = req.get_header("Authorization")
                captured["title"] = req.get_header("X-openrouter-title")
                captured["payload"] = json.loads(req.data.decode("utf-8"))
                return FakeResponse()

            with (
                patch.dict(os.environ, {"HOME": str(home)}, clear=True),
                patch.object(module, "urlopen", fake_urlopen),
                patch.object(sys, "argv", ["ask-intern", "reply", "ok"]),
                patch.object(sys, "stdin", io.StringIO("")),
                patch.object(sys, "stdout", io.StringIO()),
                patch.object(sys, "stderr", io.StringIO()),
            ):
                module.main()

            attempts = (config_dir / "attempts.jsonl").read_text(encoding="utf-8").splitlines()

        self.assertEqual(captured["authorization"], "Bearer file-key")
        self.assertEqual(captured["title"], "ask-intern")
        self.assertEqual(captured["payload"]["model"], "deepseek/deepseek-v4-flash")
        self.assertEqual(len(attempts), 2)
        self.assertIn('"event": "start"', attempts[0])
        self.assertIn('"event": "end"', attempts[1])
        self.assertIn('"status": "success"', attempts[1])

    def test_request_total_timeout_logs_timeout_and_attempt_end(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            config_dir = home / ".config" / "ask-intern"
            config_dir.mkdir(parents=True)
            (config_dir / "env").write_text(
                "export OPENROUTER_API_KEY=file-key\n",
                encoding="utf-8",
            )
            module = load_ask_intern(home)
            module.STATS_FILE = str(config_dir / "stats.tsv")
            module.EVENTS_FILE = str(config_dir / "events.tsv")
            module.ATTEMPTS_FILE = str(config_dir / "attempts.jsonl")

            def fake_request(*_args, **_kwargs):
                raise module.TotalTimeoutError("ask-intern exceeded 1s")

            stderr = io.StringIO()
            with (
                patch.dict(os.environ, {"HOME": str(home), "ASK_INTERN_SOURCE": "codex"}, clear=True),
                patch.object(module, "request_with_timeouts", fake_request),
                patch.object(sys, "argv", ["ask-intern", "summarize", "slow", "thing"]),
                patch.object(sys, "stdin", io.StringIO("")),
                patch.object(sys, "stdout", io.StringIO()),
                patch.object(sys, "stderr", stderr),
                self.assertRaises(SystemExit),
            ):
                module.main()

            events = (config_dir / "events.tsv").read_text(encoding="utf-8")
            attempts = (config_dir / "attempts.jsonl").read_text(encoding="utf-8")

        self.assertIn("timed out", stderr.getvalue())
        self.assertIn("\tcodex\tfailure\ttimeout\t", events)
        self.assertIn('"event": "start"', attempts)
        self.assertIn('"event": "end"', attempts)
        self.assertIn('"status": "failure"', attempts)
        self.assertIn('"reason": "timeout"', attempts)

    def test_high_risk_review_many_files_is_blocked_before_api_call(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            work = home / "repo"
            work.mkdir()
            files = []
            for index in range(8):
                path = work / f"part-{index}.ts"
                path.write_text("export const value = 1;\n", encoding="utf-8")
                files.extend(["-f", str(path)])
            config_dir = home / ".config" / "ask-intern"
            config_dir.mkdir(parents=True)
            (config_dir / "env").write_text("export OPENROUTER_API_KEY=file-key\n", encoding="utf-8")
            module = load_ask_intern(home)
            module.EVENTS_FILE = str(config_dir / "events.tsv")

            def fail_urlopen(*_args, **_kwargs):
                raise AssertionError("high-risk broad reviews should be denied before API calls")

            stderr = io.StringIO()
            with (
                patch.dict(os.environ, {"HOME": str(home), "ASK_INTERN_SOURCE": "codex"}, clear=True),
                patch.object(module, "urlopen", fail_urlopen),
                patch.object(sys, "argv", ["ask-intern", *files, "Deep-review this patch for correctness regressions"]),
                patch.object(sys, "stdin", io.StringIO("")),
                patch.object(sys, "stdout", io.StringIO()),
                patch.object(sys, "stderr", stderr),
                self.assertRaises(SystemExit),
            ):
                module.main()

            events = (config_dir / "events.tsv").read_text(encoding="utf-8")

        self.assertIn("split this into subsystem-sized reviews", stderr.getvalue())
        self.assertIn("\tcodex\tfailure\thigh_risk_review\t", events)

    def test_high_risk_review_large_stdin_is_blocked_but_override_allows_it(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            config_dir = home / ".config" / "ask-intern"
            config_dir.mkdir(parents=True)
            (config_dir / "env").write_text("export OPENROUTER_API_KEY=file-key\n", encoding="utf-8")
            module = load_ask_intern(home)
            module.EVENTS_FILE = str(config_dir / "events.tsv")
            module.STATS_FILE = str(config_dir / "stats.tsv")
            module.ATTEMPTS_FILE = str(config_dir / "attempts.jsonl")

            large_diff = "\n".join(f"+ changed line {index}" for index in range(5000))

            with (
                patch.dict(os.environ, {"HOME": str(home), "ASK_INTERN_SOURCE": "codex"}, clear=True),
                patch.object(
                    sys,
                    "argv",
                    ["ask-intern", "Review this uncommitted diff for likely correctness regressions"],
                ),
                patch.object(sys, "stdin", io.StringIO(large_diff)),
                patch.object(sys, "stdout", io.StringIO()),
                patch.object(sys, "stderr", io.StringIO()),
                self.assertRaises(SystemExit),
            ):
                module.main()

            captured = {}

            class FakeResponse:
                def __enter__(self):
                    return self

                def __exit__(self, exc_type, exc, tb):
                    return False

                def read(self):
                    return json.dumps(
                        {
                            "choices": [{"message": {"content": "ok"}}],
                            "usage": {"prompt_tokens": 10, "completion_tokens": 1},
                        }
                    ).encode("utf-8")

            def fake_urlopen(req, timeout):
                captured["payload"] = json.loads(req.data.decode("utf-8"))
                return FakeResponse()

            with (
                patch.dict(os.environ, {"HOME": str(home), "ASK_INTERN_SOURCE": "codex"}, clear=True),
                patch.object(module, "urlopen", fake_urlopen),
                patch.object(
                    sys,
                    "argv",
                    [
                        "ask-intern",
                        "--allow-broad-review",
                        "Review this uncommitted diff for likely correctness regressions",
                    ],
                ),
                patch.object(sys, "stdin", io.StringIO(large_diff)),
                patch.object(sys, "stdout", io.StringIO()),
                patch.object(sys, "stderr", io.StringIO()),
            ):
                module.main()

            events = (config_dir / "events.tsv").read_text(encoding="utf-8")

        self.assertIn("\tcodex\tfailure\thigh_risk_review\t", events)
        self.assertEqual(
            captured["payload"]["messages"][-1]["content"],
            "Review this uncommitted diff for likely correctness regressions",
        )

    def test_missing_temp_log_is_skipped_but_project_files_are_sent(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            work = home / "repo"
            work.mkdir()
            source_file = work / "source.py"
            source_file.write_text("def ok():\n    return True\n", encoding="utf-8")
            missing_log = Path(tmp) / "missing-dev.log"
            config_dir = home / ".config" / "ask-intern"
            config_dir.mkdir(parents=True)
            (config_dir / "env").write_text(
                "export OPENROUTER_API_KEY=file-key\n",
                encoding="utf-8",
            )
            module = load_ask_intern(home)
            module.STATS_FILE = str(config_dir / "stats.tsv")
            module.EVENTS_FILE = str(config_dir / "events.tsv")
            captured = {}

            class FakeResponse:
                def __enter__(self):
                    return self

                def __exit__(self, exc_type, exc, tb):
                    return False

                def read(self):
                    return json.dumps(
                        {
                            "choices": [{"message": {"content": "ok"}}],
                            "usage": {"prompt_tokens": 10, "completion_tokens": 1},
                        }
                    ).encode("utf-8")

            def fake_urlopen(req, timeout):
                captured["payload"] = json.loads(req.data.decode("utf-8"))
                return FakeResponse()

            stderr = io.StringIO()
            with (
                patch.dict(os.environ, {"HOME": str(home)}, clear=True),
                patch.object(module, "urlopen", fake_urlopen),
                patch.object(sys, "argv", ["ask-intern", "-f", str(missing_log), "-f", str(source_file), "summarize"]),
                patch.object(sys, "stdin", io.StringIO("")),
                patch.object(sys, "stdout", io.StringIO()),
                patch.object(sys, "stderr", stderr),
            ):
                module.main()

            context = captured["payload"]["messages"][1]["content"]
            events = (config_dir / "events.tsv").read_text(encoding="utf-8")

        self.assertIn(str(source_file), context)
        self.assertIn("def ok", context)
        self.assertIn(str(missing_log), context)
        self.assertIn("missing optional file", context)
        self.assertIn("Skipping missing optional file", stderr.getvalue())
        self.assertIn("\tsuccess\tok\t", events)

    def test_missing_file_logs_exact_invocation_for_debugging(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            config_dir = home / ".config" / "ask-intern"
            config_dir.mkdir(parents=True)
            (config_dir / "env").write_text(
                "export OPENROUTER_API_KEY=file-key\n",
                encoding="utf-8",
            )
            module = load_ask_intern(home)
            module.EVENTS_FILE = str(config_dir / "events.tsv")

            with (
                patch.dict(os.environ, {"HOME": str(home), "CODEX_SHELL": "1"}, clear=True),
                patch.object(sys, "argv", ["ask-intern", "-f", "missing.md", "secret prompt"]),
                patch.object(sys, "stdin", io.StringIO("")),
                patch.object(sys, "stdout", io.StringIO()),
                patch.object(sys, "stderr", io.StringIO()),
                self.assertRaises(SystemExit),
            ):
                module.main()

            events = (config_dir / "events.tsv").read_text(encoding="utf-8")

        self.assertIn("timestamp\tsource\tstatus\treason\tmodel", events)
        self.assertIn("\tcodex\tfailure\tmissing_file\t", events)
        self.assertIn("missing.md", events)
        self.assertIn("ask-intern -f missing.md 'secret prompt'", events)

    def test_exact_source_request_is_blocked_before_api_call(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            work = home / "repo"
            work.mkdir()
            source_file = work / "source.py"
            source_file.write_text("def ok():\n    return True\n", encoding="utf-8")
            config_dir = home / ".config" / "ask-intern"
            config_dir.mkdir(parents=True)
            module = load_ask_intern(home)
            module.EVENTS_FILE = str(config_dir / "events.tsv")

            def fail_urlopen(*_args, **_kwargs):
                raise AssertionError("exact-source requests should be denied before API calls")

            stderr = io.StringIO()
            with (
                patch.dict(os.environ, {"HOME": str(home), "ASK_INTERN_SOURCE": "codex"}, clear=True),
                patch.object(module, "urlopen", fail_urlopen),
                patch.object(
                    sys,
                    "argv",
                    [
                        "ask-intern",
                        "-f",
                        str(source_file),
                        "Show me the EXACT code with line numbers",
                    ],
                ),
                patch.object(sys, "stdin", io.StringIO("")),
                patch.object(sys, "stdout", io.StringIO()),
                patch.object(sys, "stderr", stderr),
                self.assertRaises(SystemExit),
            ):
                module.main()

            events = (config_dir / "events.tsv").read_text(encoding="utf-8")

        self.assertIn("Exact/verbatim source requests should use direct small reads", stderr.getvalue())
        self.assertIn("\tcodex\tfailure\texact_source_request\t", events)
        self.assertIn(str(source_file), events)
        self.assertIn("Show me the EXACT code with line numbers", events)

    def test_exact_source_guard_allows_negated_exact_code_instructions(self):
        with tempfile.TemporaryDirectory() as tmp:
            module = load_ask_intern(Path(tmp))

        allowed = [
            "Summarize the structure. Do not quote exact code.",
            "Don't reproduce exact code; just describe the relevant behavior.",
            "Do not include exact/verbatim code, full source, or line-numbered snippets.",
            "Summarize risks without asking for exact lines.",
            "No exact source text; point me to approximate ranges.",
            "Names only, not exact code.",
            "Do not quote exact code or full source; line numbers are not needed.",
            "Also note exact source-of-truth files/functions I should inspect next.",
            "Summarize all imports at the top and the test mock pattern. Identifiers and contract shapes only, no verbatim source.",
        ]
        denied = [
            "Show me the exact code with line numbers.",
            "Print the file.",
            "Quote exact lines 20-40.",
        ]

        for prompt in allowed:
            self.assertFalse(module.is_exact_source_request(prompt), prompt)
        for prompt in denied:
            self.assertTrue(module.is_exact_source_request(prompt), prompt)

    def test_exact_source_guard_can_be_overridden(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            work = home / "repo"
            work.mkdir()
            source_file = work / "source.py"
            source_file.write_text("def ok():\n    return True\n", encoding="utf-8")
            config_dir = home / ".config" / "ask-intern"
            config_dir.mkdir(parents=True)
            (config_dir / "env").write_text(
                "export OPENROUTER_API_KEY=file-key\n",
                encoding="utf-8",
            )
            module = load_ask_intern(home)
            module.STATS_FILE = str(config_dir / "stats.tsv")
            module.EVENTS_FILE = str(config_dir / "events.tsv")
            captured = {}

            class FakeResponse:
                def __enter__(self):
                    return self

                def __exit__(self, exc_type, exc, tb):
                    return False

                def read(self):
                    return json.dumps(
                        {
                            "choices": [{"message": {"content": "ok"}}],
                            "usage": {"prompt_tokens": 10, "completion_tokens": 1},
                        }
                    ).encode("utf-8")

            def fake_urlopen(req, timeout):
                captured["payload"] = json.loads(req.data.decode("utf-8"))
                return FakeResponse()

            with (
                patch.dict(os.environ, {"HOME": str(home)}, clear=True),
                patch.object(module, "urlopen", fake_urlopen),
                patch.object(
                    sys,
                    "argv",
                    [
                        "ask-intern",
                        "--allow-exact-source",
                        "-f",
                        str(source_file),
                        "Show me the EXACT code with line numbers",
                    ],
                ),
                patch.object(sys, "stdin", io.StringIO("")),
                patch.object(sys, "stdout", io.StringIO()),
                patch.object(sys, "stderr", io.StringIO()),
            ):
                module.main()

        self.assertEqual(captured["payload"]["messages"][-1]["content"], "Show me the EXACT code with line numbers")

    def test_existing_event_log_is_migrated_and_backfilled_to_include_source_column(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            module = load_ask_intern(home)
            config_dir = home / ".config" / "ask-intern"
            config_dir.mkdir(parents=True)
            module.EVENTS_FILE = str(config_dir / "events.tsv")
            (config_dir / "events.tsv").write_text(
                "\n".join(
                    [
                        "timestamp\tstatus\treason\tmodel\tfile_count\ttarget\tlatency_s\tcwd\tfiles\tinvocation",
                        "2026-05-03 19:00:00\tsuccess\tok\tdeepseek/deepseek-v4-flash\t1\t\t1.00\t/repo/.codex/worktrees/task\ta.md\task-intern -f a.md prompt",
                        "2026-05-03 19:00:01\tsuccess\tok\tdeepseek/deepseek-v4-flash\t1\t\t1.00\t/repo/.claude/worktrees/task\tb.md\task-intern -f b.md prompt",
                    ]
                )
                + "\n",
                encoding="utf-8",
            )

            with patch.dict(os.environ, {"HOME": str(home), "ASK_INTERN_SOURCE": "claude"}, clear=True):
                module.log_event("failure", "missing_file", model="test/model", files=["b.md"])

            events = (config_dir / "events.tsv").read_text(encoding="utf-8").splitlines()

        self.assertEqual(
            events[0],
            "timestamp\tsource\tstatus\treason\tmodel\tfile_count\ttarget\tlatency_s\tcwd\tfiles\tinvocation",
        )
        self.assertIn("2026-05-03 19:00:00\tcodex\tsuccess\tok\t", events[1])
        self.assertIn("2026-05-03 19:00:01\tclaude\tsuccess\tok\t", events[2])
        self.assertIn("\tclaude\tfailure\tmissing_file\ttest/model\t", events[3])

    def test_stats_reports_recent_failures(self):
        with tempfile.TemporaryDirectory() as tmp:
            home = Path(tmp)
            module = load_ask_intern(home)
            config_dir = home / ".config" / "ask-intern"
            config_dir.mkdir(parents=True)
            module.STATS_FILE = str(config_dir / "stats.tsv")
            module.EVENTS_FILE = str(config_dir / "events.tsv")
            now_date = datetime.now().strftime("%Y-%m-%d")
            (config_dir / "stats.tsv").write_text(
                "timestamp\tmodel\tin_tokens\tout_tokens\tcost_usd\topus_equivalent_usd\tlatency_s\n",
                encoding="utf-8",
            )
            (config_dir / "events.tsv").write_text(
                "\n".join(
                    [
                        "timestamp\tsource\tstatus\treason\tmodel\tfile_count\ttarget\tlatency_s\tcwd\tfiles\tinvocation",
                        f"{now_date} 19:00:00\tclaude\tfailure\tmissing_file\tdeepseek/deepseek-v4-flash\t1\t\t0.00\t/tmp\tmissing.md\task-intern -f missing.md prompt",
                        f"{now_date} 19:01:00\tcodex\tfailure\tapi_error\tdeepseek/deepseek-v4-flash\t2\t\t0.10\t/tmp\ta.md,b.md\task-intern -f a.md -f b.md prompt",
                        f"{now_date} 19:02:00\tunknown\tfailure\tmissing_file\tdeepseek/deepseek-v4-flash\t1\t\t0.00\t/tmp\tdefinitely-missing-intern-smoke.md\task-intern -f definitely-missing-intern-smoke.md",
                        f"{now_date} 19:03:00\tclaude\tfailure\tmissing_file\tdeepseek/deepseek-v4-flash\t2\t\t0.00\t/repo\t/private/tmp/stale.log,src/source.py\task-intern -f /private/tmp/stale.log -f src/source.py prompt",
                    ]
                )
                + "\n",
                encoding="utf-8",
            )

            output = io.StringIO()
            with patch.object(sys, "stdout", output):
                module.print_stats()

        self.assertIn("Recent failures: 2", output.getvalue())
        self.assertIn("missing_file: 1", output.getvalue())
        self.assertIn("api_error: 1", output.getvalue())
        self.assertIn("Sources:     claude 2, codex 1", output.getvalue())


if __name__ == "__main__":
    unittest.main()
