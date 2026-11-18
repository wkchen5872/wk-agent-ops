"""End-to-end hook tests with a local byte-proxy fixture, never a real daemon."""
import json
import os
import re
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import textwrap
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
SESSION = "12345678-abcd-abcd-abcd-123456789abc"
TURN = "87654321-abcd-abcd-abcd-123456789abc"

FAKE_CODEX = r'''
import base64,hashlib,json,os,socket
import websocket
from pathlib import Path
folder=Path(os.environ['FIXTURE_DIR'])
with (folder/'connections').open('a') as f:f.write(str(os.getpid())+'\n')
sock=socket.socket(fileno=os.dup(0))
headers=b''
while b'\r\n\r\n' not in headers:
    part=sock.recv(1)
    if not part:raise SystemExit(0)
    headers+=part
key=next(line.split(b':',1)[1].strip() for line in headers.split(b'\r\n') if line.lower().startswith(b'sec-websocket-key:'))
accept=base64.b64encode(hashlib.sha1(key+b'258EAFA5-E914-47DA-95CA-C5AB0DC85B11').digest())
sock.sendall(b'HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: '+accept+b'\r\n\r\n')
ws=websocket.WebSocket();ws.sock=sock;ws.connected=True
snapshots=json.loads((folder/'snapshots.json').read_text());index=-1
try:
 while True:
    message=json.loads(ws.recv())
    if 'id' not in message:continue
    method=message['method'];params=message.get('params',{})
    with (folder/'methods').open('a') as f:f.write(json.dumps({'method':method,'params':params})+'\n')
    if method=='initialize':result={'userAgent':'fixture'}
    elif method=='thread/read':
        index=min(index+1,len(snapshots)-1)
        result={'thread':{'id':params['threadId'],'status':snapshots[index]['status'],'cwd':'/tmp/project','turns':[]}}
    elif method=='thread/turns/list':
        if params.get('itemsView')!='notLoaded':
            ws.send_frame(websocket.ABNF(opcode=1,fin=1,mask_value=0,data=json.dumps({'id':message['id'],'error':{'code':-32602}}).encode()))
            continue
        result={'data':[{'id':snapshots[max(index,0)].get('turn_id',os.environ['FIXTURE_TURN']),'status':snapshots[max(index,0)].get('turn_status','inProgress'),'items':[]}],'nextCursor':None}
    else:raise RuntimeError('mutating or unexpected method')
    ws.send_frame(websocket.ABNF(opcode=websocket.ABNF.OPCODE_TEXT,fin=1,mask_value=0,data=json.dumps({'id':message['id'],'result':result}).encode()))
except (Exception,SystemExit):pass
'''


def snapshot(*flags, turn_status="inProgress", turn_id=TURN):
    return {"status": {"type": "active", "activeFlags": list(flags)},
            "turn_status": turn_status, "turn_id": turn_id}


class CodexWaitTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.home = Path(self.temp.name)
        self.notify = self.home / ".config/ai-notify"
        self.hooks = self.notify / "hooks"
        self.hooks.mkdir(parents=True)
        shutil.copytree(ROOT / "lib", self.notify / "lib")
        shutil.copy(ROOT / "telegram/hook.sh", self.hooks / "telegram-notify.sh")
        shutil.copy(ROOT / "telegram/events.tsv", self.hooks / "events.tsv")
        shutil.copytree(ROOT / "telegram/templates", self.hooks / "templates")
        runtime = self.notify / "runtime/codex-wait/bin"
        runtime.mkdir(parents=True)
        (runtime / "python3").symlink_to(sys.executable)
        worker = ROOT / "codex/wait.py"
        if worker.exists():
            shutil.copy(worker, self.hooks / "codex-wait.py")
        self.bin = self.home / "bin"
        self.bin.mkdir()
        self.executable("codex", FAKE_CODEX)
        self.executable("curl", """
            import json,os,sys
            from pathlib import Path
            text=next((a[5:] for a in sys.argv if a.startswith('text=')),'')
            with (Path(os.environ['FIXTURE_DIR'])/'messages').open('a') as f:f.write(json.dumps(text)+'\\n')
        """)
        self.config = self.notify / "config"
        self.settings()
        self.env = {k: v for k, v in os.environ.items()
                    if not k.startswith(("NOTIFY_", "TELEGRAM_", "CLAUDE_", "GITHUB_COPILOT_", "CODEX_HOME"))}
        self.env.update(HOME=str(self.home), CODEX_HOME=str(self.home / ".codex"),
                        PATH=str(self.bin) + os.pathsep + os.environ["PATH"],
                        FIXTURE_DIR=str(self.home), FIXTURE_TURN=TURN)
        self.addCleanup(self.cleanup)

    def executable(self, name, body):
        path = self.bin / name
        path.write_text("#!" + sys.executable + "\n" + textwrap.dedent(body))
        path.chmod(0o755)

    def settings(self, approval=False, questions=True, extra=""):
        self.config.write_text('TELEGRAM_ENABLED=true\nTELEGRAM_BOT_TOKEN="fixture-token"\nTELEGRAM_CHAT_ID=123\n'
                               f'NOTIFY_AUTHORIZATION={str(approval).lower()}\n'
                               f'NOTIFY_USER_INPUT={str(questions).lower()}\n' + extra)

    def cleanup(self):
        self.settings(questions=False)
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            states = self.state_files()
            if not any(isinstance(data := json.loads(p.read_text()), dict) and data.get("running") for p in states):
                break
            time.sleep(.1)
        self.temp.cleanup()

    def state_files(self):
        return [p for p in (self.notify / "state").glob("codex-*.json")
                if re.fullmatch(r"codex-[0-9a-f]{24}\.json", p.name)]

    def trigger(self, event="codex-question", session=SESSION, turn=TURN, transcript="/private/PRIVATE-TRANSCRIPT"):
        payload = {"hook_event_name": "PermissionRequest" if event == "codex-permission" else "PreToolUse",
                   "session_id": session, "turn_id": turn, "cwd": "/tmp/project", "tool_name": "Bash",
                   "tool_input": {"command": "PRIVATE-COMMAND --secret-arg", "questions": ["PRIVATE-QUESTION"]},
                   "transcript_path": transcript}
        before = time.monotonic()
        result = subprocess.run(["bash", str(self.hooks / "telegram-notify.sh"), event, "Codex"],
                                input=json.dumps(payload), text=True, capture_output=True,
                                env=self.env, timeout=3)
        self.assertLess(time.monotonic() - before, 2)
        self.assertEqual("{}", result.stdout.strip())
        self.assertEqual(0, result.returncode)

    def scenario(self, values):
        (self.home / "snapshots.json").write_text(json.dumps(values))

    def messages(self):
        path = self.home / "messages"
        return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []

    def wait_done(self, timeout=9):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            states = self.state_files()
            if states and all(not json.loads(p.read_text()).get("running") for p in states):
                return
            time.sleep(.05)
        self.fail("Hook did not start and finish the expected on-demand checker")

    def test_delayed_question_wait_reset_and_privacy(self):
        self.scenario([snapshot(), snapshot("waitingOnUserInput"), snapshot("waitingOnUserInput"),
                       snapshot(), snapshot("waitingOnUserInput"), snapshot(turn_status="completed")])
        self.trigger()
        self.wait_done()
        messages = self.messages()
        self.assertEqual(2, len(messages))
        self.assertTrue(all("Waiting for Your Response" in message for message in messages))
        artifacts = "".join(p.read_text() for p in (self.notify / "state").glob("*.json")) + "".join(messages)
        self.assertNotIn("PRIVATE-", artifacts)
        methods = [json.loads(line) for line in (self.home / "methods").read_text().splitlines()]
        self.assertEqual({"initialize", "thread/read", "thread/turns/list"}, {m["method"] for m in methods})
        self.assertTrue(all(m["params"].get("includeTurns") is False for m in methods if m["method"] == "thread/read"))
        self.assertTrue(all(m["params"].get("itemsView") == "notLoaded" for m in methods if m["method"] == "thread/turns/list"))

    def test_permission_hook_and_authorization_category(self):
        self.settings(approval=True, questions=False, extra="NOTIFY_AUTHORIZATION_DELAY_SECONDS=0\n")
        self.scenario([snapshot(), snapshot("waitingOnApproval"), snapshot(turn_status="completed")])
        self.trigger("codex-permission")
        self.wait_done()
        self.assertEqual(1, len(self.messages()))
        self.assertIn("Waiting for Your Approval", self.messages()[0])

    def test_repeated_hooks_share_one_worker(self):
        self.scenario([snapshot("waitingOnUserInput")] * 3 + [snapshot(turn_status="completed")])
        for _ in range(6):
            self.trigger()
        self.wait_done()
        self.assertEqual(1, len((self.home / "connections").read_text().splitlines()))
        self.assertEqual(1, len(self.messages()))

    def test_disabled_categories_never_connect(self):
        self.settings(questions=False)
        self.scenario([snapshot("waitingOnUserInput")])
        self.trigger()
        self.trigger("codex-question")
        self.assertFalse((self.home / "connections").exists())
        self.assertFalse((self.notify / "state").exists())

    def test_async_question_accepted_sends_once_without_daemon(self):
        payload = {"hook_event_name": "PostToolUse", "tool_name": "request_user_input_async",
                   "tool_response": '{"accepted":true}', "session_id": SESSION, "turn_id": TURN,
                   "cwd": "/tmp/project", "tool_input": {"questions": ["PRIVATE-QUESTION"]}}
        result = subprocess.run(["bash", str(self.hooks / "telegram-notify.sh"), "codex-async-question", "Codex"],
                                input=json.dumps(payload), text=True, capture_output=True, env=self.env, timeout=3)
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual("{}", result.stdout.strip())
        self.assertEqual(1, len(self.messages()))
        self.assertIn("Waiting for Your Response", self.messages()[0])
        self.assertNotIn("PRIVATE-", self.messages()[0])
        self.assertFalse((self.home / "connections").exists())
        self.assertFalse((self.notify / "state").exists())

    def test_async_question_pre_hook_does_not_start_checker(self):
        payload = {"hook_event_name": "PreToolUse", "tool_name": "request_user_input_async",
                   "session_id": SESSION, "turn_id": TURN, "cwd": "/tmp/project"}
        result = subprocess.run(["bash", str(self.hooks / "telegram-notify.sh"), "codex-question", "Codex"],
                                input=json.dumps(payload), text=True, capture_output=True, env=self.env, timeout=3)
        self.assertEqual("{}", result.stdout.strip())
        self.assertEqual(0, result.returncode)
        self.assertFalse((self.notify / "state").exists())
        self.assertEqual([], self.messages())

    def test_auto_review_without_wait_does_not_notify(self):
        self.scenario([snapshot(), snapshot(), snapshot(turn_status="completed")])
        self.trigger()
        self.wait_done()
        self.assertEqual([], self.messages())

    def test_changed_turn_does_not_notify_stale_wait(self):
        self.scenario([snapshot("waitingOnUserInput", turn_id="another-turn")])
        self.trigger()
        self.wait_done()
        self.assertEqual([], self.messages())

    def test_new_turn_hook_hands_off_an_existing_checker(self):
        self.scenario([snapshot(), snapshot("waitingOnUserInput", turn_id="next-turn"),
                       snapshot(turn_id="next-turn", turn_status="completed")])
        self.trigger()
        deadline = time.monotonic() + 3
        while time.monotonic() < deadline:
            methods = self.home / "methods"
            if methods.exists() and 'thread/turns/list' in methods.read_text():
                break
            time.sleep(.02)
        self.trigger(turn="next-turn")
        self.wait_done()
        self.assertEqual(1, len(self.messages()), "A new-turn hook must not be lost behind the old lock")

    def test_corrupt_state_does_not_prevent_next_check(self):
        import hashlib
        state = self.notify / "state"
        state.mkdir()
        identity = str((self.home / ".codex").resolve()) + "\0" + SESSION
        (state / ("codex-" + hashlib.sha256(identity.encode()).hexdigest()[:24] + ".json")).write_text('[]')
        self.scenario([snapshot("waitingOnUserInput"), snapshot(turn_status="completed")])
        self.trigger()
        deadline = time.monotonic() + 4
        while not self.messages() and time.monotonic() < deadline:
            time.sleep(.05)
        self.assertEqual(1, len(self.messages()))

    def test_transport_failure_is_bounded_and_sanitized(self):
        self.executable("codex", "import sys\nsys.stderr.write('PRIVATE-FAILURE')\nraise SystemExit(1)\n")
        self.trigger()
        self.wait_done()
        self.assertEqual([], self.messages())
        states = list((self.notify / "state").glob("codex-*.json"))
        self.assertTrue(states)
        self.assertTrue(all('PRIVATE-' not in p.read_text() for p in states))

    def test_sessions_are_independent(self):
        self.scenario([snapshot("waitingOnUserInput"), snapshot(turn_status="completed")])
        self.trigger()
        self.trigger(session="abcdefgh-abcd-abcd-abcd-123456789abc")
        self.wait_done()
        self.assertEqual(2, len(self.messages()))

    # ── Delayed authorization (notify-authorization-wait, Codex) ──────────────

    def authorization_settings(self, delay=2):
        self.settings(approval=True, questions=True, extra=f"NOTIFY_AUTHORIZATION_DELAY_SECONDS={delay}\n")

    def confirmed(self):
        return [m for m in self.messages() if "Waiting for Your Approval" in m]

    def unconfirmed(self):
        return [m for m in self.messages() if "may be waiting for approval, but this could not be confirmed" in m]

    def record_path(self):
        return self.home / ".codex/sessions/2026/11/18" / f"rollout-2026-11-18T00-00-00-{SESSION}.jsonl"

    def record(self, *entries):
        path = self.record_path()
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("a") as stream:
            for entry in entries:
                stream.write(json.dumps(entry) + "\n")
        return path

    @staticmethod
    def call(call_id):
        return {"type": "response_item", "payload": {"type": "function_call", "name": "exec_command",
                                                      "call_id": call_id,
                                                      "arguments": '{"cmd":"PRIVATE-COMMAND --secret-arg"}'}}

    @staticmethod
    def output(call_id):
        return {"type": "response_item", "payload": {"type": "function_call_output", "call_id": call_id,
                                                      "output": "PRIVATE-OUTPUT"}}

    def offline(self):
        self.executable("codex", "raise SystemExit(1)\n")

    def test_automatic_review_within_the_delay_is_silent(self):
        self.authorization_settings(delay=3)
        self.scenario([snapshot(), snapshot("waitingOnApproval"), snapshot("waitingOnApproval")]
                      + [snapshot()] * 5 + [snapshot(turn_status="completed")])
        self.trigger("codex-permission")
        self.wait_done(timeout=15)
        self.assertEqual([], self.messages(), "a long-running approved command must not notify")

    def test_approval_waiting_past_the_delay_notifies_once(self):
        self.authorization_settings(delay=2)
        self.scenario([snapshot("waitingOnApproval")] * 5 + [snapshot(turn_status="completed")])
        self.trigger("codex-permission")
        self.wait_done(timeout=12)
        self.assertEqual(1, len(self.messages()))
        self.assertEqual(1, len(self.confirmed()))
        self.assertIn("Bash", self.confirmed()[0])
        self.assertNotIn("PRIVATE-", self.confirmed()[0])
        self.assertNotIn("--secret-arg", self.confirmed()[0])

    def test_approval_cleared_then_raised_again_notifies_twice(self):
        self.authorization_settings(delay=2)
        self.scenario([snapshot("waitingOnApproval")] * 4 + [snapshot()]
                      + [snapshot("waitingOnApproval")] * 4 + [snapshot(turn_status="completed")])
        self.trigger("codex-permission")
        self.wait_done(timeout=15)
        self.assertEqual(2, len(self.confirmed()))

    def test_offline_real_wait_is_unconfirmed(self):
        self.authorization_settings(delay=2)
        self.offline()
        path = self.record(self.call("call_A"))
        self.trigger("codex-permission", transcript=str(path))
        self.wait_done(timeout=12)
        self.assertEqual(1, len(self.messages()))
        self.assertEqual(1, len(self.unconfirmed()))
        self.assertEqual([], self.confirmed())
        self.assertNotIn("PRIVATE-", self.messages()[0])

    def test_offline_approved_command_still_running_is_unconfirmed(self):
        self.authorization_settings(delay=2)
        self.offline()
        running = {"type": "event_msg", "payload": {"type": "token_count"}}
        path = self.record(self.call("call_A"), running, running)
        self.trigger("codex-permission", transcript=str(path))
        self.wait_done(timeout=12)
        self.assertEqual(1, len(self.unconfirmed()))
        self.assertEqual([], self.confirmed())

    def test_offline_unreadable_record_is_unconfirmed(self):
        self.authorization_settings(delay=2)
        self.offline()
        self.trigger("codex-permission", transcript=str(self.home / "missing.jsonl"))
        self.wait_done(timeout=12)
        self.assertEqual(1, len(self.unconfirmed()))
        self.assertEqual([], self.confirmed())

    def test_offline_result_within_the_delay_is_silent(self):
        self.authorization_settings(delay=3)
        self.offline()
        path = self.record(self.call("call_A"))
        self.trigger("codex-permission", transcript=str(path))
        time.sleep(.5)
        self.record(self.output("call_A"))
        self.wait_done(timeout=12)
        self.assertEqual([], self.messages())

    def test_offline_record_found_by_session_when_the_path_is_missing(self):
        self.authorization_settings(delay=3)
        self.offline()
        self.record(self.call("call_A"))
        self.trigger("codex-permission", transcript=str(self.home / "missing.jsonl"))
        time.sleep(.5)
        self.record({"type": "event_msg", "payload": {"type": "task_complete"}})
        self.wait_done(timeout=12)
        self.assertEqual([], self.messages(), "the end of the turn resolves the request")

    def test_offline_later_request_of_the_same_turn_has_its_own_delay(self):
        self.authorization_settings(delay=2)
        self.offline()
        path = self.record(self.call("call_A"))
        self.trigger("codex-permission", transcript=str(path))
        time.sleep(.5)
        self.record(self.output("call_A"))
        time.sleep(.6)
        self.record(self.call("call_B"))
        self.trigger("codex-permission", transcript=str(path))
        self.wait_done(timeout=15)
        self.assertEqual(1, len(self.unconfirmed()), "A resolved in time; B is reported once")

    # A CLI-started Codex session is never loaded in the daemon (task 1.2 live capture).
    NOT_LOADED = {"status": {"type": "notLoaded"}}

    def test_session_not_loaded_with_a_pending_request_is_unconfirmed(self):
        self.authorization_settings(delay=2)
        self.scenario([self.NOT_LOADED])
        path = self.record(self.call("call_A"))
        self.trigger("codex-permission", transcript=str(path))
        self.wait_done(timeout=12)
        self.assertEqual(1, len(self.unconfirmed()))
        self.assertEqual([], self.confirmed())

    def test_session_not_loaded_with_a_result_within_the_delay_is_silent(self):
        self.authorization_settings(delay=3)
        self.scenario([self.NOT_LOADED])
        path = self.record(self.call("call_A"))
        self.trigger("codex-permission", transcript=str(path))
        time.sleep(.5)
        self.record(self.output("call_A"))
        self.wait_done(timeout=12)
        self.assertEqual([], self.messages(), "automatic review that settles in time stays silent")

    def test_session_unloaded_after_it_was_active_ends_the_turn(self):
        self.authorization_settings(delay=2)
        self.scenario([snapshot(), self.NOT_LOADED])
        path = self.record(self.call("call_A"))
        self.trigger("codex-permission", transcript=str(path))
        self.wait_done(timeout=12)
        self.assertEqual([], self.messages())

    # Review codex-01a1ee38-r02/F-01: a repeated signal for the same open call is the same wait.
    def test_offline_repeat_before_the_first_notice_sends_one(self):
        self.authorization_settings(delay=2)
        self.offline()
        path = self.record(self.call("call_A"))
        self.trigger("codex-permission", transcript=str(path))
        time.sleep(.4)
        self.trigger("codex-permission", transcript=str(path))
        self.wait_done(timeout=12)
        time.sleep(.5)
        self.wait_done(timeout=12)
        self.assertEqual(1, len(self.unconfirmed()))

    def assert_repeat_after_the_checker_ends_sends_one(self):
        path = self.record(self.call("call_A"))
        self.trigger("codex-permission", transcript=str(path))
        self.wait_done(timeout=12)
        self.assertEqual(1, len(self.unconfirmed()))
        self.trigger("codex-permission", transcript=str(path))
        time.sleep(.5)
        self.wait_done(timeout=12)
        self.assertEqual(1, len(self.unconfirmed()), "the same open call was already reported")
        self.record(self.output("call_A"), self.call("call_B"))
        self.trigger("codex-permission", transcript=str(path))
        time.sleep(.5)
        self.wait_done(timeout=12)
        self.assertEqual(2, len(self.unconfirmed()), "the next call has its own notice")

    def test_offline_repeat_after_the_checker_ends_sends_one(self):
        self.authorization_settings(delay=1)
        self.offline()
        self.assert_repeat_after_the_checker_ends_sends_one()

    def test_not_loaded_repeat_after_the_checker_ends_sends_one(self):
        self.authorization_settings(delay=1)
        self.scenario([self.NOT_LOADED])
        self.assert_repeat_after_the_checker_ends_sends_one()

    # Review codex-01a1ee38-r03/F-01: a record that becomes readable only identifies the same wait.
    def test_offline_record_readable_again_is_still_the_same_wait(self):
        self.authorization_settings(delay=1)
        self.offline()
        path = self.record(self.call("call_A"))
        path.chmod(0o000)
        try:
            self.trigger("codex-permission", transcript=str(path))
            self.wait_done(timeout=12)
            self.assertEqual(1, len(self.unconfirmed()))
            state = json.loads(self.state_files()[0].read_text())
            self.assertIsNone((state.get("offline_reported") or {}).get("call", "missing"),
                              "the notice was sent before the call could be identified")
        finally:
            path.chmod(0o600)
        self.trigger("codex-permission", transcript=str(path))
        time.sleep(.5)
        self.wait_done(timeout=12)
        self.assertEqual(1, len(self.unconfirmed()), "readable again is not a new wait")
        self.record(self.output("call_A"), self.call("call_B"))
        self.trigger("codex-permission", transcript=str(path))
        time.sleep(.5)
        self.wait_done(timeout=12)
        self.assertEqual(2, len(self.unconfirmed()), "a real next call is still reported")

    # Review codex-01a1ee38-r04/F-01: readability alone is never evidence about the wait.
    def settle(self, path):
        self.trigger("codex-permission", transcript=str(path))
        time.sleep(.5)
        self.wait_done(timeout=12)

    def test_offline_readable_then_unreadable_same_call_sends_one(self):
        self.authorization_settings(delay=1)
        self.offline()
        path = self.record(self.call("call_A"))
        self.settle(path)
        self.assertEqual(1, len(self.unconfirmed()))
        path.chmod(0o000)
        try:
            self.settle(path)
        finally:
            path.chmod(0o600)
        self.assertEqual(1, len(self.unconfirmed()), "an unreadable record is not a new wait")

    def test_offline_unreadable_notice_then_result_and_new_call_reports_the_new_call(self):
        self.authorization_settings(delay=1)
        self.offline()
        path = self.record(self.call("call_A"))
        path.chmod(0o000)
        try:
            self.settle(path)
        finally:
            path.chmod(0o600)
        self.assertEqual(1, len(self.unconfirmed()))
        self.record(self.output("call_A"), self.call("call_B"))
        self.settle(path)
        self.assertEqual(2, len(self.unconfirmed()), "call_B came after the notice and gets its own")

    def test_offline_unreadable_notice_then_observed_resolution_then_new_call(self):
        self.authorization_settings(delay=1)
        self.offline()
        path = self.record(self.call("call_A"))
        path.chmod(0o000)
        try:
            self.settle(path)
        finally:
            path.chmod(0o600)
        self.record(self.output("call_A"))
        self.settle(path)
        self.assertEqual(1, len(self.unconfirmed()), "a resolution sends nothing")
        self.record(self.call("call_B"))
        self.settle(path)
        self.assertEqual(2, len(self.unconfirmed()), "after a resolution the next call is a new wait")

    # Review codex-01a1ee38-r05: a distinct new call is a new wait even while the reported one is open.
    def test_offline_new_call_while_the_reported_call_is_still_open_is_reported(self):
        self.authorization_settings(delay=1)
        self.offline()
        path = self.record(self.call("call_A"))
        self.settle(path)
        self.assertEqual(1, len(self.unconfirmed()))
        self.record(self.call("call_B"))  # call_A still has no output
        self.settle(path)
        self.assertEqual(2, len(self.unconfirmed()))

    # Review codex-01a1ee38-r05/F-01: a notice not attempted while disabled must not be reserved.
    def test_offline_wait_skipped_while_disabled_notifies_after_reenabling(self):
        self.authorization_settings(delay=2)
        self.offline()
        path = self.record(self.call("call_A"))
        self.trigger("codex-permission", transcript=str(path))
        time.sleep(.4)
        self.settings(approval=False, questions=True, extra="NOTIFY_AUTHORIZATION_DELAY_SECONDS=2\n")
        self.wait_done(timeout=12)
        self.assertEqual([], self.messages())
        self.authorization_settings(delay=1)
        self.settle(path)
        self.assertEqual(1, len(self.unconfirmed()), "the first real attempt is still owed")

    def test_offline_question_only_sends_nothing(self):
        self.authorization_settings(delay=1)
        self.offline()
        self.record(self.call("call_A"))
        self.trigger("codex-question", transcript=str(self.record_path()))
        self.wait_done(timeout=12)
        self.assertEqual([], self.messages())

    def test_starting_an_inspection_prunes_only_stale_unlocked_owned_state(self):
        import fcntl
        state = self.notify / "state"
        state.mkdir()
        old = time.time() - 10 * 86400
        recent = time.time() - 86400

        def files(names, moment):
            paths = [state / name for name in names]
            for path in paths:
                path.write_text("{}")
                os.utime(path, (moment, moment))
            return paths
        stale = files([f"codex-{'a' * 24}.{s}" for s in ("lock", "json", "request.json")], old)
        held = files([f"codex-{'b' * 24}.{s}" for s in ("lock", "json", "request.json")], old)
        fresh = files([f"codex-{'c' * 24}.{s}" for s in ("lock", "json", "request.json")], recent)
        unrelated = files(["other-notifier.json", "codex-not-ours.json"], old)
        stale_marker = files(["claude-old-session.pending"], old)
        live_marker = files(["antigravity-live.pending"], old)
        lock_dir = state / "antigravity-live.pending.lock"
        lock_dir.mkdir()
        (lock_dir / "pid").write_text(str(os.getpid()))
        holder = os.open(held[0], os.O_RDWR)
        fcntl.flock(holder, fcntl.LOCK_EX | fcntl.LOCK_NB)
        try:
            self.scenario([snapshot(turn_status="completed")])
            self.trigger()
            self.wait_done()
        finally:
            os.close(holder)
        self.assertEqual([False] * 4, [p.exists() for p in stale + stale_marker])
        self.assertTrue(all(p.exists() for p in held + fresh + unrelated + live_marker))

    def test_fake_proxy_fixture_supports_real_websocket_handshake(self):
        import socket
        import websocket
        self.scenario([snapshot()])
        client, peer = socket.socketpair()
        proxy = subprocess.Popen([str(self.bin / "codex"), "app-server", "proxy"],
                                 stdin=peer, stdout=peer, stderr=subprocess.PIPE, env=self.env)
        peer.close()
        try:
            ws = websocket.create_connection("ws://localhost/", socket=client,
                                             suppress_origin=True, timeout=2)
            ws.send(json.dumps({"id": 1, "method": "initialize", "params": {}}))
            self.assertIn("result", json.loads(ws.recv()))
            ws.close()
        finally:
            client.close()
            proxy.terminate()
            proxy.communicate(timeout=2)

    def test_status_probe_does_not_claim_live_acceptance(self):
        self.scenario([snapshot()])
        result = subprocess.run(["bash", str(ROOT / "telegram/update.sh"), "status"],
                                text=True, capture_output=True, env=self.env, timeout=5)
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertIn("daemon：唯讀連線可用", result.stdout)
        self.assertIn("本機端到端驗收：尚未記錄", result.stdout)
        self.assertIn("按需啟動", result.stdout)
        # Since task 1.2: authorization falls back to the session record, not "no inference".
        self.assertIn("查不到時改讀 Session 紀錄", result.stdout)
        self.assertIn("Approval Status Unknown", result.stdout)
        self.assertNotIn("授權與同步問題需本機 daemon", result.stdout)
        self.assertNotIn("fixture-token", result.stdout + result.stderr)


