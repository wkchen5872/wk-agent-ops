#!/usr/bin/env python3
"""Hook-triggered, metadata-only observation of an existing Codex daemon."""
import argparse
import fcntl
import hashlib
import json
import os
import re
from pathlib import Path
import shlex
import shutil
import socket
import subprocess
import sys
import tempfile
import time


FLAGS = {
    "waitingOnApproval": ("NOTIFY_CODEX_HUMAN_APPROVAL", "codex-human-approval", "HumanApprovalWaiting"),
    "waitingOnUserInput": ("NOTIFY_CODEX_USER_INPUT", "codex-user-input", "UserInputWaiting"),
}
RPC_TIMEOUT = 2
POLL_INTERVAL = 1
MAX_FAILURES = 3


class InspectionError(Exception):
    """Only stable, credential-free codes leave the transport layer."""


def notify_root():
    return Path.home() / ".config/ai-notify"


def settings():
    keys = {"TELEGRAM_ENABLED", *(entry[0] for entry in FLAGS.values())}
    result = dict.fromkeys(keys, False)
    try:
        for line in (notify_root() / "config").read_text().splitlines():
            key, separator, value = line.partition("=")
            if separator and key in keys:
                tokens = shlex.split(value, comments=True)
                result[key] = tokens == ["true"]
    except (OSError, ValueError):
        return dict.fromkeys(keys, False)
    for key in keys:
        if key in os.environ:
            result[key] = os.environ[key] == "true"
    return result


def inspection_enabled(config):
    return config["TELEGRAM_ENABLED"] and any(config[entry[0]] for entry in FLAGS.values())


def shutdown_marker():
    return notify_root() / "state/codex-disabled"


def read_json(path, default):
    try:
        value = json.loads(path.read_text())
        return value if isinstance(value, type(default)) else default
    except (OSError, ValueError):
        return default


def atomic_json(path, value):
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(dir=path.parent, prefix=path.name + ".")
    try:
        with os.fdopen(fd, "w") as stream:
            json.dump(value, stream)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def state_paths(session_id):
    codex_home = os.environ.get("CODEX_HOME", str(Path.home() / ".codex"))
    key = hashlib.sha256((str(Path(codex_home).resolve()) + "\0" + session_id).encode()).hexdigest()[:24]
    folder = notify_root() / "state"
    return folder / f"codex-{key}.lock", folder / f"codex-{key}.json"


def sanitized_trigger(payload):
    trigger = {key: payload.get(key) for key in ("session_id", "turn_id", "cwd")}
    if not all(isinstance(trigger[key], str) and 0 < len(trigger[key]) <= 128
               for key in ("session_id", "turn_id")):
        raise InspectionError("missing-session-or-turn")
    if not isinstance(trigger["cwd"], str) or len(trigger["cwd"]) > 4096:
        trigger["cwd"] = ""
    return trigger


