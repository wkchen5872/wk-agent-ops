#!/usr/bin/env bash
# Offline tests for the agent handoff loop: record parser, handoff-write, routing hook, and launcher.
# Usage: bash tests/test_agent_handoff.sh [kv|write|skill|install|route|notify|mixed|start|finish|doctor|herdr|happ|hookinstall|cleanup|pi|harness|all]
#   <section>      runs tests/handoff/<section>.sh alone.
#   all (default)  runs every section in parallel, HANDOFF_TEST_JOBS at a time (default: CPU count, at most 8;
#                  1 runs them one by one), then prints each section's output in the order above.
# Shared setup and helpers are in tests/handoff/lib.sh; the fake CLIs are in tests/handoff/fakes/.
set -u

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/handoff" && pwd)"
SECTIONS=(kv write skill install route notify mixed start finish doctor herdr happ hookinstall cleanup pi harness)
# Launch order for all: slowest first (measured 2026-11-20), so the longest section never waits for a free slot.
LAUNCH=(pi herdr happ finish notify start mixed route doctor cleanup install write hookinstall skill kv harness)
section="${1:-all}"
export HANDOFF_TEST_RUNNER=1
fail=0

if [[ "$section" == all ]]; then
  jobs="${HANDOFF_TEST_JOBS:-}"
  if [[ -z "$jobs" ]]; then jobs="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)"; (( jobs > 8 )) && jobs=8; fi
  logs="$(mktemp -d "${TMPDIR:-/tmp}/wk-handoff-run.XXXXXX")"; trap 'rm -rf "$logs"' EXIT
  # The section name is the last argument, so the paths are passed as they are (no {} substitution).
  printf '%s\n' "${LAUNCH[@]}" | xargs -n 1 -P "$jobs" bash -c 'bash "$1/$3.sh" > "$2/$3.log" 2>&1; echo $? > "$2/$3.rc"' _ "$DIR" "$logs"
  for s in "${SECTIONS[@]}"; do
    cat "$logs/$s.log" 2>/dev/null
    [[ "$(cat "$logs/$s.rc" 2>/dev/null)" == 0 ]] || fail=1
  done
else
  known=0; for s in "${SECTIONS[@]}"; do [[ "$s" == "$section" ]] && known=1; done
  if (( ! known )); then
    printf 'test_agent_handoff: unknown section "%s"; choose one of: %s all\n' "$section" "${SECTIONS[*]}" >&2
    exit 2
  fi
  bash "$DIR/$section.sh" || fail=1
fi

if [[ "$fail" -ne 0 ]]; then
  printf 'test_agent_handoff: FAILED\n'
  exit 1
fi
printf 'test_agent_handoff: ok\n'
