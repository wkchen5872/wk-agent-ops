#!/usr/bin/env bash
# Handoff test section "doctor". Run: bash tests/test_agent_handoff.sh doctor
# shellcheck source=tests/handoff/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

  printf 'environment checks\n'
  source "$KV"
  D="$tmp/doc-p"; new_project "$D"; use_project "$D"; fresh_state d1; DR="$D/.agent-handoff/roles.yaml"
  out="$(pf "$D" "$DR" implement review finish)"; rc=$?
  [[ "$rc" == 0 ]] && ! grep -qv '^\(ok\|warn\) \(base\|host\|harness\|role\|notify\) ' <<<"$out"; check "a ready machine has only ok and warn lines, each with its area, and passes" || { printf '       %s\n' "$out"; }
  grep -q '^ok role implement: .*opus.*not verified' <<<"$out"; check "a Claude model is ok and marked not verified" || { printf '       %s\n' "$out"; }
  grep -q '^warn harness .*codex.*/hooks' <<<"$out"; check "Codex hook trust is a warning that points to /hooks"
  grep -q '^ok harness .*codex-cli 0.130.0' <<<"$out" && grep -q '^ok host .*xirp' <<<"$out"; check "harness lines show the tool version and the host line names Xirp" || { printf '       %s\n' "$out"; }
  out="$(PF_PATH="$(path_without codex)" pf "$D" "$DR" implement review finish)"; rc=$?
  [[ "$rc" != 0 ]] && grep -q '^fail harness .*review.*codex' <<<"$out"; check "a missing codex is a failed harness check naming the review role" || { printf '       %s\n' "$out"; }
  out="$(FAKE_PROJECT_PATH="$tmp/nowhere" pf "$D" "$DR" implement review finish)"; rc=$?
  [[ "$rc" != 0 ]] && grep -q '^fail host .*xirp project add' <<<"$out"; check "an unregistered Xirp project is a failed host check that shows how to register it" || { printf '       %s\n' "$out"; }
  out="$(PF_NOTIFY="$tmp/no-notifier.sh" pf "$D" "$DR" implement review finish)"; rc=$?
  [[ "$rc" == 0 ]] && grep -q '^warn notify ' <<<"$out"; check "a missing notifier is only a warning" || { printf '       %s\n' "$out"; }
  DH="$tmp/doc-nohook"; mkdir -p "$DH"
  out="$(HOME="$DH" pf "$D" "$DR" implement)"; rc=$?
  [[ "$rc" != 0 ]] && grep -q '^fail harness .*claude.*settings.json' <<<"$out"; check "a Claude Code Stop hook that is not registered is a failed harness check" || { printf '       %s\n' "$out"; }
  out="$(pf "$D" "$tmp/doc-none.yaml" implement)"; rc=$?
  [[ "$rc" != 0 ]] && grep -q '^fail base .*doc-none.yaml' <<<"$out" && ! grep -q '^\(ok\|fail\) \(host\|harness\|role\)' <<<"$out"; check "a missing template file fails the base check and nothing else is checked" || { printf '       %s\n' "$out"; }
  awk '/^review:/{print; print "  host: tmux"; next} {print}' "$DR" > "$tmp/doc-tmux.yaml"
  out="$(pf "$D" "$tmp/doc-tmux.yaml" implement review finish)"; rc=$?
  [[ "$rc" != 0 ]] && grep -q "^fail role review.*xirp, herdr, herdr-app" <<<"$out"; check "an unknown host fails the role check" || { printf '       %s\n' "$out"; }

  # handoff-doctor
  out="$(doctor_in "$D" 2>&1)"; rc=$?
  [[ "$rc" == 0 ]] && grep -q '^ok role implement' <<<"$out" && grep -q '^ok role review' <<<"$out" && grep -q '^ok role finish' <<<"$out"; check "handoff-doctor checks the three roles of roles.yaml" || { printf '       %s\n' "$out"; }
  out="$(PF_PATH="$(path_without codex)" doctor_in "$D" 2>&1)"; rc=$?
  [[ "$rc" != 0 ]] && grep -q '^fail harness .*review.*codex' <<<"$out"; check "handoff-doctor exits non-zero on a failed check" || { printf '       %s\n' "$out"; }
  start_in "$D" add-export >/dev/null 2>&1; DA="$D-add-export"; commit_in "$DA" impl; hw "$DA" --role implement --status done --head HEAD
  dl="$DA/.agent-handoff/add-export"; awk '/^review_template:/{print; print "  model: \"gpt-6.1-terra\""; next} {print}' "$dl/loop.yaml" > "$tmp/dl.tmp" && cat "$tmp/dl.tmp" > "$dl/loop.yaml"
  snap="$(cd "$dl" && ls -la && cat ./*)"; ncalls="$(wc -l < "$FAKE_XIRP_DIR/calls")"
  out="$(doctor_in "$DA" add-export 2>&1)"; rc=$?
  [[ "$rc" == 0 ]] && grep -q '^ok role review_template\|^ok role review: .*gpt-6.1-terra' <<<"$out"; check "handoff-doctor <change> checks the roles recorded in that loop's loop.yaml" || { printf '       %s\n' "$out"; }
  [[ "$(cd "$dl" && ls -la && cat ./*)" == "$snap" ]] && ! tail -n +"$((ncalls + 1))" "$FAKE_XIRP_DIR/calls" | grep -q 'api send\|session message\|session delete'; check "handoff-doctor changes no loop file or record and sends nothing to a session"
  # start, role and finish refuse on a failed check and print warnings without stopping
  DS="$tmp/doc-start"; new_project "$DS"; use_project "$DS"; fresh_state d2
  out="$(PF_PATH="$(path_without codex)" start_in "$DS" add-export 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 && ! -e "$DS-add-export" ]] && grep -q 'handoff-start: fail harness .*review.*codex' <<<"$out"; check "handoff-start with a missing reviewer tool prints the failed check and opens nothing" || { printf '       %s\n' "$out"; }
  out="$(start_in "$DS" add-export 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(created)" == 1 ]] && grep -q 'handoff-start: warn notify' <<<"$out" && ! grep -q 'handoff-start: ok ' <<<"$out"; check "handoff-start prints warnings and still opens the implementer" || { printf '       %s\n' "$out"; }
  dsl="$DS-add-export/.agent-handoff/add-export/loop.yaml"; before="$(cat "$dsl")"
  out="$(cd "$DS" && HOME="$(thome)" PATH="$(path_without claude)" "$ROOT/scripts/handoff/handoff-role" add-export review claude:sonnet:high 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(cat "$dsl")" == "$before" ]] && grep -q 'handoff-role: fail harness .*review.*claude' <<<"$out"; check "handoff-role refuses a role whose tool is missing and keeps loop.yaml" || { printf '       %s\n' "$out"; }
  DF="$tmp/doc-finish"; new_loop "$DF"; use_project "$DF"; fresh_state d3; rpt "$DF"
  hw "$DF" --role implement --status done --head HEAD; hw "$DF" --role review --status done --verdict pass --head HEAD --report r.md
  out="$(PF_PATH="$(path_without codex)" finish_in "$DF" add-export 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 ]] && grep -q 'handoff-finish: fail harness .*finish.*codex' <<<"$out"; check "handoff-finish with a missing finish tool prints the failed check and opens nothing" || { printf '       %s\n' "$out"; }
  out="$(doctor_in "$D" no-such-change 2>&1)"; rc=$?
  [[ "$rc" != 0 ]] && grep -q 'no-such-change' <<<"$out"; check "handoff-doctor refuses an unknown change"

finish_section doctor
