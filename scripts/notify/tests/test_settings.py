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
                 ("codex-human-approval", "NOTIFY_AUTHORIZATION", {}),
                 ("codex-user-input", "NOTIFY_USER_INPUT", {}),
                 ("antigravity-stop", "NOTIFY_FAILURE", {"fullyIdle": True, "terminationReason": "error"})]
        for event, key, payload in cases:
            with self.subTest(key=key):
                self.assertEqual("", self.hook(event, f"{key}=false\n", payload).stdout)
                self.assertTrue(self.hook(event, f"{key}=true\n", payload).stdout)

    def test_codex_waits_follow_the_shared_categories(self):
        for event, key, title in [
            ("codex-human-approval", "NOTIFY_AUTHORIZATION", "Waiting for Your Approval"),
            ("codex-user-input", "NOTIFY_USER_INPUT", "Waiting for Your Response"),
        ]:
            with self.subTest(event=event):
                self.assertIn(title, self.hook(event).stdout, "nothing defined means enabled")
                self.assertEqual("", self.hook(event, "NOTIFY_ACTION_REQUIRED=false\n").stdout)
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
                                   "NOTIFY_ACTION_REQUIRED=false\nNOTIFY_USER_INPUT=true\n",
                                   {**payload, "tool_response": response})
                self.assertEqual(0, result.returncode, result.stderr)
                self.assertIn("Waiting for Your Response", result.stdout)
                self.assertIn("Codex has a question awaiting your response.", result.stdout)
                self.assertIn("#AsyncUserInputRequested", result.stdout)
                self.assertNotIn("PRIVATE-", result.stdout)
                self.assertFalse((self.config.parent / "state").exists())

    def test_async_question_rejects_unaccepted_results_and_disabled_category(self):
        payload = {"hook_event_name": "PostToolUse", "tool_name": "request_user_input_async"}
        settings = "NOTIFY_USER_INPUT=true\n"
        for response in [None, {}, {"accepted": False}, {"accepted": "true"}, "invalid", "{}", []]:
            with self.subTest(response=response):
                result = self.hook("codex-async-question", settings, {**payload, "tool_response": response})
                self.assertEqual("", result.stdout)
                self.assertEqual(0, result.returncode)
        for extra in [{"tool_name": "another_tool"}, {"hook_event_name": "PreToolUse"}]:
            self.assertEqual("", self.hook("codex-async-question", settings,
                                           {**payload, "tool_response": {"accepted": True}, **extra}).stdout)
        result = self.hook("codex-async-question", "NOTIFY_USER_INPUT=false\n",
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
                self.assertIn("授權要求", result.stdout)
                self.assertNotIn("既有操作提醒", result.stdout)
                self.assertNotIn("secret-for-fixture", result.stdout + result.stderr)

    def test_grouped_menu_save_and_permissions(self):
        self.config.write_text(self.base + "NOTIFY_USER_INPUT=false\n")
        result = self.update("2\ns\ny\n")
        self.assertEqual(0, result.returncode, result.stderr)
        config = self.config.read_text().replace('"', "")
        for line in ["NOTIFY_COMPLETION=true", "NOTIFY_AUTHORIZATION=false",
                     "NOTIFY_USER_INPUT=false", "NOTIFY_FAILURE=true"]:
            self.assertIn(line, config)
        self.assertIn('OTHER_SETTING="keep-me"', self.config.read_text())
        self.assertIn('TELEGRAM_BOT_TOKEN="secret-for-fixture"', self.config.read_text())
        self.assertEqual(0o600, self.config.stat().st_mode & 0o777)
        self.assertIn("儲存摘要", result.stdout)

    def test_menu_names_four_categories_and_the_delay(self):
        result = self.update("q\n")
        for name in ["工作結束", "授權要求", "等待回應", "異常停止"]:
            self.assertIn(name, result.stdout)
        self.assertNotIn("既有操作提醒", result.stdout)
        self.assertIn("仍在等待", result.stdout)
        self.assertIn("30 秒", result.stdout)

    def test_first_save_migrates_legacy_keys(self):
        legacy = ("NOTIFY_ACTION_REQUIRED=true\nNOTIFY_CODEX_HUMAN_APPROVAL=false\n"
                  "NOTIFY_CODEX_USER_INPUT=true\n")
        self.config.write_text(self.base + legacy)
        self.config.chmod(0o644)
        result = self.update("s\ny\n")
        self.assertEqual(0, result.returncode, result.stderr)
        lines = self.config.read_text().replace('"', "").splitlines()
        self.assertIn("NOTIFY_AUTHORIZATION=true", lines)
        self.assertIn("NOTIFY_USER_INPUT=true", lines)
        for key in ["NOTIFY_ACTION_REQUIRED", "NOTIFY_CODEX_HUMAN_APPROVAL", "NOTIFY_CODEX_USER_INPUT"]:
            self.assertFalse(any(line.startswith(key + "=") for line in lines), key)
        for line in self.base.splitlines():
            if not line.startswith("NOTIFY_LEVEL="):
                self.assertIn(line, self.config.read_text().splitlines())
        self.assertIn("NOTIFY_LEVEL=all", lines)
        self.assertEqual(0o600, self.config.stat().st_mode & 0o777)

    def test_legacy_level_command_changes_shared_only(self):
        self.config.write_text(self.base + 'NOTIFY_COMPLETION=false\nNOTIFY_CODEX_USER_INPUT=true\n')
        result = self.update("all\n", "notify_level")
        self.assertEqual(0, result.returncode, result.stderr)
        config = self.config.read_text().replace('"', "")
        self.assertIn("NOTIFY_COMPLETION=true", config)
        self.assertIn("NOTIFY_CODEX_USER_INPUT=true", config)

    def test_level_change_keeps_other_switches(self):
        before = self.base + "NOTIFY_AUTHORIZATION=false\nNOTIFY_USER_INPUT=false\nNOTIFY_FAILURE=false\n"
        self.config.write_text(before)
        result = self.update("attention_required\n", "notify_level")
        self.assertEqual(0, result.returncode, result.stderr)
        lines = self.config.read_text().replace('"', "").splitlines()
        for line in ["NOTIFY_AUTHORIZATION=false", "NOTIFY_USER_INPUT=false", "NOTIFY_FAILURE=false",
                     "NOTIFY_LEVEL=attention_required", "NOTIFY_COMPLETION=false"]:
            self.assertIn(line, lines)
        self.assertFalse(any(line.startswith("NOTIFY_ACTION_REQUIRED=") for line in lines))

    def test_repair_deploys_helpers_without_launch_service(self):
        self.config.write_text(self.base + "NOTIFY_AUTHORIZATION=false\nNOTIFY_USER_INPUT=false\n")
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
                                input="fixture-token\n\n2\n3\ns\ny\nn\n", text=True, capture_output=True,
                                env={**self.env, "PATH": str(binary) + os.pathsep + self.env["PATH"]}, timeout=10)
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertIn("授權要求", result.stdout)
        config = self.config.read_text().replace('"', "")
        self.assertIn("NOTIFY_AUTHORIZATION=false", config)
        self.assertIn("NOTIFY_USER_INPUT=false", config)

    def test_uninstall_cleans_owned_runtime_state_only(self):
        self.config.write_text(self.base + "NOTIFY_AUTHORIZATION=false\nNOTIFY_USER_INPUT=false\n")
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
        self.config.write_text(self.base + "NOTIFY_AUTHORIZATION=false\nNOTIFY_USER_INPUT=false\n")
        result = self.update("2\ns\ny\n")
        self.assertEqual(0, result.returncode)
        self.assertIn("無法建立專用 Python 環境", result.stderr)
        legacy = subprocess.run(["bash", str(self.config.parent / "hooks/telegram-notify.sh"),
                                 "codex-stop", "Codex"], input='{"cwd":"/tmp/project"}',
                                text=True, capture_output=True, env=self.env, timeout=3)
        self.assertIn("Task Complete", legacy.stdout)

    def test_atomic_update_preserves_literal_shell_characters(self):
        value = 'literal $HOME `uname` $(uname) | slash\\quote"'
        command = 'source "$1"; update_config_key EXTRA_SETTING "$2"; source "$AI_NOTIFY_CONFIG"; printf "%s" "$EXTRA_SETTING"'
        result = subprocess.run(["bash", "-c", command, "_", str(ROOT / "lib/config.sh"), value],
                                env=self.env, capture_output=True, text=True)
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual(value, result.stdout)


if __name__ == "__main__":
    unittest.main()