class Daemon:
    """Public byte proxy discovers the control socket; no socket-path guesses."""
    def __init__(self):
        try:
            import websocket
        except ImportError:
            raise InspectionError("dependency-unavailable") from None
        binary = shutil.which("codex")
        if not binary:
            raise InspectionError("codex-unavailable")
        self.sequence = 0
        self.ws = None
        self.proxy = None
        client, peer = socket.socketpair()
        try:
            self.proxy = subprocess.Popen([binary, "app-server", "proxy"], stdin=peer, stdout=peer,
                                          stderr=subprocess.DEVNULL)
            peer.close()
            self.ws = websocket.create_connection("ws://localhost/", socket=client,
                                                   suppress_origin=True, timeout=RPC_TIMEOUT)
            self.rpc("initialize", {"clientInfo": {"name": "ai_notify_wait_checker", "version": "1.0"}})
            self.ws.send(json.dumps({"method": "initialized"}))
        except Exception:
            client.close()
            peer.close()
            self.close()
            raise InspectionError("daemon-unavailable") from None

    def rpc(self, method, params):
        if method not in {"initialize", "thread/read", "thread/turns/list"}:
            raise InspectionError("unsupported-operation")
        self.sequence += 1
        request_id = self.sequence
        deadline = time.monotonic() + RPC_TIMEOUT
        self.ws.send(json.dumps({"id": request_id, "method": method, "params": params}))
        while time.monotonic() < deadline:
            self.ws.settimeout(max(.01, deadline - time.monotonic()))
            message = json.loads(self.ws.recv())
            if message.get("id") == request_id and "method" not in message:
                if "error" in message or not isinstance(message.get("result"), dict):
                    raise InspectionError("unsupported-protocol")
                return message["result"]
        raise InspectionError("daemon-timeout")

    def snapshot(self, session_id):
        thread = self.rpc("thread/read", {"threadId": session_id, "includeTurns": False}).get("thread")
        if not isinstance(thread, dict) or thread.get("id") != session_id:
            raise InspectionError("unsupported-protocol")
        status = thread.get("status", {})
        if not isinstance(status, dict) or status.get("type") not in {"active", "idle", "notLoaded", "systemError"}:
            raise InspectionError("unsupported-protocol")
        if status["type"] != "active":
            return status, None
        if not isinstance(status.get("activeFlags"), list):
            raise InspectionError("unsupported-protocol")
        turns = self.rpc("thread/turns/list", {"threadId": session_id, "limit": 1,
                                              "sortDirection": "desc", "itemsView": "notLoaded"}).get("data")
        if not isinstance(turns, list) or not turns or not isinstance(turns[0], dict):
            raise InspectionError("unsupported-protocol")
        return status, {"id": turns[0].get("id"), "status": turns[0].get("status")}

    def close(self):
        if self.ws:
            try:
                self.ws.shutdown()
            except OSError:
                pass
        if self.proxy:
            if self.proxy.poll() is None:
                self.proxy.terminate()
            try:
                self.proxy.wait(timeout=1)
            except subprocess.TimeoutExpired:
                self.proxy.kill()
                self.proxy.wait()


def emit(trigger, flag):
    _, event, tag = FLAGS[flag]
    hook = Path(__file__).with_name("telegram-notify.sh")
    payload = {"session_id": trigger["session_id"], "cwd": trigger["cwd"], "hook_event_name": tag}
    subprocess.run(["bash", str(hook), event, "Codex"], input=json.dumps(payload).encode(),
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5, check=False)


def run_checker(trigger, state_file, lock_fd):
    previous = read_json(state_file, {})
    notified = set(previous.get("notified", [])) if previous.get("turn_id") == trigger["turn_id"] else set()
    pending = set()
    daemon = None
    failures = 0
    code = "observing"
    request_file = state_file.with_suffix(".request.json")

    def record(running):
        atomic_json(state_file, {"pid": os.getpid(), "turn_id": trigger["turn_id"], "running": running,
                                 "code": code, "pending": sorted(pending), "notified": sorted(notified),
                                 "updated_at": int(time.time())})
    try:
        record(True)
        while True:
            latest = read_json(request_file, trigger)
            if latest.get("turn_id") != trigger["turn_id"]:
                latest = sanitized_trigger(latest)
                if latest["session_id"] != trigger["session_id"]:
                    raise InspectionError("invalid-trigger")
                trigger = latest
                notified.clear()
                pending.clear()
            config = settings()
            if shutdown_marker().exists() or not inspection_enabled(config):
                code = "disabled"
                break
            try:
                if daemon is None:
                    daemon = Daemon()
                status, turn = daemon.snapshot(trigger["session_id"])
                if status["type"] != "active":
                    code = "turn-finished"
                    break
                if turn["id"] != trigger["turn_id"] or turn["status"] != "inProgress":
                    code = "turn-finished"
                    break
                pending = set(status["activeFlags"]) & FLAGS.keys()
                notified.intersection_update(pending)
                for flag in sorted(pending):
                    if config[FLAGS[flag][0]] and flag not in notified:
                        # Reserve before attempting delivery: a timeout must not spam this wait.
                        notified.add(flag)
                        record(True)
                        emit(trigger, flag)
                code = "observing"
                failures = 0
                record(True)
            except Exception as error:
                code = str(error) if isinstance(error, InspectionError) else "daemon-unavailable"
                if daemon:
                    daemon.close()
                    daemon = None
                failures += 1
                record(True)
                if failures >= MAX_FAILURES:
                    break
            time.sleep(POLL_INTERVAL)
    finally:
        if daemon:
            daemon.close()
        record(False)
        os.close(lock_fd)
        # Closing and then rechecking closes the lost-wakeup race at turn handoff.
        latest = read_json(request_file, trigger)
        if latest.get("turn_id") != trigger["turn_id"] and not shutdown_marker().exists():
            start_checker(latest, record_request=False)


