#!/usr/bin/env python3

import importlib.machinery
import importlib.util
import io
import json
import os
import sys
import tempfile
import unittest
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

        self.assertEqual(captured["authorization"], "Bearer file-key")
        self.assertEqual(captured["title"], "ask-intern")
        self.assertEqual(captured["payload"]["model"], "deepseek/deepseek-v4-flash")


if __name__ == "__main__":
    unittest.main()
