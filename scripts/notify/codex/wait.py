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
    "waitingOnApproval": ("authorization", "codex-human-approval", "HumanApprovalWaiting"),
    "waitingOnUserInput": ("user_input", "codex-user-input", "UserInputWaiting"),
}
# New key, then the legacy keys it replaces (design decision 2 of refine-notify-core).
CATEGORIES = {
    "authorization": ("NOTIFY_AUTHORIZATION", ("NOTIFY_ACTION_REQUIRED", "NOTIFY_CODEX_HUMAN_APPROVAL")),
    "user_input": ("NOTIFY_USER_INPUT", ("NOTIFY_ACTION_REQUIRED", "NOTIFY_CODEX_USER_INPUT")),
}
STALE_SECONDS = 7 * 86400
RPC_TIMEOUT = 2
POLL_INTERVAL = 1
MAX_FAILURES = 3


class InspectionError(Exception):
    """Only stable, credential-free codes leave the transport layer."""


def notify_root():
    return Path.home() / ".config/ai-notify"


def read_config():
    values = {}
    try:
        for line in (notify_root() / "config").read_text().splitlines():
            key, separator, value = line.partition("=")
            if separator and re.fullmatch(r"[A-Z][A-Z0-9_]*", key):
                try:
                    tokens = shlex.split(value, comments=True)
                except ValueError:
                    continue
                values[key] = tokens[0] if len(tokens) == 1 else ""
    except OSError:
        return None
    return values


def category_enabled(name, config_file, environment):
    """Environment new key, environment legacy keys, file new key, file legacy keys, default on."""
    key, legacy = CATEGORIES[name]
    for source in (environment, config_file):
        if source.get(key) in ("true", "false"):
            return source[key] == "true"
        values = [source.get(entry) for entry in legacy]
        if "true" in values:
            return True
        if "false" in values:
            return False
    return True


def seconds(name, environment, config_file, default):
    for source in (environment, config_file):
        value = source.get(name, "")
        if re.fullmatch(r"[0-9]+", value or ""):
            return int(value)
    return default


def settings():
    config_file = read_config()
    if config_file is None:
        return {"TELEGRAM_ENABLED": False, "authorization": False, "user_input": False, "delay": 30}
    environment = dict(os.environ)
    enabled = environment.get("TELEGRAM_ENABLED", config_file.get("TELEGRAM_ENABLED")) == "true"
    result = {"TELEGRAM_ENABLED": enabled,
              "delay": seconds("NOTIFY_AUTHORIZATION_DELAY_SECONDS", environment, config_file, 30)}
    for name in CATEGORIES:
        result[name] = category_enabled(name, config_file, environment)
    return result


def inspection_enabled(config):
    return config["TELEGRAM_ENABLED"] and any(config[name] for name in CATEGORIES)


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
    # Only a generic tool label may reach a message; never the tool input.
    tool = payload.get("tool_name")
    trigger["tool_name"] = tool if isinstance(tool, str) and re.fullmatch(r"[A-Za-z0-9_.:-]{1,64}", tool) else ""
    trigger["kind"] = "permission" if payload.get("kind") == "permission" else "question"
    requested = payload.get("requested_at")
    trigger["requested_at"] = requested if isinstance(requested, (int, float)) else time.time()
    # Size of the session record when the request was raised: calls written later belong to later requests.
    size = payload.get("record_size")
    trigger["record_size"] = size if isinstance(size, int) and not isinstance(size, bool) and size >= 0 else None
    path = payload.get("transcript_path")
    if isinstance(path, str) and path.startswith("/") and len(path) <= 4096:
        trigger["transcript_path"] = path
    return trigger


def persisted(trigger):
    """The record path stays in memory; state files never hold it."""
    return {key: value for key, value in trigger.items() if key != "transcript_path"}


def record_path(trigger):
    path = trigger.get("transcript_path")
    if path and os.path.isfile(path):
        return Path(path)
    if not re.fullmatch(r"[A-Za-z0-9-]{1,128}", trigger["session_id"]):
        return None
    codex_home = Path(os.environ.get("CODEX_HOME", str(Path.home() / ".codex")))
    found = sorted((codex_home / "sessions").glob(f"*/*/*/rollout-*-{trigger['session_id']}.jsonl"))
    return found[-1] if found else None


def open_calls(trigger):
    """Tool calls without an output as [(call_id, byte offset)], oldest first; None when unreadable.

    A record shows that a request has a result; it never proves that a request waits for
    approval, so callers treat an open call only as "could not confirm".
    """
    path = record_path(trigger)
    if path is None:
        return None
    try:
        with path.open("rb") as stream:
            stream.seek(0, os.SEEK_END)
            offset = max(0, stream.tell() - 2_000_000)
            stream.seek(offset)
            data = stream.read()
    except OSError:
        return None
    calls = []
    for raw in data.splitlines(keepends=True):
        position, offset = offset, offset + len(raw)
        try:
            entry = json.loads(raw)
        except ValueError:
            continue
        payload = entry.get("payload") if isinstance(entry, dict) else None
        if not isinstance(payload, dict):
            continue
        kind = payload.get("type")
        if entry.get("type") == "event_msg" and kind in ("task_complete", "turn_aborted"):
            calls.clear()
        elif isinstance(kind, str) and kind.endswith("_call") and isinstance(payload.get("call_id"), str):
            calls.append((payload["call_id"], position))
        elif isinstance(kind, str) and kind.endswith("_call_output"):
            calls = [call for call in calls if call[0] != payload.get("call_id")]
    return calls


