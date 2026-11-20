#!/usr/bin/env bash
# Shared setup and helpers for the handoff test sections (tests/handoff/<section>.sh), sourced by each section.
# Every section runs in its own process with its own $tmp. Run sections through tests/test_agent_handoff.sh.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SKILL="$ROOT/template/common/skills/agent-handoff"
KV="$SKILL/scripts/kv.sh"
WRITE="$SKILL/scripts/handoff-write"
fail=0
# Run inside a Herdr app terminal, the route would name that terminal as the stopping session.
unset HC_TERMINAL_ID

ok() { printf '  ok   %s\n' "$1"; }
bad() { printf '  FAIL %s\n' "$1"; fail=1; }
# check <name>: ok or FAIL from the exit status of the command just before it; returns 1 on FAIL for a diagnostic.
check() { local rc=$? name="$1"; if (( rc == 0 )); then ok "$name"; else bad "$name"; return 1; fi; }

new_repo() {
  local dir="$1"
  git init -q -b main "$dir"
  git -C "$dir" config user.email test@example.com
  git -C "$dir" config user.name "Handoff Test"
  git -C "$dir" config commit.gpgsign false
  printf '/.agent-handoff/\n' > "$dir/.gitignore"
  printf 'seed\n' > "$dir/README.md"
  git -C "$dir" add .gitignore README.md
  git -C "$dir" commit -qm seed
}

tmp="$(cd "$(mktemp -d "${TMPDIR:-/tmp}/wk-handoff.XXXXXX")" && pwd -P)"
trap 'rm -rf "$tmp"' EXIT

# ---------------------------------------------------------------- test doubles for xirp, gh and notify
ROUTE="$ROOT/scripts/handoff/handoff-route"
# Fake CLIs (one file each; see the header of each file for what it models and its switches).
FAKES="$ROOT/tests/handoff/fakes"
# hook_home <dir>: a HOME where handoff-route is registered for Claude Code and Codex.
hook_home() {
  mkdir -p "$1/.claude" "$1/.codex"
  jq -n '{hooks:{Stop:[{matcher:"",hooks:[{type:"command",command:"bash \"~/.config/wk-workflow/handoff/handoff-route\""}]}]}}' | tee "$1/.claude/settings.json" > "$1/.codex/hooks.json"
}
REAL_HOME="$HOME"; TEST_HOME="$tmp/home-test"; hook_home "$TEST_HOME"
# Commands run with the test HOME, unless a test sets its own HOME for the call.
thome() { if [[ "$HOME" == "$REAL_HOME" ]]; then printf '%s' "$TEST_HOME"; else printf '%s' "$HOME"; fi; }
herdr_calls() { cat "$FAKE_XIRP_DIR/herdr/calls" 2>/dev/null; }
herdr_prompts() { cat "$FAKE_XIRP_DIR/herdr/prompts" 2>/dev/null; }

# new_loop <dir> [review-mode] [finish-trigger] [max] : repo with a loop for change add-export
new_loop() {
  local d="$1" mode="${2:-shared}" trig="${3:-ask}" max="${4:-3}"
  new_repo "$d"; git -C "$d" switch -q -c feature/add-export
  mkdir -p "$d/.agent-handoff/add-export"
  cat > "$d/.agent-handoff/add-export/loop.yaml" <<YAML
change: add-export
max_rounds: $max
implementer:
  session: impl-1
  worktree: $d
reviewer:
  session:
  worktree:
finish:
  session:
  worktree:
  trigger: $trig
  delivery: local
review_template:
  worktree: $mode
  harness: codex
  model: gpt-6.1-sol
  effort: high
  name: "codex - review - {change}"
  prompt: "\$change-review {change} commit {head} round {round} {author}"
finish_template:
  worktree: shared
  harness: codex
  model: gpt-5.6-terra
  effort: medium
  name: "codex - finish - {change}"
  prompt: "\$openspec-commit {change} delivery {delivery}"
YAML
}
fresh_state() { export FAKE_XIRP_DIR="$tmp/state-$1"; rm -rf "$FAKE_XIRP_DIR"; mkdir -p "$FAKE_XIRP_DIR/herdr" "$FAKE_XIRP_DIR/happ" "$FAKE_XIRP_DIR/hc"; }
use_project() { export FAKE_PROJECT_PATH="$(dirname "$(git -C "$1" rev-parse --path-format=absolute --git-common-dir)")"; }
# Hook mode run synchronously (HANDOFF_ROUTE_WAIT=1), as when an agent stops.
route_in() { (cd "$1" && PATH="$FAKES:$PATH" HANDOFF_NOTIFY="$FAKES/notify.sh" HANDOFF_CREATE_WAIT=2 HANDOFF_ROUTE_WAIT=1 CHIRP_SESSION_ID="${T_SID-chirp-1}" "$ROUTE" </dev/null); }
hw() { local d="$1"; shift; (cd "$d" && "$WRITE" --change add-export "$@") >/dev/null 2>&1; }
commit_in() { printf '%s\n' "$2" > "$1/work.txt"; git -C "$1" add work.txt; git -C "$1" commit -qm "$2"; }
msgs() { cat "$FAKE_XIRP_DIR/messages" 2>/dev/null; }
notes() { cat "$FAKE_XIRP_DIR/notified" 2>/dev/null; }
created() { cat "$FAKE_XIRP_DIR/count" 2>/dev/null || echo 0; }

