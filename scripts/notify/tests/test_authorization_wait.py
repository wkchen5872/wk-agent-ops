"""Delayed authorization confirmation for Claude Code and Antigravity (notify-authorization-wait).

Every test runs the deployed layout in a temporary HOME with a fake curl that logs each
message and its arrival time. Delays are shortened to a few seconds.

A notice arrives some time after its check is due (hook start, the check itself, the
Python fake curl), and later still under load. So the tests never require a notice by a
fixed moment: they wait for it with `until`, and they decide "restarted or not" from the
wait marker, which load cannot change. Only "nothing yet" checks use fixed moments,
because lateness can only help them.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import textwrap
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
SESSION = "abcdef12-3456-7890-abcd-ef1234567890"
CONFIRMED = "等待你授權"
UNCONFIRMED = "可能在等待授權，無法確認"


class HookFixture(unittest.TestCase):
    delay = "2"

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.home = Path(self.temp.name)
        root = self.home / ".config/ai-notify"
        (root / "hooks").mkdir(parents=True)
        shutil.copytree(ROOT / "lib", root / "lib")
        shutil.copy(ROOT / "telegram/hook.sh", root / "hooks/telegram-notify.sh")
        shutil.copy(ROOT / "telegram/events.tsv", root / "hooks/events.tsv")
        shutil.copytree(ROOT / "telegram/templates", root / "hooks/templates")
        self.hook_path = root / "hooks/telegram-notify.sh"
        self.state = root / "state"
        (root / "config").write_text('TELEGRAM_ENABLED=true\nTELEGRAM_BOT_TOKEN="fixture-token"\n'
                                     'TELEGRAM_CHAT_ID=123\n')
        binary = self.home / "bin"
        binary.mkdir()
        curl = binary / "curl"
        curl.write_text("#!" + sys.executable + "\n" + textwrap.dedent("""
            import json,os,sys,time
            text=next((a[5:] for a in sys.argv if a.startswith('text=')),'')
            with open(os.path.join(os.environ['HOME'],'messages'),'a') as f:
                f.write(json.dumps({'t':time.time(),'text':text})+'\\n')
        """))
        curl.chmod(0o755)
        self.env = {k: v for k, v in os.environ.items()
                    if not k.startswith(("NOTIFY_", "TELEGRAM_", "CLAUDE_", "GITHUB_COPILOT_"))}
        self.env.update(HOME=str(self.home), PATH=str(binary) + os.pathsep + os.environ["PATH"],
                        NOTIFY_AUTHORIZATION_DELAY_SECONDS=self.delay)
        self.start = time.time()
        self.addCleanup(self.cleanup)

    def cleanup(self):
        # Background checks are children of the deployed hook path; stop any still sleeping.
        subprocess.run(["pkill", "-f", str(self.hook_path)], capture_output=True)
        time.sleep(.1)
        self.temp.cleanup()

    def hook(self, event, tool, payload, quick=True, **env):
        before = time.monotonic()
        result = subprocess.run(["bash", str(self.hook_path), event, tool], input=json.dumps(payload),
                                text=True, capture_output=True, env={**self.env, **env}, timeout=15)
        if quick:
            self.assertLess(time.monotonic() - before, 1.5, "hook must return without waiting")
        self.assertEqual(0, result.returncode, result.stderr)
        return result.stdout

    def at(self, seconds):
        """Sleep until `seconds` after the test started."""
        remaining = self.start + seconds - time.time()
        if remaining > 0:
            time.sleep(remaining)

    def messages(self, containing=""):
        path = self.home / "messages"
        if not path.exists():
            return []
        entries = [json.loads(line) for line in path.read_text().splitlines()]
        return [(round(e["t"] - self.start, 2), e["text"]) for e in entries if containing in e["text"]]

    def authorization(self, label=""):
        return [m for m in self.messages(label) if CONFIRMED in m[1] or UNCONFIRMED in m[1]]

    def until(self, count, seconds, label=""):
        """Wait until `count` notices arrived, or until `seconds` after the test started."""
        while len(self.authorization(label)) < count and time.time() < self.start + seconds:
            time.sleep(.05)
        return self.authorization(label)

    @staticmethod
    def field(marker, key):
        return next((line.split("=", 1)[1] for line in marker.splitlines() if line.startswith(key + "=")), "")


class ClaudeCodeTests(HookFixture):
    def setUp(self):
        super().setUp()
        self.transcript = self.home / "transcript.jsonl"
        self.transcript.write_text('{"type":"user","message":{"role":"user","content":"PRIVATE-PROMPT"}}\n')

    def request(self, call_id, command="PRIVATE-COMMAND --secret-arg"):
        entry = {"type": "assistant", "message": {"role": "assistant", "content": [
            {"type": "tool_use", "id": call_id, "name": "Bash", "input": {"command": command}}]}}
        with self.transcript.open("a") as stream:
            stream.write(json.dumps(entry, separators=(",", ":")) + "\n")

    def answer(self, call_id):
        entry = {"type": "user", "message": {"role": "user", "content": [
            {"type": "tool_result", "tool_use_id": call_id, "content": "PRIVATE-OUTPUT"}]}}
        with self.transcript.open("a") as stream:
            stream.write(json.dumps(entry, separators=(",", ":")) + "\n")

    def prompt(self, transcript=None, **env):
        payload = {"hook_event_name": "Notification", "notification_type": "permission_prompt",
                   "message": "Claude needs your permission to use Bash", "session_id": SESSION,
                   "transcript_path": str(transcript or self.transcript), "cwd": "/tmp/claude-project"}
        self.assertEqual("", self.hook("notification", "Claude Code", payload, **env))

    def stop(self):
        self.hook("stop", "Claude Code", {"hook_event_name": "Stop", "session_id": SESSION,
                                          "transcript_path": str(self.transcript), "cwd": "/tmp/claude-project"})

    def marker(self):
        files = list(self.state.glob("claude-*.pending")) if self.state.exists() else []
        return files[0].read_text() if files else ""

    def test_waiting_request_notifies_once_after_the_delay(self):
        self.request("toolu_A")
        self.prompt()
        self.at(1.5)
        self.assertEqual([], self.authorization(), "nothing may be sent before the delay")
        sent = self.until(1, 6)
        self.assertEqual(1, len(sent))
        self.assertGreaterEqual(sent[0][0], 1.9)
        text = sent[0][1]
        self.assertIn(CONFIRMED, text)
        self.assertNotIn(UNCONFIRMED, text)
        self.assertIn("Claude Code", text)
        self.assertIn("claude-project", text)
        self.assertIn("#abcdef12", text)
        self.assertIn("Bash", text)
        for private in ("PRIVATE-COMMAND", "--secret-arg", "PRIVATE-PROMPT", "transcript.jsonl"):
            self.assertNotIn(private, text)

    def test_request_answered_within_the_delay_is_silent(self):
        self.request("toolu_A")
        self.prompt()
        self.at(.5)
        self.answer("toolu_A")
        self.at(3.6)
        self.assertEqual([], self.authorization())
        self.assertEqual("", self.marker(), "a resolved wait is cleared")

    def test_unreadable_record_sends_the_unconfirmed_notice(self):
        self.prompt(transcript=self.home / "missing.jsonl")
        sent = self.until(1, 6)
        self.assertEqual(1, len(sent))
        self.assertIn(UNCONFIRMED, sent[0][1])
        self.assertNotIn(CONFIRMED, sent[0][1])

    def test_same_request_signalled_again_keeps_its_start(self):
        self.request("toolu_A")
        self.prompt()
        first = self.marker()
        self.at(1.2)
        self.prompt()
        self.assertEqual(first, self.marker(), "a repeat keeps the identity and the start time")
        self.assertEqual(1, len(self.until(1, 6)))
        self.at(self.until(1, 6)[0][0] + 1.5)
        self.assertEqual(1, len(self.authorization()), "a repeat must not cause a second notice")

    def test_answered_then_stopped_then_asked_again_notifies_again(self):
        self.request("toolu_A")
        self.prompt()
        self.assertEqual(1, len(self.until(1, 6)))
        self.answer("toolu_A")
        self.stop()
        self.assertEqual("", self.marker(), "the end of the turn clears the notified wait")
        self.request("toolu_B")
        self.prompt()
        self.assertEqual(2, len(self.until(2, time.time() - self.start + 6)))

    def test_notified_answered_then_a_new_request_has_its_own_delay(self):
        self.request("toolu_A")
        self.prompt()
        self.assertEqual(1, len(self.until(1, 6)))
        self.answer("toolu_A")
        self.request("toolu_B")
        second = time.time() - self.start
        self.prompt()
        self.at(second + 1.5)
        self.assertEqual(1, len(self.authorization()), "the second wait needs its own delay")
        sent = self.until(2, second + 6)
        self.assertEqual(2, len(sent))
        self.assertGreaterEqual(sent[1][0], second + 1.9)

    def test_second_wait_before_the_first_timer_ends(self):
        self.env["NOTIFY_AUTHORIZATION_DELAY_SECONDS"] = "3"
        self.request("toolu_A")
        self.prompt()
        self.at(.5)
        self.answer("toolu_A")
        self.at(1)
        self.request("toolu_B")
        self.prompt()
        self.at(3.6)  # the first check has run; the second is not due before about 4 s
        self.assertEqual([], self.authorization(), "the first check must not send for the second wait")
        self.assertEqual("toolu_B", self.field(self.marker(), "id"), "the first check must not clear the second wait")
        self.assertEqual("0", self.field(self.marker(), "notified"), "the first check must not act on it")
        sent = self.until(1, 9)
        self.assertEqual(1, len(sent))
        self.assertGreaterEqual(sent[0][0], 3.9)

    def test_delay_zero_sends_at_once(self):
        self.request("toolu_A")
        self.prompt(NOTIFY_AUTHORIZATION_DELAY_SECONDS="0")
        self.assertEqual(1, len(self.authorization()))

    def test_invalid_delay_uses_the_default(self):
        for value in ("abc", "-5"):
            with self.subTest(value=value):
                self.request("toolu_" + value.strip("-"))
                self.prompt(NOTIFY_AUTHORIZATION_DELAY_SECONDS=value)
        self.at(2.5)
        self.assertEqual([], self.authorization())

    def test_disabled_category_starts_no_check(self):
        self.request("toolu_A")
        self.prompt(NOTIFY_AUTHORIZATION="false")
        self.at(2.6)
        self.assertEqual([], self.authorization())
        self.assertEqual("", self.marker())

    def test_held_lock_keeps_a_new_wait_safe_from_the_old_check(self):
        self.request("toolu_A")
        self.prompt()
        self.answer("toolu_A")
        lock = next(self.state.glob("claude-*.pending")).with_suffix(".pending.lock")
        lock.mkdir()
        (lock / "pid").write_text(str(os.getpid()))
        self.at(1)
        self.request("toolu_B")
        signal = subprocess.Popen(["bash", str(self.hook_path), "notification", "Claude Code"],
                                  stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                  env=self.env, text=True)
        signal.stdin.write(json.dumps({"hook_event_name": "Notification", "notification_type": "permission_prompt",
                                       "session_id": SESSION, "transcript_path": str(self.transcript),
                                       "cwd": "/tmp/claude-project"}))
        signal.stdin.close()
        self.at(2.4)  # the first check is now waiting for the lock as well
        shutil.rmtree(lock)
        released = time.time() - self.start
        signal.wait(timeout=5)
        self.at(released + 1.5)  # the new wait is not due before its own delay
        self.assertEqual([], self.authorization(), "the old check must not send for the new wait")
        self.assertEqual("toolu_B", self.field(self.marker(), "id"))
        self.assertEqual("0", self.field(self.marker(), "notified"))
        sent = self.until(1, released + 7)
        self.assertEqual(1, len(sent))
        self.assertGreaterEqual(sent[0][0], released + 1.9)


class AntigravityTests(HookFixture):
    def status(self, pending, conversation="agy-conversation", **env):
        payload = {"conversation_id": conversation, "agent_state": "tool_use" if pending else "idle",
                   "tool_confirmation_pending": pending, "cwd": "/tmp/agy-project", "email": "private@example.com"}
        output = self.hook("antigravity-statusline", "Antigravity CLI", payload, **env)
        self.assertEqual("tool_use" if pending else "idle", output.strip(), "status line output is unchanged")

    def marker(self, conversation="agy-conversation"):
        path = self.state / f"antigravity-{conversation}.pending"
        return path.read_text() if path.exists() else ""

    def signals(self, every, until, start=0.0, **env):
        moment = start
        while moment <= until:
            self.at(moment)
            self.status(True, **env)
            moment += every

    def test_continued_wait_notifies_at_the_delay(self):
        self.status(True)
        first = self.marker()
        self.at(1.5)
        self.status(True)
        self.assertEqual(first, self.marker(), "a repeated true keeps the identity and the start time")
        sent = self.until(1, 6)
        self.assertEqual(1, len(sent))
        self.assertIn(CONFIRMED, sent[0][1])
        self.assertNotIn("private@example.com", sent[0][1])

    def test_confirmation_cleared_within_the_delay_is_silent(self):
        self.status(True)
        self.at(.5)
        self.status(False)
        self.at(2.8)
        self.assertEqual([], self.authorization())
        self.assertEqual("", self.marker())

    def test_true_after_false_is_a_new_wait(self):
        self.status(True)
        first = self.field(self.marker(), "id")
        self.at(.5)
        self.status(False)
        self.at(1)
        self.status(True)
        self.assertNotEqual(first, self.field(self.marker(), "id"), "true after false starts a new wait")
        self.at(2.6)
        self.assertEqual([], self.authorization())
        self.assertEqual(1, len(self.until(1, 7)))

    def test_answered_confirmation_omits_the_field_and_clears_the_wait(self):
        # Antigravity 1.5.10 never sends false: once answered, the field is simply absent (task 1.3).
        self.status(True)
        self.assertNotEqual("", self.marker())
        self.at(.5)
        answered = {"conversation_id": "agy-conversation", "session_id": "agy-conversation",
                    "agent_state": "working", "cwd": "/tmp/agy-project"}
        self.assertEqual("working", self.hook("antigravity-statusline", "Antigravity CLI", answered).strip())
        self.assertEqual("", self.marker())
        self.at(2.8)
        self.assertEqual([], self.authorization())

    def test_conversation_stop_clears_the_wait(self):
        self.status(True)
        self.at(.5)
        self.hook("antigravity-stop", "Antigravity CLI",
                  {"terminationReason": "NO_TOOL_CALL", "fullyIdle": True, "conversationId": "agy-conversation",
                   "workspacePaths": ["/tmp/agy-project"]})
        self.assertEqual("", self.marker())
        self.at(2.8)
        self.assertEqual([], self.authorization())

    def test_disabled_telegram_still_clears_the_wait(self):
        self.status(True)
        self.assertNotEqual("", self.marker())
        self.status(False, TELEGRAM_ENABLED="false")
        self.assertEqual("", self.marker())

    def test_repeating_signals_send_exactly_one_notice(self):
        self.status(True)
        first = self.field(self.marker(), "id")
        self.signals(every=.5, until=5, start=.5)
        self.assertEqual(first, self.field(self.marker(), "id"), "repeats never start a new wait")
        self.at(5.5)
        sent = self.authorization()
        self.assertEqual(1, len(sent))
        self.assertLess(sent[0][0], 5, "repeats every 0.5 s must not postpone the notice")

    def test_rearm_counts_from_the_notice(self):
        self.env.update(NOTIFY_AUTHORIZATION_DELAY_SECONDS="1", NOTIFY_AUTHORIZATION_REARM_SECONDS="4")
        self.status(True)
        sent = self.until(1, 5)
        self.assertEqual(1, len(sent))
        first = self.field(self.marker(), "id")
        notified = int(self.field(self.marker(), "notified"))
        # The marker keeps whole seconds; re-arming is never early and at most one second late.
        time.sleep(max(0, notified + 3 - time.time()))
        self.status(True)  # short of the re-arm interval: merged
        self.assertEqual(first, self.field(self.marker(), "id"))
        time.sleep(max(0, notified + 6 - time.time()))
        self.status(True)  # past the interval: a new wait with its own delay
        self.assertNotEqual(first, self.field(self.marker(), "id"))
        self.assertEqual(1, len(self.authorization()), "the new wait has its own delay")
        self.assertEqual(2, len(self.until(2, time.time() - self.start + 5)))

    def test_first_notice_arrives_at_the_delay_whatever_the_rearm_interval(self):
        # Each configuration uses its own conversation, so earlier runs cannot interfere.
        # Signals continue past the delay; a starving design would send nothing until they stop.
        for delay, rearm in (("2", "1"), ("2", "2"), ("3", "2")):
            with self.subTest(delay=delay, rearm=rearm):
                conversation = f"agy-d{delay}-r{rearm}"
                self.start = time.time()
                self.signals(every=.6, until=float(delay) + 2.4, conversation=conversation,
                             NOTIFY_AUTHORIZATION_DELAY_SECONDS=delay, NOTIFY_AUTHORIZATION_REARM_SECONDS=rearm)
                sent = self.authorization(conversation)
                self.assertTrue(sent, "the first notice must arrive while signals keep coming")
                self.assertGreaterEqual(sent[0][0], float(delay) - .1)

    def test_resolution_evidence_rearms_at_once(self):
        self.status(True)
        self.assertEqual(1, len(self.until(1, 6)))
        self.status(False)
        time.sleep(.5)
        second = time.time() - self.start
        self.status(True)
        self.at(second + 1.5)
        self.assertEqual(1, len(self.authorization()), "the new wait has its own delay")
        sent = self.until(2, second + 6)
        self.assertEqual(2, len(sent))
        self.assertGreaterEqual(sent[1][0], second + 1.9)

    def test_invalid_rearm_interval_uses_the_default(self):
        for value in ("abc", "-5"):
            with self.subTest(value=value):
                conversation = f"agy-rearm{value}"
                self.start = time.time()
                env = {"NOTIFY_AUTHORIZATION_DELAY_SECONDS": "1", "NOTIFY_AUTHORIZATION_REARM_SECONDS": value}
                self.status(True, conversation=conversation, **env)
                self.assertEqual(1, len(self.until(1, 5, conversation)))
                first = self.field(self.marker(conversation), "id")
                time.sleep(2.2)  # past any interval of 0-1 s
                self.status(True, conversation=conversation, **env)
                self.assertEqual(first, self.field(self.marker(conversation), "id"),
                                 "an invalid interval must not re-arm at once")


if __name__ == "__main__":
    unittest.main()
