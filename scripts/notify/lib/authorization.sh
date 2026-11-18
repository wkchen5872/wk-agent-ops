#!/usr/bin/env bash
# Delayed authorization confirmation shared by the bash providers (Claude Code, Antigravity).
# A wait is a marker file `<provider>-<session>.pending` in the state directory:
#   id=<wait identity>  ided=<1 if the tool gave the identity>  started=<epoch>
#   notified=<epoch of the notice, 0 before it>  tool=<generic label of the requesting tool>
# Every read-compare-act on a marker happens under the session lock `<marker>.lock`.

NOTIFY_STATE_DIR="${HOME}/.config/ai-notify/state"

# auth_seconds <value> <default> — non-negative integers only; anything else is the default.
auth_seconds() {
  if [[ "$1" =~ ^[0-9]+$ ]]; then printf '%s\n' "$((10#$1))"; else printf '%s\n' "$2"; fi
}

auth_marker() { printf '%s/%s-%s.pending\n' "${NOTIFY_STATE_DIR}" "$1" "$2"; }

# The current (sub)shell's own PID; bash 3.2 has no BASHPID.
_auth_pid() { sh -c 'echo $PPID'; }

# auth_lock <marker> <tenths of a second to wait>. A lock whose owner is gone is broken.
auth_lock() {
  local lock="$1.lock" tries="${2:-30}" owner
  mkdir -p "${NOTIFY_STATE_DIR}" 2>/dev/null || return 1
  chmod 700 "${NOTIFY_STATE_DIR}" 2>/dev/null || true
  while ! mkdir "${lock}" 2>/dev/null; do
    owner="$(cat "${lock}/pid" 2>/dev/null)"
    if [[ -n "${owner}" ]] && ! kill -0 "${owner}" 2>/dev/null; then
      rm -rf -- "${lock}"
      continue
    fi
    tries=$((tries - 1))
    [[ ${tries} -gt 0 ]] || return 1
    sleep 0.1
  done
  _auth_pid > "${lock}/pid"
}

auth_unlock() { rm -rf -- "$1.lock"; }

# auth_read <marker> — sets AUTH_ID AUTH_IDED AUTH_STARTED AUTH_NOTIFIED AUTH_TOOL; fails if absent.
auth_read() {
  AUTH_ID="" AUTH_IDED=0 AUTH_STARTED=0 AUTH_NOTIFIED=0 AUTH_TOOL=""
  [[ -f "$1" ]] || return 1
  local line
  while IFS= read -r line || [[ -n "${line}" ]]; do
    case "${line}" in
      id=*) AUTH_ID="${line#id=}" ;;
      ided=*) AUTH_IDED="${line#ided=}" ;;
      started=*) AUTH_STARTED="$(auth_seconds "${line#started=}" 0)" ;;
      notified=*) AUTH_NOTIFIED="$(auth_seconds "${line#notified=}" 0)" ;;
      tool=*) AUTH_TOOL="${line#tool=}" ;;
    esac
  done < "$1"
  [[ -n "${AUTH_ID}" ]]
}

# auth_write <marker> <id> <ided> <started> <notified> <tool> — atomic replace, mode 600.
auth_write() {
  local tmp
  tmp="$(mktemp "$1.XXXXXX")" || return 1
  printf 'id=%s\nided=%s\nstarted=%s\nnotified=%s\ntool=%s\n' "$2" "$3" "$4" "$5" "$6" > "${tmp}" &&
    chmod 600 "${tmp}" && mv -f "${tmp}" "$1" && return 0
  rm -f -- "${tmp}"
  return 1
}

# auth_clear <marker> — resolution evidence or the end of a turn. The marker is only ever
# changed under its lock: when another process holds it, a detached retry waits for the lock
# and clears the marker only if it still belongs to the same wait.
# The target wait is fixed when resolution arrives, so a wait swapped in while waiting for
# the lock is never mistaken for it.
auth_clear() {
  auth_read "$1" || return 0
  local target="${AUTH_ID}"
  if auth_lock "$1" 30; then
    if auth_read "$1" && [[ "${AUTH_ID}" == "${target}" ]]; then rm -f -- "$1"; fi
    auth_unlock "$1"
    return 0
  fi
  ( _auth_clear_later "$1" "${target}" ) </dev/null >/dev/null 2>&1 &
  disown 2>/dev/null || true
}

_auth_clear_later() {
  auth_lock "$1" 600 || return 0
  if auth_read "$1" && [[ "${AUTH_ID}" == "$2" ]]; then rm -f -- "$1"; fi
  auth_unlock "$1"
}

# auth_decide <marker> <identity or empty> <rearm seconds> <now>
# Prints "new" when a new wait begins, otherwise "same". Caller holds the lock.
# With an identity: same identity → same wait; a different one → new wait.
# Without one: any wait on record absorbs the signal, except a notified wait whose
# notice is at least <rearm> seconds old (design decision 3). Clocks here have whole-second
# resolution, so a wait may re-arm up to one second early.
auth_decide() {
  if ! auth_read "$1"; then echo new; return; fi
  if [[ -n "$2" ]]; then
    [[ "${AUTH_IDED}" == 1 && "${AUTH_ID}" == "$2" ]] && { echo same; return; }
    echo new; return
  fi
  if [[ "${AUTH_NOTIFIED}" -gt 0 && $(( $4 - AUTH_NOTIFIED )) -ge "$3" ]]; then echo new; else echo same; fi
}

auth_new_id() { printf 'w%s-%s-%s\n' "$(date +%s)" "$$" "${RANDOM}"; }