# ---------------------------------------------------------------- handoff notifications
jl() { cat "$FAKE_XIRP_DIR/handoff.jsonl" 2>/dev/null; }
kinds() { jl | jq -r .kind 2>/dev/null | paste -sd' ' -; }
jt() { jl | tail -1 | jq -e "$@" >/dev/null 2>&1; }
ncount() { if [[ -f "$FAKE_XIRP_DIR/notified" ]]; then wc -l < "$FAKE_XIRP_DIR/notified" | tr -d ' '; else echo 0; fi; }
routed() { grep -qxF "$2" "$1/.agent-handoff/add-export/.routed" 2>/dev/null; }
lset() { (source "$ROOT/scripts/handoff/lib/handoff.sh" && kv_set "$@"); }
rpt() { printf 'r\n' > "$1/r.md"; mkdir -p "$1/.git/info"; printf '/r.md\n' >> "$1/.git/info/exclude"; }
# one_record <dir> <state> <handoff-write args...>: fresh loop and state with one record written
one_record() { local d="$1" s="$2"; shift 2; new_loop "$d"; use_project "$d"; fresh_state "$s"; rpt "$d"; hw "$d" "$@"; }

# ---------------------------------------------------------------- launcher (handoff-start)
START="$ROOT/scripts/handoff/handoff-start"
FINISH="$ROOT/scripts/handoff/handoff-finish"
# new_project <dir>: main worktree on main, with an active change, its branch and role templates
new_project() {
  local d="$1"; new_repo "$d"
  mkdir -p "$d/openspec/changes/add-export"; printf 'p\n' > "$d/openspec/changes/add-export/proposal.md"
  git -C "$d" add openspec; git -C "$d" commit -qm change; git -C "$d" branch feature/add-export
  mkdir -p "$d/.agent-handoff"; cp "$SKILL/roles.example.yaml" "$d/.agent-handoff/roles.yaml"
}
start_in() { local d="$1"; shift; (cd "$d" && HOME="$(thome)" PATH="${PF_PATH:-$FAKES:$PATH}" HANDOFF_CREATE_WAIT=2 "$START" "$@" </dev/null); }
finish_in() { local d="$1"; shift; (cd "$d" && HOME="$(thome)" PATH="${PF_PATH:-$FAKES:$PATH}" HANDOFF_CREATE_WAIT=2 "$FINISH" "$@" </dev/null); }
role_in() { local d="$1"; shift; (cd "$d" && HOME="$(thome)" PATH="${PF_PATH:-$FAKES:$PATH}" HANDOFF_NOTIFY="$FAKES/notify.sh" HANDOFF_CREATE_WAIT=2 "$ROOT/scripts/handoff/handoff-role" "$@" </dev/null); }
deleted() { cat "$FAKE_XIRP_DIR/deleted" 2>/dev/null; }
# mv that fails when its destination matches $FAKE_MV_FAIL and its source $FAKE_MV_FROM (globs; test-only fault injection),
# after letting $FAKE_MV_AFTER matching calls through (counted in $FAKE_MV_COUNT); with $FAKE_MV_IF, only when the
# source file contains that text.
MVSHIM="$tmp/mvshim"; mkdir -p "$MVSHIM"
cat > "$MVSHIM/mv" <<'SH'
#!/usr/bin/env bash
src="$1"; for a in "$@"; do dst="$a"; done
# shellcheck disable=SC2053
if [[ -n "${FAKE_MV_FAIL:-}" && "$dst" == $FAKE_MV_FAIL && "$src" == ${FAKE_MV_FROM:-*} ]] \
  && { [[ -z "${FAKE_MV_IF:-}" ]] || grep -qF -- "$FAKE_MV_IF" "$src" 2>/dev/null; }; then
  n="$(cat "${FAKE_MV_COUNT:-/dev/null}" 2>/dev/null)"; n="${n:-0}"; echo $((n + 1)) > "${FAKE_MV_COUNT:-/dev/null}"
  (( n >= ${FAKE_MV_AFTER:-0} )) && { echo "mv: injected failure" >&2; exit 1; }
