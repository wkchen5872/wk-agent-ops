#!/usr/bin/env bash
# Handoff test section "cleanup". Run: bash tests/test_agent_handoff.sh cleanup
# shellcheck source=tests/handoff/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# ---------------------------------------------------------------- handoff-cleanup
  printf 'handoff-cleanup\n'
  source "$KV"
  CLEAN="$ROOT/scripts/handoff/handoff-cleanup"
  clean_in() { local d="$1"; shift; (cd "$d" && PATH="$FAKES:$PATH" "$CLEAN" "$@" </dev/null); }
  deleted() { cat "$FAKE_XIRP_DIR/deleted" 2>/dev/null; }
  # A full new-mode loop: implementer A, review worktree B, finish worktree F, all from the main worktree P.
  P="$tmp/clean-p"; new_project "$P"; use_project "$P"; fresh_state c1
  awk '/^  worktree: shared$/{print "  worktree: new"; next} {print}' "$P/.agent-handoff/roles.yaml" > "$P/r.tmp" && mv "$P/r.tmp" "$P/.agent-handoff/roles.yaml"
  start_in "$P" add-export >/dev/null 2>&1
  A="$P-add-export"; B="$A-review"; F="$A-finish"
  pcommon="$(git -C "$P" rev-parse --path-format=absolute --git-common-dir)"; mkdir -p "$pcommon/info"; printf '/rv/\n' >> "$pcommon/info/exclude"
  commit_in "$A" impl; hw "$A" --role implement --status done --head HEAD; route_in "$A" >/dev/null 2>&1
  mkdir -p "$B/rv"; printf 'review\n' > "$B/rv/r01.md"
  hw "$B" --role review --status done --verdict pass --head HEAD --report rv/r01.md
  finish_in "$A" add-export >/dev/null 2>&1
  if [[ ! -d "$B" || ! -d "$F" ]]; then bad "cleanup fixture has review and finish worktrees"; fi
  # A Work Item in the implementer worktree, ignored like the project's /work-items/WI-*/ rule.
  printf '/work-items/WI-*/\n' >> "$pcommon/info/exclude"
  mkdir -p "$A/work-items/WI-20261119-x/agents"; printf 'drill\n' > "$A/work-items/WI-20261119-x/agents/drill.md"

  out="$(clean_in "$A" add-export --yes 2>&1)"; rc=$?
  [[ "$rc" != 0 && -z "$(deleted)" && -d "$A" && -d "$B" && -d "$F" ]] && grep -q 'review' <<<"$out"; check "an unfinished loop is refused and the newest record named" || { printf '       %s\n' "$out"; }

  hw "$F" --role finish --status done --head HEAD
  printf 'x\n' > "$B/stray.txt"
  out="$(clean_in "$P" add-export --yes 2>&1)"; rc=$?
  [[ "$rc" != 0 && -z "$(deleted)" && -d "$A" && -d "$B" && -d "$F" ]] && grep -q "$B" <<<"$out"; check "a worktree with uncommitted changes stops cleanup and is named" || { printf '       %s\n' "$out"; }
  rm "$B/stray.txt"

  out="$(clean_in "$P" add-export 2>&1)"; rc=$?
  [[ "$rc" == 0 && -z "$(deleted)" && -d "$A" && -d "$B" && -d "$F" ]] && grep -q 'sess-1' <<<"$out" && grep -q 'sess-2' <<<"$out" && grep -q 'sess-3' <<<"$out" \
    && grep -q "$A" <<<"$out" && grep -q "$B" <<<"$out" && grep -q "$F" <<<"$out" && grep -q -- '--yes' <<<"$out"; check "without --yes it lists the sessions and worktrees and changes nothing" || { printf '       %s\n' "$out"; }
  grep -q "work-items/WI-20261119-x" <<<"$out" && [[ -f "$A/work-items/WI-20261119-x/agents/drill.md" ]]; check "the preview names the Work Items it will archive" || { printf '       %s\n' "$out"; }

  out="$(clean_in "$P" add-export --yes 2>&1)"; rc=$?
  arc="$P/.agent-handoff/archive/add-export"
  [[ "$rc" == 0 && -f "$arc/$(basename "$A")/01-implement.yaml" && -f "$arc/$(basename "$B")/02-review.yaml" && -f "$arc/$(basename "$B")/rv/r01.md" \
    && -n "$(ls "$arc/$(basename "$F")"/*-finish.yaml 2>/dev/null)" ]]; check "records and review reports are archived in the main worktree" || { printf '       %s\n' "$out"; }
  [[ -f "$arc/$(basename "$A")/work-items/WI-20261119-x/agents/drill.md" && ! -e "$A" ]]; check "a Work Item in a removed worktree is archived with its files" || { printf '       %s\n' "$out"; }
  [[ "$(deleted | sort | tr '\n' ' ')" == "sess-1 sess-2 sess-3 " ]]; check "each loop session is deleted once" || printf '       %s\n' "($(deleted | tr '\n' ' '))"
  [[ ! -e "$A" && ! -e "$B" && ! -e "$F" && "$(git -C "$P" worktree list | wc -l | tr -d ' ')" == 1 ]] && git -C "$P" show-ref --verify --quiet refs/heads/feature/add-export \
    && ! grep -q -- '--force' "$FAKE_XIRP_DIR/calls" 2>/dev/null; check "loop worktrees are removed and the feature branch is kept" || { git -C "$P" worktree list | sed 's/^/       /'; }
  [[ "$(git -C "$P" status --short | wc -l | tr -d ' ')" == 0 ]]; check "the archive stays out of Git"

  # Implementer in the main worktree: cleanup keeps it.
  H="$tmp/clean-here"; new_project "$H"; use_project "$H"; fresh_state c2; git -C "$H" switch -q feature/add-export
  start_in "$H" add-export --worktree here >/dev/null 2>&1
  printf 'r\n' > "$H/.agent-handoff/r.md"
  hw "$H" --role implement --status done --head HEAD
  hw "$H" --role review --status done --verdict pass --head HEAD --report .agent-handoff/r.md
  hw "$H" --role finish --status done --head HEAD
  awk '/^reviewer:/{r=1} r&&/^  session:/{print "  session: rev-2"; r=0; next} {print}' "$H/.agent-handoff/add-export/loop.yaml" > "$H/l.tmp" && mv "$H/l.tmp" "$H/.agent-handoff/add-export/loop.yaml"
  hcommon="$(git -C "$H" rev-parse --path-format=absolute --git-common-dir)"; mkdir -p "$hcommon/info"; printf '/work-items/WI-*/\n' >> "$hcommon/info/exclude"
  mkdir -p "$H/work-items/WI-20261119-x"; printf 'wi\n' > "$H/work-items/WI-20261119-x/README.md"
  out="$(clean_in "$H" add-export --yes 2>&1)"; rc=$?
  [[ "$rc" == 0 && -d "$H/.git" && "$(deleted | sort | tr '\n' ' ')" == "rev-2 sess-1 " && -f "$H/.agent-handoff/archive/add-export/$(basename "$H")/03-finish.yaml" ]]; check "an implementer in the main worktree keeps the main worktree" || { printf '       %s\n' "$out"; }
  [[ -f "$H/work-items/WI-20261119-x/README.md" ]]; check "a Work Item in the kept main worktree stays in place"
  # Abandoned loop: no finish record; --abandon cleans it with the same safety checks.
  Q="$tmp/clean-abandon"; new_project "$Q"; use_project "$Q"; fresh_state c3
  start_in "$Q" add-export >/dev/null 2>&1; QA="$Q-add-export"
  commit_in "$QA" impl; hw "$QA" --role implement --status done --head HEAD
  out="$(clean_in "$Q" add-export --abandon 2>&1)"; rc=$?
  [[ "$rc" == 0 && -d "$QA" && -z "$(deleted)" ]] && grep -qi 'abandon' <<<"$out"; check "--abandon without --yes lists the plan for an unfinished loop and changes nothing" || { printf '       %s\n' "$out"; }
  printf 'x\n' > "$QA/stray.txt"
  out="$(clean_in "$Q" add-export --abandon --yes 2>&1)"; rc=$?
  [[ "$rc" != 0 && -d "$QA" && -z "$(deleted)" ]]; check "--abandon still refuses a worktree with uncommitted changes" || { printf '       %s\n' "$out"; }
  rm "$QA/stray.txt"
  out="$(clean_in "$Q" add-export --abandon --yes 2>&1)"; rc=$?
  [[ "$rc" == 0 && ! -e "$QA" && "$(deleted)" == sess-1 && -f "$Q/.agent-handoff/archive/add-export/$(basename "$QA")/01-implement.yaml" ]] \
    && git -C "$Q" show-ref --verify --quiet refs/heads/feature/add-export; check "--abandon --yes archives, deletes the sessions and worktrees, and keeps the branch" || { printf '       %s\n' "$out"; }
  [[ -x "$ROOT/scripts/handoff/handoff-cleanup" ]] && grep -q 'handoff-cleanup' "$ROOT/scripts/handoff/install.sh" && grep -q 'handoff-cleanup' "$ROOT/scripts/handoff/README.md"; check "handoff-cleanup is installed and documented"

finish_section cleanup