def start_checker(payload, record_request=True):
    if shutdown_marker().exists() or not inspection_enabled(settings()) or os.environ.get("TELEGRAM_DRY_RUN") == "true":
        return
    trigger = sanitized_trigger(payload)
    lock_path, state_file = state_paths(trigger["session_id"])
    lock_path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    if record_request:
        atomic_json(state_file.with_suffix(".request.json"), trigger)
    fd = os.open(lock_path, os.O_CREAT | os.O_RDWR, 0o600)
    try:
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        process = subprocess.Popen([sys.executable, str(Path(__file__).resolve()), "run", "--lock-fd", str(fd)],
                                   stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                   pass_fds=(fd,), start_new_session=True)
        process.stdin.write(json.dumps(trigger).encode())
        process.stdin.close()
    finally:
        os.close(fd)


def probe(session_id=None):
    daemon = None
    try:
        daemon = Daemon()
        if session_id:
            status, turn = daemon.snapshot(session_id)
            return {"available": True, "status": status, "turn": turn,
                    "live_wait_coverage": "unverified"}
        return {"available": True, "mode": "on-demand", "live_wait_coverage": "unverified"}
    except Exception as error:
        return {"available": False, "code": str(error) if isinstance(error, InspectionError) else "daemon-unavailable"}
    finally:
        if daemon:
            daemon.close()


def stop_checkers():
    marker = shutdown_marker()
    marker.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    marker.touch(mode=0o600)
    deadline = time.monotonic() + 12
    while True:
        busy = False
        for lock in marker.parent.glob("codex-*.lock"):
            if not re.fullmatch(r"codex-[0-9a-f]{24}\.lock", lock.name):
                continue
            with lock.open("r+") as stream:
                try:
                    fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
                except BlockingIOError:
                    busy = True
        if not busy:
            for path in marker.parent.iterdir():
                if re.fullmatch(r"codex-[0-9a-f]{24}\.(json|request\.json|lock)", path.name):
                    path.unlink(missing_ok=True)
            return True
        if time.monotonic() >= deadline:
            return False
        time.sleep(.1)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("start", "run", "probe", "stop"))
    parser.add_argument("--lock-fd", type=int)
    parser.add_argument("--session")
    args = parser.parse_args()
    if args.action == "stop":
        stopped = stop_checkers()
        print(json.dumps({"stopped": stopped}))
        sys.exit(0 if stopped else 1)
    if args.action == "probe":
        print(json.dumps(probe(args.session), ensure_ascii=False))
        return
    try:
        payload = json.load(sys.stdin)
        if args.action == "start":
            start_checker(payload)
        else:
            trigger = sanitized_trigger(payload)
            if args.lock_fd is None:
                raise InspectionError("missing-lock")
            run_checker(trigger, state_paths(trigger["session_id"])[1], args.lock_fd)
    except Exception:
        # Notification helpers must never control the native agent loop.
        return


if __name__ == "__main__":
    main()