def pending_call(trigger):
    """The last open call id, "" if none, None when the record cannot be read."""
    calls = open_calls(trigger)
    if calls is None:
        return None
    return calls[-1][0] if calls else ""


def record_size(trigger):
    """Size of the session record even when its content cannot be read, else None."""
    path = record_path(trigger)
    try:
        return path.stat().st_size if path else None
    except OSError:
        return None


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
    send(trigger, event, tag)


def send(trigger, event, tag):
    hook = Path(__file__).with_name("telegram-notify.sh")
    payload = {"session_id": trigger["session_id"], "cwd": trigger["cwd"], "hook_event_name": tag}
    if trigger.get("tool_name"):
        payload["tool_name"] = trigger["tool_name"]
    subprocess.run(["bash", str(hook), event, "Codex"], input=json.dumps(payload).encode(),
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5, check=False)


def run_checker(trigger, state_file, lock_fd):
    previous = read_json(state_file, {})
    same_turn = previous.get("turn_id") == trigger["turn_id"]
    notified = set(previous.get("notified", [])) if same_turn else set()
    # The wait already reported as unconfirmed in this turn: {"call": id or None, "offset": record
    # size at the notice}. Only record content decides identity; readability is never evidence.
    reported = previous.get("offline_reported") if same_turn else None
    if not isinstance(reported, dict):
        reported = None
    pending = set()
    daemon = None
    failures = 0
    code = "observing"
    request_file = state_file.with_suffix(".request.json")
    # Approval waits must last longer than the delay; this is when the current one began.
    approval_since = None
    # An authorization request raised in this turn and not yet settled (offline fallback).
    def own(candidate):
        """Fix a request together with its own call: the open call at its trigger, or, when the
        record was unreadable then, the record size that bounds which calls can be its own."""
        if candidate is None:
            return None, None
        if candidate.get("record_size") is None:
            candidate = {**candidate, "record_size": record_size(candidate)}
        return candidate, pending_call(candidate)

    request, request_call = own(trigger if trigger["kind"] == "permission" else None)
    # A session never seen active is not loaded in the daemon (CLI-started Codex): the runtime
    # cannot answer for it. Once seen active, "not loaded" means the turn has finished.
    seen_active = False

    def record(running):
        atomic_json(state_file, {"pid": os.getpid(), "turn_id": trigger["turn_id"], "running": running,
                                 "code": code, "pending": sorted(pending), "notified": sorted(notified),
                                 "offline_reported": reported, "updated_at": int(time.time())})

    def settle_offline(config):
        """Runtime cannot be queried: settle this request's own call from the session record, reporting
        each continuous wait once as unconfirmed (review codex-01a1ee38-r02/F-01, r03, r04, r05)."""
        nonlocal reported

        def report(call, offset):
            nonlocal reported
            if not config["authorization"]:
                return  # nothing is attempted, so nothing is reserved
            reported = {"call": call, "offset": offset}
            record(True)
            send(request, "codex-authorization-unconfirmed", "HumanApprovalUnconfirmed")

        calls = open_calls(request)
        if calls is None:
            # An unreadable record says nothing: a wait already reported this turn stays reported.
            if reported is None:
                report(None, request.get("record_size"))
            return
        if not calls:
            reported = None  # no open call: the reported wait is resolved
            record(True)
            return
        if request_call:
            own_calls = [entry for entry in calls if entry[0] == request_call]
        elif request_call == "":
            own_calls = []  # nothing was open when this request was raised
        else:
            bound = request.get("record_size")
            own_calls = [entry for entry in calls if bound is None or entry[1] < bound]
        if not own_calls:
            return  # this request's call has its result; later calls are settled by their own requests
        call, offset = own_calls[-1]
        if reported is None:
            report(call, offset)
        elif reported["call"] == call:
            return
        elif reported["call"] is None:
            if reported["offset"] is not None and offset >= reported["offset"]:
                report(call, offset)  # written after the notice: a new request
            else:
                reported = {"call": call, "offset": offset}  # the reported wait, now identified
                record(True)
        else:
            report(call, offset)  # a different call: a new request, whatever happened to the old one

    try:
        record(True)
        while True:
            latest = read_json(request_file, persisted(trigger))
            if latest.get("turn_id") != trigger["turn_id"]:
                latest = sanitized_trigger(latest)
                if latest["session_id"] != trigger["session_id"]:
                    raise InspectionError("invalid-trigger")
                trigger = {**latest, "transcript_path": trigger.get("transcript_path", "")}
                notified.clear()
                pending.clear()
                reported = None
                approval_since = None
                request, request_call = own(trigger if trigger["kind"] == "permission" else None)
            elif latest.get("kind") == "permission" and request is None:
                request, request_call = own({**trigger, **sanitized_trigger(latest),
                                             "transcript_path": trigger.get("transcript_path", "")})
            config = settings()
            if shutdown_marker().exists() or not inspection_enabled(config):
                code = "disabled"
                break
            try:
                if daemon is None:
                    daemon = Daemon()
                status, turn = daemon.snapshot(trigger["session_id"])
                if status["type"] != "active":
                    if not seen_active:
                        raise InspectionError("session-not-loaded")
                    code = "turn-finished"
                    break
                seen_active = True
                if turn["id"] != trigger["turn_id"] or turn["status"] != "inProgress":
                    code = "turn-finished"
                    break
                request = None  # the runtime answers for the request from now on
                pending = set(status["activeFlags"]) & FLAGS.keys()
                notified.intersection_update(pending)
                if "waitingOnApproval" in pending:
                    approval_since = approval_since or time.monotonic()
                else:
                    approval_since = None
                for flag in sorted(pending):
                    if not config[FLAGS[flag][0]] or flag in notified:
                        continue
                    if flag == "waitingOnApproval" and time.monotonic() - approval_since < config["delay"]:
                        continue
                    # Reserve before attempting delivery: a timeout must not spam this wait.
                    notified.add(flag)
                    record(True)
                    emit(trigger, flag)
                code = "observing"
                failures = 0
                record(True)
            except Exception as error:
                code = str(error) if isinstance(error, InspectionError) else "daemon-unavailable"
                if daemon and code != "session-not-loaded":
                    daemon.close()
                    daemon = None
                failures += 1
                record(True)
                if request is not None:
                    # Keep the request until its delay has passed, then settle it from the record.
                    if time.time() - request["requested_at"] >= config["delay"]:
                        settle_offline(config)
                        newer = read_json(request_file, {})
                        if (newer.get("kind") == "permission" and newer.get("turn_id") == trigger["turn_id"]
                                and newer.get("requested_at", 0) > request["requested_at"]):
                            # A later request of this turn gets its own delay.
                            request, request_call = own({**trigger, **sanitized_trigger(newer),
                                                         "transcript_path": trigger.get("transcript_path", "")})
                        else:
                            request = None
                            break
                elif failures >= MAX_FAILURES:
                    break
            time.sleep(POLL_INTERVAL)
    finally:
        if daemon:
            daemon.close()
        record(False)
        os.close(lock_fd)
        # Closing and then rechecking closes the lost-wakeup race at turn handoff.
        latest = read_json(request_file, persisted(trigger))
        if latest.get("turn_id") != trigger["turn_id"] and not shutdown_marker().exists():
            start_checker(latest, record_request=False)


