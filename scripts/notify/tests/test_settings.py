"""Notification category and grouped-menu acceptance tests; never use real HOME."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
HOOK = ROOT / "telegram/hook.sh"
UPDATE = ROOT / "telegram/update.sh"


class SettingsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.config = self.home / ".config/ai-notify/config"
        self.config.parent.mkdir(parents=True)
        self.base = 'TELEGRAM_ENABLED=true\nTELEGRAM_BOT_TOKEN="secret-for-fixture"\nTELEGRAM_CHAT_ID="123"\nNOTIFY_LEVEL=all\nOTHER_SETTING="keep-me"\n'
        self.config.write_text(self.base)
        self.env = {k: v for k, v in os.environ.items()
                    if not k.startswith(("NOTIFY_", "TELEGRAM_", "CLAUDE_", "GITHUB_COPILOT_"))}
        self.env.update(HOME=str(self.home), TELEGRAM_DRY_RUN="true")

    def hook(self, event, settings="", payload=None, **env):
        self.config.write_text(self.base + settings)
        return subprocess.run(["bash", str(HOOK), event, "Codex"],
                              input=json.dumps(payload or {}), text=True, capture_output=True,
                              env={**self.env, **env}, timeout=5)

    def test_shared_switches_control_their_categories(self):
        cases = [("codex-stop", "NOTIFY_COMPLETION", {}),
                 ("codex-permission", "NOTIFY_ACTION_REQUIRED", {"tool_name": "Bash"}),
                 ("antigravity-stop", "NOTIFY_FAILURE", {"fullyIdle": True, "terminationReason": "error"})]
        for event, key, payload in cases:
            with self.subTest(key=key):
                self.assertEqual("", self.hook(event, f"{key}=false\n", payload).stdout)
                self.assertTrue(self.hook(event, f"{key}=true\n", payload).stdout)

    def test_new_categories_default_off_and_are_independent(self):
        for event, key, title in [
            ("codex-human-approval", "NOTIFY_CODEX_HUMAN_APPROVAL", "等待你授權"),
            ("codex-user-input", "NOTIFY_CODEX_USER_INPUT", "Waiting for Your Response"),
        ]:
            with self.subTest(event=event):
                self.assertEqual("", self.hook(event).stdout)
                output = self.hook(event, f"NOTIFY_ACTION_REQUIRED=false\n{key}=true\n",
                                   {"session_id": "12345678-abcd-abcd-abcd-123456789abc",
                                    "cwd": "/tmp/project", "tool_input": {"command": "PRIVATE-COMMAND"}}).stdout
                self.assertIn(title, output)
                self.assertIn("#12345678", output)
                self.assertNotIn("PRIVATE-COMMAND", output)

    def test_explicit_environment_overrides_config(self):
        result = self.hook("codex-stop", "NOTIFY_COMPLETION=false\n", NOTIFY_COMPLETION="true")
        self.assertIn("Task Complete", result.stdout)

    def test_async_question_success_notifies_without_a_wait_flag(self):
        payload = {"hook_event_name": "PostToolUse", "tool_name": "request_user_input_async",
                   "tool_input": {"questions": [{"title": "PRIVATE-QUESTION"}]},
                   "session_id": "12345678-abcd-abcd-abcd-123456789abc", "cwd": "/tmp/project"}
        for response in [{"accepted": True}, '{"accepted":true}']:
            with self.subTest(response=response):
                result = self.hook("codex-async-question",
                                   "NOTIFY_ACTION_REQUIRED=false\nNOTIFY_CODEX_USER_INPUT=true\n",
                                   {**payload, "tool_response": response})
                self.assertEqual(0, result.returncode, result.stderr)
                self.assertIn("Waiting for Your Response", result.stdout)
                self.assertIn("Codex has a question awaiting your response.", result.stdout)
                self.assertIn("#AsyncUserInputRequested", result.stdout)
                self.assertNotIn("PRIVATE-", result.stdout)
                self.assertFalse((self.config.parent / "state").exists())

    def test_async_question_rejects_unaccepted_results_and_disabled_category(self):
        payload = {"hook_event_name": "PostToolUse", "tool_name": "request_user_input_async"}
        settings = "NOTIFY_CODEX_USER_INPUT=true\n"
        for response in [None, {}, {"accepted": False}, {"accepted": "true"}, "invalid", "{}", []]:
            with self.subTest(response=response):
                result = self.hook("codex-async-question", settings, {**payload, "tool_response": response})
                self.assertEqual("", result.stdout)
                self.assertEqual(0, result.returncode)
        for extra in [{"tool_name": "another_tool"}, {"hook_event_name": "PreToolUse"}]:
            self.assertEqual("", self.hook("codex-async-question", settings,
                                           {**payload, "tool_response": {"accepted": True}, **extra}).stdout)
        result = self.hook("codex-async-question", "NOTIFY_CODEX_USER_INPUT=false\n",
                           {**payload, "tool_response": {"accepted": True}}, TELEGRAM_DRY_RUN="false")
        self.assertEqual("{}", result.stdout.strip())
        self.assertEqual(0, result.returncode)

    def update(self, text, key="types"):
        return subprocess.run(["bash", str(UPDATE), key], input=text, text=True,
                              capture_output=True, env=self.env, timeout=10)

    def test_grouped_menu_cancel_and_eof_leave_bytes_unchanged(self):
        for text in ["2\nq\n", "2\n", "h\nq\n", "s\nn\nq\n"]:
            with self.subTest(text=text):
                result = self.update(text)
                self.assertEqual(self.base, self.config.read_text())
                self.assertIn("Codex 專用", result.stdout)
                self.assertNotIn("secret-for-fixture", result.stdout + result.stderr)

    def test_grouped_menu_save_and_permissions(self):
        result = self.update("2\ns\ny\n")
        self.assertEqual(0, result.returncode, result.stderr)
        config = self.config.read_text()
        self.assertIn("NOTIFY_ACTION_REQUIRED=false", config.replace('"', ""))
        self.assertIn('OTHER_SETTING="keep-me"', config)
        self.assertIn('TELEGRAM_BOT_TOKEN="secret-for-fixture"', config)
        self.assertIn("NOTIFY_CODEX_HUMAN_APPROVAL=false", config.replace('"', ""))
        self.assertEqual(0o600, self.config.stat().st_mode & 0o777)
        self.assertIn("儲存摘要", result.stdout)
        self.assertNotIn("NOTIFY_CODEX_PERMISSION_REQUEST", config)

    def test_legacy_level_command_changes_shared_only(self):
        self.config.write_text(self.base + 'NOTIFY_COMPLETION=false\nNOTIFY_CODEX_USER_INPUT=true\n')
        result = self.update("all\n", "notify_level")
        self.assertEqual(0, result.returncode, result.stderr)
        config = self.config.read_text().replace('"', "")
        self.assertIn("NOTIFY_COMPLETION=true", config)
        self.assertIn("NOTIFY_CODEX_USER_INPUT=true", config)

    def test_repair_deploys_helpers_without_launch_service(self):
        deployed = self.home / ".config/ai-notify/hooks/telegram-notify.sh"
        deployed.parent.mkdir(parents=True)
        deployed.touch()
        result = self.update("", "fix-hooks")
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertTrue((deployed.parent / "codex-wait.py").is_file())
        self.assertTrue((self.config.parent / "lib/config.sh").is_file())
        self.assertFalse((self.home / "Library/LaunchAgents").exists())
        self.assertFalse((self.config.parent / "runtime").exists())

    def test_codex_question_registration_preserves_other_hooks(self):
        codex = self.home / ".codex/hooks.json"
        codex.parent.mkdir(parents=True)
        unrelated = [{"matcher": "Bash", "hooks": [{"type": "command", "command": "unrelated"}]}]
        codex.write_text(json.dumps({"other": True, "hooks": {"PreToolUse": unrelated,
                                                               "PostToolUse": unrelated}}))
        registry = os.environ.get("NOTIFY_REGISTRY_TEST_PATH", str(ROOT / "lib/registry.sh"))
        command = 'source "$1"; register_hook_codex "$2"; register_hook_codex "$2"'
        result = subprocess.run(["bash", "-c", command, "_", registry, "/tmp/telegram-notify.sh"],
                                env=self.env, capture_output=True, text=True)
        self.assertEqual(0, result.returncode, result.stderr)
        data = json.loads(codex.read_text())
        questions = [group for group in data["hooks"]["PreToolUse"]
                     if any("codex-question" in hook["command"] for hook in group["hooks"])]
        self.assertEqual(1, len(questions))
        self.assertEqual("^(request_user_input|request_user_input_async)$", questions[0]["matcher"])
        async_questions = [group for group in data["hooks"]["PostToolUse"]
                           if any("codex-async-question" in hook["command"] for hook in group["hooks"])]
        self.assertEqual(1, len(async_questions))
        self.assertEqual("^request_user_input_async$", async_questions[0]["matcher"])
        subprocess.run(["bash", "-c", 'source "$1"; unregister_hook_codex "$2"', "_", registry,
                        "/tmp/telegram-notify.sh"], env=self.env, check=True, capture_output=True)
        remaining = json.loads(codex.read_text())["hooks"]
        self.assertEqual(unrelated, remaining["PreToolUse"])
        self.assertEqual(unrelated, remaining["PostToolUse"])

    def test_fresh_setup_uses_grouped_menu(self):
        self.config.unlink()
        binary = self.home / "bin"
        binary.mkdir()
        curl = binary / "curl"
        curl.write_text('#!/bin/sh\necho \'{"ok":true,"result":[{"message":{"chat":{"id":123}}}]}\'\n')
        curl.chmod(0o755)
        result = subprocess.run(["bash", str(ROOT / "telegram/install.sh")],
                                input="fixture-token\n\n2\ns\ny\nn\n", text=True, capture_output=True,
                                env={**self.env, "PATH": str(binary) + os.pathsep + self.env["PATH"]}, timeout=10)
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertIn("Codex 專用", result.stdout)
        self.assertIn("NOTIFY_ACTION_REQUIRED=false", self.config.read_text().replace('"', ""))

    def test_uninstall_cleans_owned_runtime_state_only(self):
        deployed = self.home / ".config/ai-notify/hooks/telegram-notify.sh"
        deployed.parent.mkdir(parents=True)
        deployed.touch()
        self.update("", "fix-hooks")
        state = self.config.parent / "state"
        state.mkdir()
        owned = state / ("codex-" + "a" * 24 + ".json")
        owned.write_text('{"running":false}')
        unrelated = state / "other-notifier.json"
        unrelated.write_text('keep')
        result = subprocess.run(["bash", str(ROOT / "telegram/uninstall.sh")], input="y\nn\n",
                                text=True, capture_output=True, env=self.env, timeout=15)
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertFalse(owned.exists())
        self.assertTrue(unrelated.exists())
        self.assertFalse((deployed.parent / "codex-wait.py").exists())

    def test_dependency_failure_keeps_legacy_notifications_available(self):
        binary = self.home / "bin"
        binary.mkdir()
        python = binary / "python3"
        python.write_text('#!/bin/sh\nexit 1\n')
        python.chmod(0o755)
        self.env["PATH"] = str(binary) + os.pathsep + self.env["PATH"]
        result = self.update("4\ns\ny\n")
        self.assertEqual(0, result.returncode)
        self.assertIn("無法建立專用 Python 環境", result.stderr)
        legacy = subprocess.run(["bash", str(self.config.parent / "hooks/telegram-notify.sh"),
                                 "codex-permission", "Codex"], input='{"tool_name":"Bash"}',
                                text=True, capture_output=True, env=self.env, timeout=3)
        self.assertIn("Action Required", legacy.stdout)

    def test_atomic_update_preserves_literal_shell_characters(self):
        value = 'literal $HOME `uname` $(uname) | slash\\quote"'
        command = 'source "$1"; update_config_key EXTRA_SETTING "$2"; source "$AI_NOTIFY_CONFIG"; printf "%s" "$EXTRA_SETTING"'
        result = subprocess.run(["bash", "-c", command, "_", str(ROOT / "lib/config.sh"), value],
                                env=self.env, capture_output=True, text=True)
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual(value, result.stdout)


if __name__ == "__main__":
    unittest.main()
