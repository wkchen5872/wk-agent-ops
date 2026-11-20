#!/usr/bin/env bash
# Handoff test section "herdr". Run: bash tests/test_agent_handoff.sh herdr
# shellcheck source=tests/handoff/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

  printf 'herdr host\n'
  source "$KV"
  # 4.2 environment checks for herdr
  Q="$tmp/herdr-doc"; herdr_project "$Q" "herdr_session: work"; fresh_state h1; QR="$Q/.agent-handoff/roles.yaml"
  out="$(pf "$Q" "$QR" implement review finish)"; rc=$?
  [[ "$rc" == 0 ]] && grep -q '^ok host .*herdr 0.9.5' <<<"$out" && grep -q "^ok host .*work" <<<"$out" && ! grep -q 'xirp' <<<"$out" \
    && herdr_calls | grep -q $'^work\tstatus server'; check "a herdr loop checks herdr and the server of herdr_session, and not Xirp" || { printf '       %s\n' "$out"; }
  : > "$(HS)/calls"; out="$(HERDR_ENV=1 HERDR_SESSION=dev pf "$Q" "$QR" implement review finish)"
  herdr_calls | grep -q $'^dev\tstatus server' && ! herdr_calls | grep -q $'^work\t'; check "inside a herdr pane the check uses the pane's session" || { herdr_calls | sed 's/^/       /'; }
  touch "$(HS)/server-down"
  out="$(pf "$Q" "$QR" implement review finish)"; rc=$?
  [[ "$rc" != 0 ]] && grep -q '^fail host .*not running' <<<"$out"; check "a herdr server that is not running fails the host check" || { printf '       %s\n' "$out"; }
  out="$(start_in "$Q" add-export 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(created)" == 0 && ! -e "$Q-add-export" ]] && grep -q 'handoff-start: fail host .*not running' <<<"$out" \
    && ! herdr_calls | grep -q 'agent start\|workspace create\|worktree open'; check "handoff-start refuses when the herdr server is not running and opens nothing on any host" || { printf '       %s\n' "$out"; }
  rm -f "$(HS)/server-down"; touch "$(HS)/no-integration-codex"
  out="$(pf "$Q" "$QR" implement review finish)"; rc=$?
  [[ "$rc" == 0 ]] && grep -q '^warn harness review, finish: .*herdr.*codex.*integration' <<<"$out" && ! grep -q '^warn harness implement: .*integration' <<<"$out"; check "a missing herdr integration for a herdr role's tool is a warning" || { printf '       %s\n' "$out"; }
  out="$(PF_PATH="$(path_without herdr)" pf "$Q" "$QR" implement review finish)"; rc=$?
  [[ "$rc" != 0 ]] && grep -q '^fail host .*herdr command was not found' <<<"$out"; check "a missing herdr command fails the host check" || { printf '       %s\n' "$out"; }
  # 4.3 opening a herdr role
  Q2="$tmp/herdr-open"; herdr_project "$Q2"; fresh_state h2; QW="$Q2-add-export"; ql="$QW/.agent-handoff/add-export/loop.yaml"
  out="$(start_in "$Q2" add-export 2>&1)"; rc=$?
  seq="$(herdr_calls | cut -f2 | awk '{print $1, $2}' | grep -v '^status server\|^integration status\|^--version' | paste -sd, -)"
  [[ "$rc" == 0 && "$seq" == "workspace list,workspace create,worktree open,tab rename,agent start,agent prompt,agent get" ]] \
    && herdr_calls | grep -qF "workspace create --cwd $Q2 --label $(basename "$Q2") --no-focus" \
    && herdr_calls | grep -qF "worktree open --workspace w1 --path $QW --label add-export --no-focus"; check "a missing repository workspace is opened, then the loop's worktree workspace under it" || { printf '       %s\n' "($seq)"; printf '       %s\n' "$out"; herdr_calls | sed 's/^/       /'; }
  grep -qF $'w2:t1\tclaude - impl - add-export' "$(HS)/renamed" 2>/dev/null; check "the implementer's tab is named after the template"
  herdr_calls | grep 'agent start' | grep -qE 'agent start impl-[a-z0-9]+ --kind claude --pane w2:p1 -- --model opus --effort high --name claude - impl - add-export$'; check "Claude Code starts with the template's model, effort and name" || { herdr_calls | grep 'agent start' | sed 's/^/       /'; }
  herdr_prompts | grep -q $'^w2:p1\t.*openspec-apply-change add-export' \
    && herdr_calls | grep 'agent prompt' | grep -q -- '--wait --until working --until blocked --timeout [0-9]'; check "the implement prompt is sent separately and waits only until the agent starts working" || { herdr_calls | grep 'agent prompt' | sed 's/^/       /'; }
  [[ -z "$(herdr_calls | grep -E 'workspace create|worktree open|tab create' | grep -v -- '--no-focus')" ]]; check "every workspace and tab opens without focus"
  [[ "$(kv_get "$ql" implementer.session)" == w2:p1 && "$(kv_get "$ql" implementer.native_session)" == native-w2:p1 && "$(kv_get "$ql" implementer.herdr_session)" == default \
    && "$(kv_get "$ql" implementer.herdr_tab)" == w2:t1 && "$(kv_get "$ql" herdr.workspaces)" == w2 && "$(kv_get "$ql" implementer.pending_prompt 2>/dev/null)" != true \
    && "$(created)" == 0 ]]; check "loop.yaml records the pane, herdr session, native session ID, tab and the workspace the loop opened" || { cat "$ql"; }
  # The reviewer shares the worktree: it joins the same workspace in a tab of its own.
  commit_in "$QW" impl; hw "$QW" --role implement --status done --head HEAD; route_in "$QW"
  [[ "$(kv_get "$ql" reviewer.session)" == w2:p2 ]] && herdr_calls | grep -qF 'tab create --workspace w2 --cwd '"$QW"' --label codex - review - add-export --no-focus' \
    && herdr_calls | grep 'agent start' | grep -qE 'review-[a-z0-9]+ --kind codex --pane w2:p2 -- -m gpt-6.1-sol -c model_reasoning_effort=high$' \
    && herdr_prompts | grep -q $'^w2:p2\t.*change-review add-export' && [[ "$(kv_get "$ql" herdr.workspaces)" == w2 ]] \
    && [[ "$(herdr_calls | grep -c -- "worktree open --workspace w1 --path $QW --label add-export --no-focus")" == 2 ]]; check "a shared herdr reviewer opens in a new tab of the loop's workspace with Codex's model and effort" || { herdr_calls | sed 's/^/       /'; }
  # 5.1 messages go to the recorded pane after checking it still runs the role's agent
  qc="$(git -C "$QW" rev-parse --path-format=absolute --git-common-dir)"; mkdir -p "$qc/info"; printf '/r.md\n' >> "$qc/info/exclude"; printf 'r\n' > "$QW/r.md"
  hw "$QW" --role review --status done --verdict changes-required --head HEAD --report r.md; route_in "$QW"
  herdr_prompts | grep -q $'^w2:p1\t.*changes-required' && routed "$QW" 02-review.yaml; check "changes-required is sent to the implementer's pane" || { herdr_prompts | sed 's/^/       /'; }
  grep -q '02-review.yaml action=implementer:messaged:w2:p1 .*model=gpt-6.1-sol(template)' "$QW/.agent-handoff/add-export/routing.log"; check "the routing log shows a herdr role's model from its template, marked as such" || { cat "$QW/.agent-handoff/add-export/routing.log"; }
  commit_in "$QW" two; hw "$QW" --role implement --status done --head HEAD; touch "$(HS)/shell-w2:p2"; np="$(herdr_prompts | wc -l)"; nn="$(ncount)"
  route_in "$QW"
  [[ "$(herdr_prompts | wc -l)" == "$np" && "$(ncount)" == $((nn + 1)) ]] && ! routed "$QW" 03-implement.yaml && grep -q 'reviewer:send-failed:w2:p2' "$QW/.agent-handoff/add-export/routing.log"; check "a reviewer pane that now runs a shell gets no text and the record stays unprocessed" || { tail -2 "$QW/.agent-handoff/add-export/routing.log"; }
  rm -f "$(HS)/shell-w2:p2"; touch "$(HS)/blocked"; route_in "$QW"
  [[ "$(herdr_prompts | wc -l)" == "$np" && "$(ncount)" == $((nn + 1)) ]] && ! routed "$QW" 03-implement.yaml; check "a reviewer waiting on a dialog gets no text and no second notice"
  rm -f "$(HS)/blocked"; lset "$ql" reviewer.native_session other-session; route_in "$QW"
  [[ "$(herdr_prompts | wc -l)" == "$np" ]] && ! routed "$QW" 03-implement.yaml; check "a pane whose agent has another native session is treated as gone"
  lset "$ql" reviewer.native_session native-w2:p2; route_in "$QW"
  herdr_prompts | tail -1 | grep -q $'^w2:p2\t.*第 2 輪' && routed "$QW" 03-implement.yaml \
    && [[ "$(herdr_prompts | grep -c $'^w2:p2\t.*第 2 輪')" == 1 ]] && herdr_calls | grep 'agent prompt w2:p2' | tail -1 | grep -q -- '--wait --until working'; check "a retry sends the review message to the recorded pane once"
  # 5.2 an agent that stops at a dialog when it opens: keep the pane, notify once, retry only the prompt
  Q5="$tmp/herdr-trust"; herdr_project "$Q5"; fresh_state h5; Q5W="$Q5-add-export"; q5l="$Q5W/.agent-handoff/add-export/loop.yaml"
  start_in "$Q5" add-export >/dev/null 2>&1; commit_in "$Q5W" impl; hw "$Q5W" --role implement --status done --head HEAD
  touch "$(HS)/not-ready"; route_in "$Q5W"
  [[ "$(kinds)" == attention && "$(kv_get "$q5l" reviewer.session)" == w2:p2 && "$(kv_get "$q5l" reviewer.pending_prompt)" == true ]] && ! routed "$Q5W" 01-implement.yaml \
    && jt '(.detail|test("w2:t2")) and (.detail|test("codex - review - add-export")) and (.detail|test("w2[^:]")) and (.next|test("handoff-route --foreground"))' \
    && ! herdr_prompts | grep -q '^w2:p2' && ! herdr_calls | grep -q 'send-keys'; check "a reviewer stopped at a trust dialog keeps its pane, sends one notice naming its workspace and tab, and answers nothing" || { printf '       %s\n' "($(kinds))"; jl | tail -1 | sed 's/^/       /'; }
  route_in "$Q5W"; [[ "$(ncount)" == 1 ]]; check "the dialog is notified only once" || { notes | cut -c1-300; cat "$Q5W/.agent-handoff/add-export/routing.log"; }
  rm -f "$(HS)/not-ready"; ntab="$(herdr_calls | grep -c 'tab create')"
  (cd "$Q5W" && PATH="$FAKES:$PATH" HANDOFF_NOTIFY="$FAKES/notify.sh" HANDOFF_CREATE_WAIT=2 "$ROUTE" --foreground </dev/null)
  [[ "$(herdr_calls | grep -c 'tab create')" == "$ntab" && "$(herdr_calls | grep -c 'agent start')" == 2 && -z "$(kv_get "$q5l" reviewer.pending_prompt)" ]] \
    && herdr_prompts | grep -q $'^w2:p2\t.*change-review add-export' && routed "$Q5W" 01-implement.yaml; check "a foreground retry sends the review prompt to the same pane and marks the record processed" || { herdr_calls | sed 's/^/       /'; }
  Q6="$tmp/herdr-trust-start"; herdr_project "$Q6"; fresh_state h6; touch "$(HS)/not-ready"
  out="$(start_in "$Q6" add-export 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(kv_get "$Q6-add-export/.agent-handoff/add-export/loop.yaml" implementer.pending_prompt)" == true ]] && grep -q 'w2:t1' <<<"$out" && grep -q 'handoff-start add-export' <<<"$out"; check "an implementer stopped at a dialog keeps its pane and handoff-start says to run it again" || { printf '       %s\n' "$out"; }
  rm -f "$(HS)/not-ready"; out="$(start_in "$Q6" add-export 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(herdr_calls | grep -c 'worktree open')" == 1 && "$(kv_get "$Q6-add-export/.agent-handoff/add-export/loop.yaml" implementer.session)" == w2:p1 ]] \
    && herdr_prompts | grep -q $'^w2:p1\t.*openspec-apply-change'; check "running handoff-start again sends the implement prompt to the same pane" || { printf '       %s\n' "$out"; }
  # 5.3 a loop that uses both hosts routes each message through the receiving role's host
  MX="$tmp/herdr-mixed"; new_loop "$MX"; use_project "$MX"; fresh_state h7; rpt "$MX"; mxl="$MX/.agent-handoff/add-export/loop.yaml"
  lset "$mxl" review_template.host herdr; lset "$mxl" reviewer.herdr_session default
  hw "$MX" --role implement --status done --head HEAD; route_in "$MX"
  hw "$MX" --role review --status done --verdict changes-required --head HEAD --report r.md; route_in "$MX"
  [[ "$(created)" == 0 && "$(kv_get "$mxl" reviewer.session)" == w1:p2 ]] && herdr_prompts | grep -q $'^w1:p2\t.*change-review' && msgs | grep -q $'^impl-1\t.*changes-required'; check "with the implementer on Xirp and the reviewer on herdr, each message goes through its receiver's host" || { msgs; herdr_calls | sed 's/^/       /'; }
  NX="$tmp/herdr-noxirp"; herdr_project "$NX"; fresh_state h8; start_in "$NX" add-export >/dev/null 2>&1; NXW="$NX-add-export"
  commit_in "$NXW" impl; hw "$NXW" --role implement --status done --head HEAD
  (cd "$NXW" && PATH="$(path_without xirp)" HANDOFF_NOTIFY="$FAKES/notify.sh" HANDOFF_CREATE_WAIT=2 HANDOFF_ROUTE_WAIT=1 "$ROUTE" </dev/null)
  routed "$NXW" 01-implement.yaml && herdr_prompts | grep -q $'^w2:p2\t.*change-review'; check "a herdr loop is routed on a machine without xirp" || { cat "$NXW/.agent-handoff/add-export/routing.log" 2>/dev/null; }
  # 6.1 cleanup closes what the loop opened in herdr, before it removes the worktrees
  CLEAN="$ROOT/scripts/handoff/handoff-cleanup"
  hclean() { local d="$1"; shift; (cd "$d" && PATH="$FAKES:$PATH" "$CLEAN" "$@" </dev/null); }
  printf 'r\n' > "$NXW/r.md"; nxc="$(git -C "$NXW" rev-parse --path-format=absolute --git-common-dir)"; mkdir -p "$nxc/info"; printf '/r.md\n' >> "$nxc/info/exclude"
  hw "$NXW" --role review --status done --verdict pass --head HEAD --report r.md; hw "$NXW" --role finish --status done --head HEAD
  out="$(hclean "$NX" add-export 2>&1)"; rc=$?
  [[ "$rc" == 0 && ! -s "$(HS)/closed" ]] && grep -q 'herdr workspace w2' <<<"$out" && ! grep -q 'herdr workspace w1' <<<"$out"; check "the cleanup preview lists the herdr workspace the loop opened and closes nothing" || { printf '       %s\n' "$out"; }
  out="$(hclean "$NX" add-export --yes 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(cat "$(HS)/closed" 2>/dev/null)" == "workspace close w2 exists=yes" && ! -e "$NXW" ]]; check "cleanup closes the loop's herdr workspace once, before its worktree is removed, and keeps the repository workspace" || { printf '       %s\n' "$out"; cat "$(HS)/closed" 2>/dev/null; }
  Q8="$tmp/herdr-clean-here"; herdr_project "$Q8"; fresh_state h9; git -C "$Q8" switch -q feature/add-export
  start_in "$Q8" add-export --worktree here >/dev/null 2>&1; commit_in "$Q8" impl; hw "$Q8" --role implement --status done --head HEAD; route_in "$Q8"
  out="$(hclean "$Q8" add-export --abandon --yes 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(sort "$(HS)/closed" 2>/dev/null | paste -sd, -)" == "tab close w1:t2 exists=yes,tab close w1:t3 exists=yes" && -d "$Q8/.git" ]]; check "cleanup of a loop in the main worktree closes only the loop's tabs" || { printf '       %s\n' "$out"; cat "$(HS)/closed" 2>/dev/null; }
  out="$(hclean "$MX" add-export --abandon --yes 2>&1)"; rc=$?
  [[ "$rc" == 0 ]] && grep -qx 'impl-1' "$FAKE_XIRP_DIR/deleted" 2>/dev/null && grep -q 'tab close w1:t2' "$(HS)/closed" 2>/dev/null; check "cleanup of a loop on both hosts deletes the Xirp session and closes the herdr tab" || { printf '       %s\n' "$out"; }
  # codex-herdr-r01 regressions
  # herdr_loop <dir> <state>: a herdr loop with the reviewer opened for round 1; sets HL (worktree) and HLL (loop.yaml)
  herdr_loop() {
    herdr_project "$1"; fresh_state "$2"; start_in "$1" add-export >/dev/null 2>&1; HL="$1-add-export"; HLL="$HL/.agent-handoff/add-export/loop.yaml"
    local c; c="$(git -C "$HL" rev-parse --path-format=absolute --git-common-dir)"; mkdir -p "$c/info"; printf '/r.md\n' >> "$c/info/exclude"; printf 'r\n' > "$HL/r.md"
    commit_in "$HL" impl; hw "$HL" --role implement --status done --head HEAD; route_in "$HL"
  }
  # F-01: cleanup removes no worktree until herdr confirms the close, or that the target is gone
  herdr_loop "$tmp/herdr-f1" h11; hw "$HL" --role review --status done --verdict pass --head HEAD --report r.md; hw "$HL" --role finish --status done --head HEAD
  touch "$(HS)/server-down"; out="$(hclean "$tmp/herdr-f1" add-export --yes 2>&1)"; rc=$?
  [[ "$rc" != 0 && -d "$HL" && -f "$HLL" ]] && grep -q 'herdr workspace w2' <<<"$out"; check "cleanup keeps the worktrees and fails when herdr cannot close the loop's workspace (codex-herdr-r01/F-01)" || { printf '       %s\n' "$out"; }
  rm -f "$(HS)/server-down"; touch "$(HS)/gone-w2"; out="$(hclean "$tmp/herdr-f1" add-export --yes 2>&1)"; rc=$?
  [[ "$rc" == 0 && ! -e "$HL" ]]; check "a rerun of cleanup treats a workspace herdr no longer has as closed" || { printf '       %s\n' "$out"; }
  mkdir -p "$tmp/herdr sp"; herdr_loop "$tmp/herdr sp/p" h12; hw "$HL" --role review --status done --verdict pass --head HEAD --report r.md; hw "$HL" --role finish --status done --head HEAD
  out="$(hclean "$tmp/herdr sp/p" add-export --yes 2>&1)"; rc=$?
  [[ "$rc" == 0 && ! -e "$HL" ]] && grep -q 'workspace close w2 exists=yes' "$(HS)/closed" 2>/dev/null; check "cleanup closes the herdr workspace of a loop whose path has spaces" || { printf '       %s\n' "$out"; }
  # F-02: a reused herdr reviewer keeps the native session ID read when the loop started
  RV="$tmp/herdr-f2"; herdr_project "$RV"; fresh_state h13; printf 'codex\n' > "$(HS)/pane-w9:p1"
  out="$(start_in "$RV" add-export --reviewer-session w9:p1 2>&1)"; rc=$?; RVL="$RV-add-export/.agent-handoff/add-export/loop.yaml"
  [[ "$rc" == 0 && "$(kv_get "$RVL" reviewer.session)" == w9:p1 && "$(kv_get "$RVL" reviewer.native_session)" == native-w9:p1 ]]; check "a reused herdr reviewer's native session ID is recorded (codex-herdr-r01/F-02)" || { printf '       %s\n' "$out"; }
  printf 'native-replacement\n' > "$(HS)/native-w9:p1"; commit_in "$RV-add-export" impl; hw "$RV-add-export" --role implement --status done --head HEAD; route_in "$RV-add-export"
  ! herdr_prompts | grep -q '^w9:p1' && ! routed "$RV-add-export" 01-implement.yaml; check "a reused pane now running another session of the same tool gets no prompt"
  # F-03: a submission whose result is unknown is never sent again
  herdr_loop "$tmp/herdr-f3" h14; commit_in "$HL" two; hw "$HL" --role review --status done --verdict changes-required --head HEAD --report r.md
  touch "$(HS)/prompt-timeout"; np="$(herdr_prompts | wc -l)"; nn="$(ncount)"; route_in "$HL"; route_in "$HL"; rm -f "$(HS)/prompt-timeout"; route_in "$HL"
  (( $(herdr_prompts | wc -l) == np + 1 && $(ncount) == nn + 1 )) && routed "$HL" 02-review.yaml && jt '.kind=="attention" and (.detail|test("w2:p1"))' \
    && grep -q 'changes-required' "$HL/.agent-handoff/add-export/implementer-unconfirmed.txt" 2>/dev/null; check "an unconfirmed submission is not resent: one notice, the message kept in a file, the record processed (codex-herdr-r01/F-03)" || { jl | tail -1; }
  # A prompt left in the composer (Enter swallowed while the agent was still starting) is submitted once more.
  herdr_loop "$tmp/herdr-stall" h14s; commit_in "$HL" two; hw "$HL" --role review --status done --verdict changes-required --head HEAD --report r.md
  touch "$(HS)/stall"; np="$(herdr_prompts | wc -l)"; nn="$(ncount)"; route_in "$HL"; rm -f "$(HS)/stall"
  (( $(herdr_prompts | wc -l) == np + 1 && $(ncount) == nn + 1 )) && herdr_calls | grep -q 'agent send-keys w2:p1 enter' \
    && herdr_calls | grep -q 'agent wait w2:p1 --until working --until blocked --timeout' && routed "$HL" 02-review.yaml \
    && [[ ! -e "$HL/.agent-handoff/add-export/implementer-unconfirmed.txt" ]] && jt '.kind=="review"'; check "a stalled prompt gets one more Enter and counts as delivered once the agent starts working" || { herdr_calls | grep agent | sed 's/^/       /'; jl | tail -1; }
  herdr_loop "$tmp/herdr-stall2" h14t; commit_in "$HL" two; hw "$HL" --role review --status done --verdict changes-required --head HEAD --report r.md
  touch "$(HS)/stall" "$(HS)/enter-ignored"; np="$(herdr_prompts | wc -l)"; nn="$(ncount)"; route_in "$HL"; route_in "$HL"; rm -f "$(HS)/stall" "$(HS)/enter-ignored"
  (( $(herdr_prompts | wc -l) == np + 1 && $(ncount) == nn + 1 && $(herdr_calls | grep -c 'agent send-keys') == 1 )) && routed "$HL" 02-review.yaml \
    && grep -q 'changes-required' "$HL/.agent-handoff/add-export/implementer-unconfirmed.txt" 2>/dev/null && jt '.kind=="attention" and (.detail|test("w2:p1"))'; check "a prompt still not taken after the extra Enter is kept unconfirmed: one notice, never resent" || { herdr_calls | grep agent | sed 's/^/       /'; jl | tail -1; }
  # F-05: a role already open that waits on a dialog is named by workspace and tab
  herdr_loop "$tmp/herdr-f5" h15; commit_in "$HL" two; hw "$HL" --role implement --status done --head HEAD; touch "$(HS)/blocked"; route_in "$HL"
  jt '.kind=="attention" and (.detail|test("workspace w2")) and (.detail|test("w2:t2")) and (.detail|test("codex - review - add-export"))' && ! routed "$HL" 03-implement.yaml; check "an open reviewer waiting on a dialog gets one notice naming its workspace and tab (codex-herdr-r01/F-05)" || { jl | tail -1; }
  # F-04: the host is needed only to open or message a session
  F4="$tmp/herdr-f4"; new_loop "$F4"; use_project "$F4"; fresh_state h16; rpt "$F4"; lset "$F4/.agent-handoff/add-export/loop.yaml" finish_template.host herdr
  hw "$F4" --role implement --status done --head HEAD; hw "$F4" --role review --status done --verdict pass --head HEAD --report r.md
  (cd "$F4" && PATH="$(path_without herdr)" HANDOFF_NOTIFY="$FAKES/notify.sh" HANDOFF_ROUTE_WAIT=1 CHIRP_SESSION_ID=chirp-1 "$ROUTE" </dev/null)
  [[ "$(ncount)" == 1 ]] && routed "$F4" 02-review.yaml && jt '.kind=="attention" and (.next|test("handoff-finish add-export"))'; check "a pass waiting for handoff-finish is notified when the finish host is not installed (codex-herdr-r01/F-04)" || { notes; }
  # F-06: a host value is matched exactly
  F6="$tmp/herdr-f6"; new_project "$F6"; use_project "$F6"; fresh_state h17
  awk '/^implement:/{print; print "  host: \"xirp herdr\""; next} {print}' "$F6/.agent-handoff/roles.yaml" > "$F6/r.tmp" && mv "$F6/r.tmp" "$F6/.agent-handoff/roles.yaml"
  dout="$(doctor_in "$F6" 2>&1)"; drc=$?; out="$(start_in "$F6" add-export 2>&1)"; rc=$?
  [[ "$drc" != 0 && "$rc" != 0 && ! -e "$F6-add-export" && "$(created)" == 0 ]] && grep -q '^fail role implement' <<<"$dout" && grep -q 'fail role implement' <<<"$out"; check "a host that is not exactly xirp or herdr fails doctor and start, and nothing is created (codex-herdr-r01/F-06)" || { printf '       %s\n' "$dout" "$out"; }
  # codex-herdr-r03 regressions
  # r01/F-03 in finish: an unconfirmed finish prompt is neither resent nor taken as delivered until the user checks it
  herdr_loop "$tmp/herdr-r3a" h21; lset "$HLL" finish.trigger auto; hw "$HL" --role review --status done --verdict pass --head HEAD --report r.md
  touch "$(HS)/prompt-timeout"; route_in "$HL"; rm -f "$(HS)/prompt-timeout"; route_in "$HL"; nf="$(herdr_prompts | grep -c '^w2:p3')"
  uf="$HL/.agent-handoff/add-export/finish-unconfirmed.txt"
  [[ "$nf" == 1 && -f "$uf" ]] && ! routed "$HL" 02-review.yaml && ! grep -q 'finish:opened' "$HL/.agent-handoff/add-export/routing.log" \
    && jt '.kind=="attention" and (.detail|test("finish-unconfirmed.txt"))'; check "an unconfirmed automatic finish prompt is shown, kept and not taken as opened on the next hook (codex-herdr-r03, r01/F-03)" || { cat "$HL/.agent-handoff/add-export/routing.log"; jl | tail -1; }
  rm -f "$uf"; (cd "$HL" && PATH="$FAKES:$PATH" HANDOFF_NOTIFY="$FAKES/notify.sh" HANDOFF_CREATE_WAIT=2 "$ROUTE" --foreground </dev/null)
  [[ "$(herdr_prompts | grep -c '^w2:p3')" == 1 ]] && routed "$HL" 02-review.yaml && grep -q 'finish:opened:w2:p3' "$HL/.agent-handoff/add-export/routing.log"; check "after the user removes the file, the finish counts as opened without sending the prompt again" || { cat "$HL/.agent-handoff/add-export/routing.log"; }
  herdr_loop "$tmp/herdr-r3b" h22; hw "$HL" --role review --status done --verdict pass --head HEAD --report r.md
  finish_in "$HL" add-export >/dev/null 2>&1; commit_in "$HL" archive; hw "$HL" --role finish --status blocked --head HEAD --note "push rejected"
  touch "$(HS)/prompt-timeout"; out1="$(finish_in "$HL" add-export 2>&1)"; rc1=$?; rm -f "$(HS)/prompt-timeout"
  n1="$(herdr_prompts | grep -c '^w2:p3')"; out2="$(finish_in "$HL" add-export 2>&1)"; rc2=$?
  [[ "$rc1" != 0 && "$rc2" != 0 && "$(herdr_prompts | grep -c '^w2:p3')" == "$n1" ]] && grep -q 'finish-unconfirmed.txt' <<<"$out1" && grep -q 'finish-unconfirmed.txt' <<<"$out2"; check "a finish retry whose prompt herdr did not confirm is not sent again by the next handoff-finish (codex-herdr-r03, r01/F-03)" || { printf '       %s\n' "$out1" "$out2"; }
  # r01/F-05: a reused reviewer waiting on a dialog is named by its real workspace and tab
  RB="$tmp/herdr-r3c"; herdr_project "$RB"; fresh_state h23; printf 'codex\n' > "$(HS)/pane-w9:p1"
  printf 'w9:p1\tw9:t4\n' >> "$(HS)/panes"; printf 'w9:t4\tmy review\n' >> "$(HS)/tablabels"
  start_in "$RB" add-export --reviewer-session w9:p1 >/dev/null 2>&1; commit_in "$RB-add-export" impl; hw "$RB-add-export" --role implement --status done --head HEAD
  touch "$(HS)/blocked"; route_in "$RB-add-export"
  [[ "$(ncount)" == 1 ]] && jt '(.detail|test("workspace w9")) and (.detail|test("tab w9:t4")) and (.detail|test("my review"))' && ! routed "$RB-add-export" 01-implement.yaml; check "a reused reviewer waiting on a dialog gets one notice naming its actual workspace and tab (codex-herdr-r03, r01/F-05)" || { jl | tail -1; }
  rm -f "$(HS)/blocked"; hclean "$RB" add-export --abandon --yes >/dev/null 2>&1
  ! grep -q 'w9' "$(HS)/closed" 2>/dev/null; check "cleanup never closes a reused reviewer's tab"
  # r03/F-01: a herdr stop is logged with its herdr pane and native session, never an inherited Xirp ID
  herdr_loop "$tmp/herdr-r3d" h24; commit_in "$HL" two; hw "$HL" --role implement --status done --head HEAD
  (cd "$HL" && printf '{"session_id":"native-w2:p1"}' | PATH="$FAKES:$PATH" HANDOFF_NOTIFY="$FAKES/notify.sh" HANDOFF_CREATE_WAIT=2 HANDOFF_ROUTE_WAIT=1 \
    HERDR_ENV=1 HERDR_PANE_ID=w2:p1 CHIRP_SESSION_ID=chirp-inherited "$ROUTE")
  grep -q '02-implement.yaml action=reviewer:messaged:w2:p2 session=herdr:w2:p1 native=native-w2:p1 model=opus(template)' "$HL/.agent-handoff/add-export/routing.log" \
    && ! grep -q chirp-inherited "$HL/.agent-handoff/add-export/routing.log"; check "a herdr stop is logged with its herdr pane and native session, not the inherited Xirp ID (codex-herdr-r03/F-01)" || { tail -1 "$HL/.agent-handoff/add-export/routing.log"; }
  # codex-herdr-r04 regressions
  # r01/F-03: once a finish retry was submitted for a blocked record, handoff-finish never sends it again for that record
  herdr_loop "$tmp/herdr-r4a" h31; hw "$HL" --role review --status done --verdict pass --head HEAD --report r.md
  finish_in "$HL" add-export >/dev/null 2>&1; commit_in "$HL" archive; hw "$HL" --role finish --status blocked --head HEAD --note "push rejected"
  touch "$(HS)/prompt-timeout"; finish_in "$HL" add-export >/dev/null 2>&1; rm -f "$(HS)/prompt-timeout"; n1="$(herdr_prompts | grep -c '^w2:p3')"
  rm -f "$HL/.agent-handoff/add-export/finish-unconfirmed.txt"; out="$(finish_in "$HL" add-export 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(herdr_prompts | grep -c '^w2:p3')" == "$n1" ]] && grep -q 'already sent.*03-finish.yaml' <<<"$out"; check "after the user clears an unconfirmed finish retry, handoff-finish does not resend it for the same record (codex-herdr-r04, r01/F-03)" || { printf '       %s\n' "$out"; }
  herdr_loop "$tmp/herdr-r4b" h32; hw "$HL" --role review --status done --verdict pass --head HEAD --report r.md
  finish_in "$HL" add-export >/dev/null 2>&1; commit_in "$HL" archive; hw "$HL" --role finish --status blocked --head HEAD --note "push rejected"
  finish_in "$HL" add-export >/dev/null 2>&1; finish_in "$HL" add-export >/dev/null 2>&1
  commit_in "$HL" again; hw "$HL" --role finish --status blocked --head HEAD --note "push rejected again"; finish_in "$HL" add-export >/dev/null 2>&1
  [[ "$(herdr_prompts | grep '^w2:p3' | grep -c '重試收尾')" == 2 ]]; check "a delivered finish retry is sent once per blocked record" || { herdr_prompts | grep '^w2:p3' | cut -c1-60; }
  # codex-herdr-r05 (r01/F-03): two overlapping handoff-finish runs submit the retry for one blocked record once
  herdr_loop "$tmp/herdr-r5a" h41; hw "$HL" --role review --status done --verdict pass --head HEAD --report r.md
  finish_in "$HL" add-export >/dev/null 2>&1; commit_in "$HL" archive; hw "$HL" --role finish --status blocked --head HEAD --note "push rejected"
  echo 2 > "$(HS)/prompt-delay"
  finish_in "$HL" add-export > "$tmp/r5-1.out" 2>&1 & p1=$!; sleep 0.5
  finish_in "$HL" add-export > "$tmp/r5-2.out" 2>&1 & p2=$!; wait "$p1"; r1=$?; wait "$p2"; r2=$?; rm -f "$(HS)/prompt-delay"
  [[ "$(herdr_prompts | grep '^w2:p3' | grep -c '重試收尾')" == 1 && "$r1" == 0 && "$r2" == 0 ]] && grep -q 'already sent' "$tmp/r5-2.out"; check "two overlapping handoff-finish runs submit the retry for one blocked record once (codex-herdr-r05, r01/F-03)" || { cat "$tmp/r5-1.out" "$tmp/r5-2.out" | grep -v warn; }
  herdr_loop "$tmp/herdr-r5b" h42; hw "$HL" --role review --status done --verdict pass --head HEAD --report r.md
  finish_in "$HL" add-export >/dev/null 2>&1; commit_in "$HL" archive; hw "$HL" --role finish --status blocked --head HEAD --note "push rejected"
  touch "$(HS)/blocked"; finish_in "$HL" add-export >/dev/null 2>&1; rc1=$?; rm -f "$(HS)/blocked"; finish_in "$HL" add-export >/dev/null 2>&1; rc2=$?
  [[ "$rc1" != 0 && "$rc2" == 0 && "$(herdr_prompts | grep '^w2:p3' | grep -c '重試收尾')" == 1 ]]; check "a finish retry herdr did not send (a dialog) can be retried once the dialog is answered"
  # codex-herdr-r06/F-01: a claim that cannot be created is an error, not "already sent"
  MKF="$tmp/mkdir-fail-bin"; mkdir -p "$MKF"
  printf '#!/usr/bin/env bash\nfor last; do :; done\nif [[ -e "$FAKE_XIRP_DIR/mkdir-fail" && "$last" == *.finish-retry-* ]]; then echo "mkdir: $last: Permission denied" >&2; exit 1; fi\nexec /bin/mkdir "$@"\n' > "$MKF/mkdir"; chmod +x "$MKF/mkdir"
  herdr_loop "$tmp/herdr-r6a" h51; hw "$HL" --role review --status done --verdict pass --head HEAD --report r.md
  finish_in "$HL" add-export >/dev/null 2>&1; commit_in "$HL" archive; hw "$HL" --role finish --status blocked --head HEAD --note "push rejected"
  touch "$FAKE_XIRP_DIR/mkdir-fail"; out="$(PF_PATH="$MKF:$FAKES:$PATH" finish_in "$HL" add-export 2>&1)"; rc=$?; rm -f "$FAKE_XIRP_DIR/mkdir-fail"
  n1="$(herdr_prompts | grep '^w2:p3' | grep -c '重試收尾')"
  out2="$(finish_in "$HL" add-export 2>&1)"; rc2=$?
  [[ "$rc" != 0 && "$n1" == 0 && "$rc2" == 0 && "$(herdr_prompts | grep '^w2:p3' | grep -c '重試收尾')" == 1 ]] && grep -q 'Permission denied' <<<"$out" && ! grep -q 'already sent' <<<"$out"; check "a finish retry claim that cannot be created fails, sends nothing, and can be retried (codex-herdr-r06/F-01)" || { printf '       %s\n' "$out" | grep -v warn; }
  # r03/F-01: a manual run does not name whoever ran it as the stopping session
  herdr_loop "$tmp/herdr-r4c" h33; commit_in "$HL" two; hw "$HL" --role implement --status done --head HEAD
  (cd "$HL" && PATH="$FAKES:$PATH" HANDOFF_NOTIFY="$FAKES/notify.sh" HANDOFF_CREATE_WAIT=2 HERDR_ENV=1 HERDR_PANE_ID=w1:p9 CHIRP_SESSION_ID=chirp-inherited "$ROUTE" --foreground </dev/null)
  grep -q '02-implement.yaml action=reviewer:messaged:w2:p2 session=unknown trigger=herdr:w1:p9 model=opus(template)' "$HL/.agent-handoff/add-export/routing.log"; check "a manual run logs the stopping session as unknown and names who ran it separately (codex-herdr-r04, r03/F-01)" || { tail -1 "$HL/.agent-handoff/add-export/routing.log"; }
  Q3="$tmp/herdr-busy"; herdr_project "$Q3"; fresh_state h3; echo 1 > "$(HS)/busy"
  printf '%s\n' "{\"workspace_id\":\"w9\",\"label\":\"repo\",\"worktree\":{\"checkout_path\":\"$Q3\"}}" > "$(HS)/workspaces"
  out="$(start_in "$Q3" add-export --impl codex:gpt-x:low 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(herdr_calls | grep -c 'agent start')" == 2 ]] && ! herdr_calls | grep -q 'workspace create' && herdr_calls | grep -qF 'worktree open --workspace w9 ' \
    && herdr_calls | grep 'agent start' | tail -1 | grep -qE -- '--kind codex --pane w1:p1 -- -m gpt-x -c model_reasoning_effort=low$'; check "an open repository workspace is reused, and a busy new pane is retried" || { printf '       %s\n' "$out"; herdr_calls | sed 's/^/       /'; }
  Q4="$tmp/herdr-here"; herdr_project "$Q4"; fresh_state h4; git -C "$Q4" switch -q feature/add-export
  out="$(start_in "$Q4" add-export --worktree here 2>&1)"; rc=$?; q4l="$Q4/.agent-handoff/add-export/loop.yaml"
  [[ "$rc" == 0 && "$(kv_get "$q4l" implementer.session)" == w1:p2 && "$(kv_get "$q4l" implementer.herdr_tab)" == w1:t2 && -z "$(kv_get "$q4l" herdr.workspaces 2>/dev/null)" ]] \
    && ! herdr_calls | grep -q 'worktree open' && herdr_calls | grep -qF "tab create --workspace w1 --cwd $Q4 --label claude - impl - add-export --no-focus"; check "an implementer in the main worktree opens a tab in the repository workspace" || { printf '       %s\n' "$out"; herdr_calls | sed 's/^/       /'; }
  # Replacing a herdr reviewer closes only its tab: the workspace also holds the implementer.
  Q9="$tmp/herdr-replace"; herdr_project "$Q9"; fresh_state h9; Q9W="$Q9-add-export"; q9l="$Q9W/.agent-handoff/add-export/loop.yaml"
  start_in "$Q9" add-export >/dev/null 2>&1; commit_in "$Q9W" impl; hw "$Q9W" --role implement --status done --head HEAD; route_in "$Q9W" >/dev/null 2>&1
  wrpt "$Q9W"; hw "$Q9W" --role review --status done --verdict changes-required --head HEAD --report r.md
  out="$(role_in "$Q9W" add-export review codex:gpt-6.2-sol:high --replace 2>&1)"; rc=$?
  [[ "$rc" == 0 && -z "$(kv_get "$q9l" reviewer.session)" && -z "$(kv_get "$q9l" reviewer.herdr_tab)" && -z "$(kv_get "$q9l" reviewer.native_session)" ]] \
    && grep -q '^tab close w2:t2 ' "$(HS)/closed" 2>/dev/null && ! grep -q '^workspace close' "$(HS)/closed"; check "replacing a herdr reviewer closes only its tab and clears its session" || { printf '       %s\n' "$out"; cat "$(HS)/closed" 2>/dev/null | sed 's/^/       /'; }
  Q10="$tmp/herdr-replace-other"; herdr_project "$Q10"; fresh_state h10; Q10W="$Q10-add-export"; q10l="$Q10W/.agent-handoff/add-export/loop.yaml"
  start_in "$Q10" add-export >/dev/null 2>&1; commit_in "$Q10W" impl; hw "$Q10W" --role implement --status done --head HEAD; route_in "$Q10W" >/dev/null 2>&1
  wrpt "$Q10W"; hw "$Q10W" --role review --status done --verdict changes-required --head HEAD --report r.md
  printf 'other-session\n' > "$(HS)/native-w2:p2"; s0="$(cksum < "$q10l")"
  out="$(role_in "$Q10W" add-export review codex:gpt-6.2-sol:high --replace 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(cksum < "$q10l")" == "$s0" && ! -s "$(HS)/closed" ]] && grep -q 'native' <<<"$out"; check "a herdr reviewer pane that now runs another session is not closed (codex-role-review-r01/F-02)" || { printf '       %s\n' "$out"; }
  rm -f "$(HS)/native-w2:p2"; lset "$q10l" reviewer.herdr_tab ""; s0="$(cksum < "$q10l")"
  out="$(role_in "$Q10W" add-export review codex:gpt-6.2-sol:high --replace 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(cksum < "$q10l")" == "$s0" && ! -s "$(HS)/closed" ]] && grep -q 'tab' <<<"$out"; check "a herdr reviewer without a recorded tab is not closed (codex-role-review-r01/F-02)" || { printf '       %s\n' "$out"; }
  # codex-role-review-r02/F-03: a prompt herdr did not confirm is not sent again by a retry.
  Q12="$tmp/herdr-replace-unconfirmed"; herdr_project "$Q12"; fresh_state h12; Q12W="$Q12-add-export"; q12l="$Q12W/.agent-handoff/add-export/loop.yaml"
  start_in "$Q12" add-export >/dev/null 2>&1; commit_in "$Q12W" impl; hw "$Q12W" --role implement --status done --head HEAD; route_in "$Q12W" >/dev/null 2>&1
  touch "$(HS)/prompt-timeout"
  out="$(role_in "$Q12W" add-export review codex:gpt-6.2-sol:high --replace 2>&1)"; rc=$?
  rm -f "$(HS)/prompt-timeout"; np="$(kv_get "$q12l" reviewer.session)"
  routed "$Q12W" 01-implement.yaml; r1=$?; held=0; [[ -f "$Q12W/.agent-handoff/add-export/reviewer-unconfirmed.txt" ]] && held=1
  rm -f "$Q12W/.agent-handoff/add-export/reviewer-unconfirmed.txt"
  (cd "$Q12W" && PATH="$FAKES:$PATH" HANDOFF_NOTIFY="$FAKES/notify.sh" CLAUDE_PROJECT_DIR="$Q12W" "$ROUTE" --foreground </dev/null >/dev/null 2>&1)
  [[ "$rc" != 0 && "$r1" == 0 && "$held" == 1 && -n "$np" && "$(herdr_prompts | grep -c "^$np"$'\t')" == 1 ]] && grep -q 'unconfirmed' <<<"$out"; check "a replacement whose new prompt herdr did not confirm is not sent again (codex-role-review-r02/F-03)" || { printf '       %s\n' "$out"; }
  Q11="$tmp/herdr-fin-replace"; herdr_project "$Q11"; fresh_state h11; Q11W="$Q11-add-export"; q11l="$Q11W/.agent-handoff/add-export/loop.yaml"
  start_in "$Q11" add-export >/dev/null 2>&1; commit_in "$Q11W" impl; hw "$Q11W" --role implement --status done --head HEAD
  wrpt "$Q11W"; hw "$Q11W" --role review --status done --verdict pass --head HEAD --report r.md
  touch "$(HS)/prompt-timeout"; finish_in "$Q11W" add-export >/dev/null 2>&1; rm -f "$(HS)/prompt-timeout"; fp="$(kv_get "$q11l" finish.session)"
  out="$(role_in "$Q11W" add-export finish codex:gpt-6.2-sol:high --replace 2>&1)"; rc=$?
  np="$(kv_get "$q11l" finish.session)"
  [[ -n "$fp" && "$rc" == 0 && -n "$np" && "$np" != "$fp" && ! -e "$Q11W/.agent-handoff/add-export/finish-unconfirmed.txt" \
    && "$(herdr_prompts | grep -c "^$np"$'\t')" == 1 ]] && grep -q '^tab close' "$(HS)/closed"; check "replacing a finish role whose prompt herdr did not confirm opens the new one with one prompt (codex-role-review-r01/F-05)" || { printf '       %s\n' "$out"; }

  # codex-extract-handoff-r01/F-02: the agent's arguments reach herdr whole, or the agent is not started
  Q12="$tmp/herdr-argv"; herdr_project "$Q12"; fresh_state h-argv; q12l="$Q12-add-export/.agent-handoff/add-export/loop.yaml"
  start_in "$Q12" add-export >/dev/null 2>&1
  [[ "$(cat "$(HS)/argv-w2:p1" 2>/dev/null)" == '["--model","opus","--effort","high","--name","claude - impl - add-export"]' ]]; check "a name with spaces reaches herdr as one argument (codex-extract-handoff-r01/F-02)" || { cat "$(HS)/argv-w2:p1"; }
  Q13="$tmp/herdr-argv-fail"; herdr_project "$Q13"; fresh_state h-argv-fail; q13l="$Q13-add-export/.agent-handoff/add-export/loop.yaml"
  JQS="$tmp/jq-cut"; mkdir -p "$JQS"
  # jq that stops part-way through decoding the arguments (two lines, then exit 42); every other call is the real jq.
  printf '#!/usr/bin/env bash\nif [[ "$*" == "-r .[1:][]" ]]; then printf "%%s\\n" --model opus; exit 42; fi\nexec %q "$@"\n' "$(command -v jq)" > "$JQS/jq"; chmod +x "$JQS/jq"
  out="$(PF_PATH="$JQS:$FAKES:$PATH" start_in "$Q13" add-export 2>&1)"; rc=$?
  [[ "$rc" != 0 && "$(kv_get "$q13l" implementer.pending_prompt 2>/dev/null)" == true ]] && grep -q 'pane is kept' <<<"$out" \
    && ! herdr_calls | grep -q 'agent start\|agent prompt'; check "arguments that cannot be decoded in full start no agent and keep the pane for a retry (codex-extract-handoff-r01/F-02)" || { printf '       %s\n' "$out"; herdr_calls | sed 's/^/       /'; }

finish_section herdr