def prune_state():
    """Remove notification-owned state older than seven days whose lock nobody holds."""
    folder = notify_root() / "state"
    try:
        entries = list(folder.iterdir())
    except OSError:
        return
    now = time.time()

    def age(paths):
        try:
            return now - max(path.stat().st_mtime for path in paths)
        except OSError:
            return 0
    # Codex keeps three files per session; they go together, only when the checker lock is free.
    groups = {}
    for path in entries:
        match = re.fullmatch(r"(codex-[0-9a-f]{24})\.(json|request\.json|lock)", path.name)
        if match:
            groups.setdefault(match.group(1), []).append(path)
    for key, paths in groups.items():
        if age(paths) < STALE_SECONDS:
            continue
        lock = folder / f"{key}.lock"
        try:
            descriptor = os.open(lock, os.O_RDWR) if lock.exists() else None
        except OSError:
            continue
        try:
            if descriptor is not None:
                try:
                    fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
                except BlockingIOError:
                    continue
            for path in paths:
                path.unlink(missing_ok=True)
        finally:
            if descriptor is not None:
                os.close(descriptor)
    # Delayed-authorization markers of the bash providers use a lock directory holding a PID.
    for path in entries:
        if not re.fullmatch(r"(claude|antigravity)-[A-Za-z0-9_.-]+\.pending", path.name) or age([path]) < STALE_SECONDS:
            continue
        lock = path.with_name(path.name + ".lock")
        try:
            owner = int((lock / "pid").read_text().strip())
        except (OSError, ValueError):
            owner = None
        if owner is not None:
            try:
                os.kill(owner, 0)
                continue  # a live process holds the lock
            except PermissionError:
                continue  # alive, owned by someone else
            except ProcessLookupError:
                pass
        path.unlink(missing_ok=True)
        shutil.rmtree(lock, ignore_errors=True)


def start_checker(payload, record_request=True):
    if shutdown_marker().exists() or not inspection_enabled(settings()) or os.environ.get("TELEGRAM_DRY_RUN") == "true":
        return
    trigger = sanitized_trigger(payload)
    if trigger["kind"] == "permission" and trigger["record_size"] is None:
        trigger["record_size"] = record_size(trigger)
    lock_path, state_file = state_paths(trigger["session_id"])
    lock_path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    prune_state()
    if record_request:
        atomic_json(state_file.with_suffix(".request.json"), persisted(trigger))
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
