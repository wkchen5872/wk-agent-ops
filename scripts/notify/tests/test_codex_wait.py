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

    def settings(self, approval=False, questions=True, legacy=False):
        self.config.write_text('TELEGRAM_ENABLED=true\nTELEGRAM_BOT_TOKEN="fixture-token"\nTELEGRAM_CHAT_ID=123\n'
                               f'NOTIFY_ACTION_REQUIRED={str(legacy).lower()}\n'
                               f'NOTIFY_CODEX_HUMAN_APPROVAL={str(approval).lower()}\n'
                               f'NOTIFY_CODEX_USER_INPUT={str(questions).lower()}\n')

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

    def trigger(self, event="codex-permission", session=SESSION, turn=TURN):
        payload = {"hook_event_name": "PermissionRequest" if event == "codex-permission" else "PreToolUse",
                   "session_id": session, "turn_id": turn, "cwd": "/tmp/project", "tool_name": "Bash",
                   "tool_input": {"command": "PRIVATE-COMMAND", "questions": ["PRIVATE-QUESTION"]},
                   "transcript_path": "/private/PRIVATE-TRANSCRIPT"}
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

    def test_question_hook_and_human_approval_category(self):
        self.settings(approval=True, questions=False)
        self.scenario([snapshot(), snapshot("waitingOnApproval"), snapshot(turn_status="completed")])
        self.trigger("codex-question")
        self.wait_done()
        self.assertEqual(1, len(self.messages()))
        self.assertIn("等待你授權", self.messages()[0])

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
        self.assertNotIn("fixture-token", result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