class CodexCheckerClockTests(unittest.TestCase):
    """Drives the real run_checker with a virtual clock (review codex-01a1ee38-r05)."""

    def test_an_old_timer_never_settles_a_later_request_early(self):
        import importlib.util
        import os as _os
        from unittest.mock import patch
        spec = importlib.util.spec_from_file_location("wait_under_test", ROOT / "codex/wait.py")
        wait = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(wait)
        clock, sent = [100.0], []
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            record = root / "record.jsonl"
            state = root / "state.json"
            call = lambda i: {"type": "response_item", "payload": {"type": "function_call", "call_id": i}}
            output = lambda i: {"type": "response_item", "payload": {"type": "function_call_output", "call_id": i}}
            record.write_text(json.dumps(call("call_A")) + "\n")
            record.chmod(0o000)
            a = {"session_id": "test-session", "turn_id": "test-turn", "cwd": "/tmp/project", "kind": "permission",
                 "requested_at": 100.0, "transcript_path": str(record)}
            request_file = state.with_suffix(".request.json")
            request_file.write_text(json.dumps(wait.persisted(a)))

            def tick(seconds):
                clock[0] += seconds
                if clock[0] == 101.0:  # A gets its result and a new request B is raised
                    record.chmod(0o600)
                    with record.open("a") as stream:
                        for entry in (output("call_A"), call("call_B")):
                            stream.write(json.dumps(entry) + "\n")
                    request_file.write_text(json.dumps(wait.persisted({**a, "requested_at": 101.0})))

            def unavailable():
                raise wait.InspectionError("daemon-unavailable")
            lock = _os.open(root / "lock", _os.O_CREAT | _os.O_RDWR, 0o600)
            config = {"TELEGRAM_ENABLED": True, "authorization": True, "user_input": True, "delay": 3}
            try:
                with patch.object(wait, "notify_root", return_value=root), \
                        patch.object(wait, "settings", return_value=config), \
                        patch.object(wait, "Daemon", side_effect=unavailable), \
                        patch.object(wait.time, "time", side_effect=lambda: clock[0]), \
                        patch.object(wait.time, "sleep", side_effect=tick), \
                        patch.object(wait, "send", side_effect=lambda r, e, t: sent.append((clock[0], e))):
                    wait.run_checker(a, state, lock)
            finally:
                record.chmod(0o600)
        self.assertEqual([(104.0, "codex-authorization-unconfirmed")], sent,
                         "B is reported at its own deadline (104), not by A's timer (103)")


if __name__ == "__main__":
    unittest.main()