fi
exec /bin/mv "$@"
SH
chmod +x "$MVSHIM/mv"
# git that moves feature/add-export to $FAKE_GIT_MOVE_TO just before "worktree add" (test-only race injection).
REAL_GIT="$(command -v git)"; GITSHIM="$tmp/gitshim"; mkdir -p "$GITSHIM"
cat > "$GITSHIM/git" <<SH
#!/usr/bin/env bash
if [[ -n "\${FAKE_GIT_MOVE_TO:-}" && "\$1" == -C && " \$* " == *" worktree add "* ]]; then "$REAL_GIT" -C "\$2" update-ref refs/heads/feature/add-export "\$FAKE_GIT_MOVE_TO"; fi
exec "$REAL_GIT" "\$@"
SH
chmod +x "$GITSHIM/git"
MV_KV='*/loop.yaml.[A-Za-z0-9][A-Za-z0-9][A-Za-z0-9][A-Za-z0-9][A-Za-z0-9][A-Za-z0-9]'  # kv_set's temporary file
# wrpt <worktree>: an ignored review report r.md in a linked worktree
wrpt() { local i; i="$(git -C "$1" rev-parse --path-format=absolute --git-common-dir)/info"; printf 'r\n' > "$1/r.md"; mkdir -p "$i"; printf '/r.md\n' >> "$i/exclude"; }

# ---------------------------------------------------------------- environment checks (ho_preflight, handoff-doctor)
LIB="$ROOT/scripts/handoff/lib/handoff.sh"
DOCTOR="$ROOT/scripts/handoff/handoff-doctor"
# pf <dir> <file> <sections...>: run ho_preflight in <dir> with the test HOME and the fakes
pf() { local d="$1"; shift; (cd "$d" && export HOME="$(thome)" PATH="${PF_PATH:-$FAKES:$PATH}" HANDOFF_NOTIFY="${PF_NOTIFY-$FAKES/notify.sh}"; source "$LIB"; ho_preflight "$@"); }
doctor_in() { local d="$1"; shift; (cd "$d" && HOME="$(thome)" PATH="${PF_PATH:-$FAKES:$PATH}" HANDOFF_NOTIFY="${PF_NOTIFY-$FAKES/notify.sh}" "$DOCTOR" "$@" </dev/null); }
# A PATH with every fake but one tool, and nothing that could hold the real one.
path_without() { local b="$tmp/bin-without-$1"; rm -rf "$b"; cp -R "$FAKES" "$b"; rm -f "$b/$1"; ln -sf "$(command -v jq)" "$b/jq"; printf '%s' "$b:/usr/bin:/bin"; }

# ---------------------------------------------------------------- herdr host
HS() { printf '%s' "$FAKE_XIRP_DIR/herdr"; }
# herdr_project <dir> [roles.yaml lines...]: project whose roles all run on herdr (plus the given lines)
herdr_project() {
  local d="$1" l; shift; new_project "$d"; use_project "$d"
  { printf 'host: herdr\n'; for l in "$@"; do printf '%s\n' "$l"; done; cat "$d/.agent-handoff/roles.yaml"; } > "$d/r.tmp" && mv "$d/r.tmp" "$d/.agent-handoff/roles.yaml"
}

# ---------------------------------------------------------------- herdr-app host (Herdr desktop app)
HA() { printf '%s' "$FAKE_XIRP_DIR/happ"; }
HC() { printf '%s' "$FAKE_XIRP_DIR/hc"; }
# happ_do <command>: the recorded herdr-app do calls of that command, one JSON array each
happ_do() { jq -c --arg c "$1" 'select(.[0] == "do" and .[1] == $c)' "$(HA)/calls" 2>/dev/null; }
# happ_opt <call-json> <option>: that option's value in one recorded call
happ_opt() { jq -r --arg k "--$2" '. as $a | [range(length) | select($a[.] == $k) | $a[. + 1]][0] // empty' <<<"$1"; }
hc_sends() { cat "$(HC)/sends" 2>/dev/null; }
# happ_project <dir> [roles.yaml lines...]: project whose roles all run on the Herdr app (plus the given lines)
happ_project() {
  local d="$1" l; shift; new_project "$d"; use_project "$d"
  { printf 'host: herdr-app\n'; for l in "$@"; do printf '%s\n' "$l"; done; cat "$d/.agent-handoff/roles.yaml"; } > "$d/r.tmp" && mv "$d/r.tmp" "$d/.agent-handoff/roles.yaml"
}
# happ_loop <dir> <state>: a herdr-app loop with the reviewer opened for round 1; sets AL (worktree) and ALL (loop.yaml)
happ_loop() {
  happ_project "$1"; fresh_state "$2"; start_in "$1" add-export >/dev/null 2>&1; AL="$1-add-export"; ALL="$AL/.agent-handoff/add-export/loop.yaml"
  wrpt "$AL"; commit_in "$AL" impl; hw "$AL" --role implement --status done --head HEAD; route_in "$AL"
}
hclean() { local d="$1"; shift; (cd "$d" && PATH="$FAKES:$PATH" "$ROOT/scripts/handoff/handoff-cleanup" "$@" </dev/null); }

# finish_section <name>: end the section, exiting 1 if any assertion failed. Run directly (not through
# tests/test_agent_handoff.sh), it also prints the section result.
finish_section() {
  if [[ -z "${HANDOFF_TEST_RUNNER:-}" ]]; then
    if (( fail )); then printf 'handoff/%s: FAILED\n' "$1"; else printf 'handoff/%s: ok\n' "$1"; fi
  fi
  exit "$fail"
}
