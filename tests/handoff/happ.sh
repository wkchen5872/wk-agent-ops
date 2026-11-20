#!/usr/bin/env bash
# Handoff test section "happ". Run: bash tests/test_agent_handoff.sh happ
# shellcheck source=tests/handoff/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

  printf 'herdr-app host\n'
  source "$KV"
  # 1.3 environment checks
  AD="$tmp/happ-doc"; happ_project "$AD"; fresh_state a1; ADR="$AD/.agent-handoff/roles.yaml"
  out="$(pf "$AD" "$ADR" implement review finish)"; rc=$?
  [[ "$rc" == 0 ]] && grep -q '^ok host implement, review, finish: .*Herdr app.*herdr-core 0.1.21' <<<"$out" && ! grep -q 'xirp\|^ok host .*herdr 0.9' <<<"$out"; check "a herdr-app loop checks the Herdr app and herdr-core, shows the core version, and not Xirp or herdr" || { printf '       %s\n' "$out"; }
  touch "$(HA)/app-closed"; out="$(pf "$AD" "$ADR" implement review finish)"; rc=$?
  [[ "$rc" != 0 ]] && grep -q '^fail host .*Herdr app is not open.*open' <<<"$out"; check "a closed Herdr app fails the host check and asks to open it" || { printf '       %s\n' "$out"; }
  out="$(start_in "$AD" add-export 2>&1)"; rc=$?
  [[ "$rc" != 0 && ! -e "$AD-add-export" && -z "$(happ_do space.new)$(happ_do tab.new)" && "$(created)" == 0 ]] && grep -q 'handoff-start: fail host .*Herdr app' <<<"$out"; check "handoff-start refuses while the Herdr app is closed and opens no session on any host" || { printf '       %s\n' "$out"; }
  rm -f "$(HA)/app-closed"; touch "$(HC)/core-down"; out="$(pf "$AD" "$ADR" implement review finish)"; rc=$?
  [[ "$rc" != 0 ]] && grep -q '^fail host .*herdr-core is not running' <<<"$out"; check "herdr-core that is not running fails the host check" || { printf '       %s\n' "$out"; }
  rm -f "$(HC)/core-down"
  # codex-herdr-app-r01/F-03: a status that exits non-zero fails even when it prints JSON
  touch "$(HA)/status-fail-json"; out="$(pf "$AD" "$ADR" implement review finish)"; rc=$?; sout="$(start_in "$AD" add-export 2>&1)"; src=$?
  [[ "$rc" != 0 && "$src" != 0 && ! -e "$AD-add-export" && -z "$(happ_do space.new)$(happ_do tab.new)" ]] && grep -q '^fail host .*Herdr app is not open' <<<"$out"; check "a Herdr app status that exits non-zero fails the host check even with JSON, and start opens nothing (codex-herdr-app-r01/F-03)" || { printf '       %s\n' "$out" "$sout"; }
  rm -f "$(HA)/status-fail-json"
  out="$(PF_PATH="$(path_without herdr-app)" pf "$AD" "$ADR" implement review finish)"; rc=$?
  [[ "$rc" != 0 ]] && grep -q '^fail host .*herdr-app command was not found' <<<"$out"; check "a missing herdr-app command fails the host check and names it" || { printf '       %s\n' "$out"; }
  out="$(PF_PATH="$(path_without hc)" pf "$AD" "$ADR" implement review finish)"; rc=$?
  [[ "$rc" != 0 ]] && grep -q '^fail host .*hc command .*not found' <<<"$out"; check "a missing hc command fails the host check and names it" || { printf '       %s\n' "$out"; }
  # 1.1 host value
  AV="$tmp/happ-value"; happ_project "$AV"; fresh_state a2; out="$(start_in "$AV" add-export 2>&1)"; rc=$?; avl="$AV-add-export/.agent-handoff/add-export/loop.yaml"
  [[ "$rc" == 0 && "$(kv_get "$avl" implement_template.host)" == herdr-app && "$(kv_get "$avl" review_template.host)" == herdr-app \
    && "$(kv_get "$avl" finish_template.host)" == herdr-app && ! -s "$FAKE_XIRP_DIR/herdr/calls" && "$(created)" == 0 ]]; check "host: herdr-app is recorded for every role and no herdr TUI or Xirp command is used" || { printf '       %s\n' "$out"; }
  # 2.1 opening
  c="$(happ_do space.new)"; AW="$AV-add-export"
  [[ "$(happ_opt "$c" name)" == add-export && "$(happ_opt "$c" folder)" == "$AW" && "$(happ_opt "$c" tab)" == "claude - impl - add-export" \
    && "$(happ_opt "$c" focus)" == false && "$(happ_opt "$c" argv)" == '["claude","--model","opus","--effort","high","--name","claude - impl - add-export"]' ]] \
    && happ_opt "$c" task | grep -q 'openspec-apply-change add-export'; check "the implementer opens a space named after the change, with Claude's argv, the prompt as its task and no focus" || { printf '       %s\n' "$c"; }
  [[ "$(kv_get "$avl" implementer.session)" == t1 && "$(kv_get "$avl" implementer.happ_space)" == sp1 && "$(kv_get "$avl" implementer.happ_tab)" == tb1 \
    && "$(kv_get "$avl" herdr_app.spaces)" == sp1 && "$(kv_get "$avl" implementer.pending_prompt 2>/dev/null)" != true && ! -e "$AW/.agent-handoff/add-export/implementer-unconfirmed.txt" ]]; check "loop.yaml records the terminal, space, tab and the space the loop opened" || { cat "$avl"; }
  wrpt "$AW"; commit_in "$AW" impl; hw "$AW" --role implement --status done --head HEAD; route_in "$AW"; c="$(happ_do tab.new)"
  [[ "$(happ_opt "$c" space)" == sp1 && "$(happ_opt "$c" name)" == "codex - review - add-export" && "$(happ_opt "$c" focus)" == false \
    && "$(happ_opt "$c" argv)" == '["codex","-m","gpt-6.1-sol","-c","model_reasoning_effort=high"]' && "$(kv_get "$avl" reviewer.session)" == t2 \
    && "$(kv_get "$avl" herdr_app.spaces)" == sp1 && "$(happ_do space.new | wc -l | tr -d ' ')" == 1 ]] && happ_opt "$c" task | grep -q 'change-review add-export' && routed "$AW" 01-implement.yaml; check "a shared reviewer opens as a tab in the loop's space with Codex's argv" || { printf '       %s\n' "$c"; cat "$AW/.agent-handoff/add-export/routing.log"; }
  # 3.1 messages
  hw "$AW" --role review --status done --verdict changes-required --head HEAD --report r.md; route_in "$AW"
  hc_sends | grep -q $'^t1\t.*changes-required' && routed "$AW" 02-review.yaml; check "changes-required is sent to the implementer's idle terminal and the record is processed" || { hc_sends; tail -1 "$AW/.agent-handoff/add-export/routing.log"; }
  # 3.2 the routing log names the stopping terminal
  grep -q '02-review.yaml action=implementer:messaged:t1 session=chirp-1 model=gpt-6.1-sol(template)' "$AW/.agent-handoff/add-export/routing.log"; check "without HC_TERMINAL_ID the routing log names the session as before, with the herdr-app role's template model" || { tail -1 "$AW/.agent-handoff/add-export/routing.log"; }
  commit_in "$AW" two; hw "$AW" --role implement --status done --head HEAD
  (cd "$AW" && printf '{"session_id":"native-1"}' | PATH="$FAKES:$PATH" HANDOFF_NOTIFY="$FAKES/notify.sh" HANDOFF_CREATE_WAIT=2 HANDOFF_ROUTE_WAIT=1 \
    HC_TERMINAL_ID=t1 CHIRP_SESSION_ID=chirp-inherited "$ROUTE")
  grep -q '03-implement.yaml action=reviewer:messaged:t2 session=herdr-app:t1 native=native-1 model=opus(template)' "$AW/.agent-handoff/add-export/routing.log" \
    && ! grep -q chirp-inherited "$AW/.agent-handoff/add-export/routing.log" && hc_sends | grep -q $'^t2\t.*第 2 輪'; check "with HC_TERMINAL_ID the routing log names herdr-app:<terminal>, never an inherited Xirp ID" || { tail -1 "$AW/.agent-handoff/add-export/routing.log"; }
  # blocked: nothing is answered, one notice, the record stays unprocessed
  commit_in "$AW" three; hw "$AW" --role implement --status done --head HEAD; touch "$(HC)/blocked"; ns="$(hc_sends | wc -l)"; nn="$(ncount)"
  route_in "$AW"; route_in "$AW"
  [[ "$(hc_sends | wc -l)" == "$ns" && "$(ncount)" == $((nn + 1)) ]] && ! routed "$AW" 04-implement.yaml && ! grep -q -- '--force' "$(HC)/calls" \
    && jt '.kind=="attention" and (.detail|test("permission")) and (.detail|test("add-export")) and (.detail|test("codex - review - add-export"))'; check "a reviewer at a permission dialog gets no text, one notice naming its space and tab, and the record stays unprocessed" || { jl | tail -1; }
  rm -f "$(HC)/blocked"; (cd "$AW" && PATH="$FAKES:$PATH" HANDOFF_NOTIFY="$FAKES/notify.sh" HANDOFF_CREATE_WAIT=2 "$ROUTE" --foreground </dev/null)
  [[ "$(hc_sends | grep -c $'^t2\t.*第 3 輪')" == 1 ]] && routed "$AW" 04-implement.yaml; check "after the dialog is answered a foreground retry sends the round once"
  # a terminal that has finished: delivery fails, nothing is sent
  commit_in "$AW" four; hw "$AW" --role implement --status done --head HEAD; touch "$(HC)/finished-t2"; ns="$(hc_sends | wc -l)"
  route_in "$AW"
  [[ "$(hc_sends | wc -l)" == "$ns" ]] && ! routed "$AW" 05-implement.yaml && grep -q '05-implement.yaml action=reviewer:send-failed:t2' "$AW/.agent-handoff/add-export/routing.log"; check "a reviewer terminal that has finished gets no text and the delivery fails" || { tail -1 "$AW/.agent-handoff/add-export/routing.log"; }
  rm -f "$(HC)/finished-t2"; touch "$(HC)/shell-t2"; route_in "$AW"
  [[ "$(hc_sends | wc -l)" == "$ns" ]] && ! routed "$AW" 05-implement.yaml; check "a reviewer terminal that now runs a shell gets no text, even with the agent's stale idle status (codex-herdr-app-r01/F-02)"
  rm -f "$(HC)/shell-t2"; touch "$(HC)/no-status"; route_in "$AW"; rm -f "$(HC)/no-status"
  [[ "$(hc_sends | wc -l)" == "$ns" ]] && ! routed "$AW" 05-implement.yaml; check "a reviewer that reports no status gets no text, since idle cannot be confirmed (codex-herdr-app-r01/F-02)"
  # started:false: kept unconfirmed, never resent
  rm -f "$(HC)/shell-t2"; touch "$(HC)/send-unstarted"; ns="$(hc_sends | wc -l)"
  (cd "$AW" && PATH="$FAKES:$PATH" HANDOFF_NOTIFY="$FAKES/notify.sh" HANDOFF_CREATE_WAIT=2 "$ROUTE" --foreground </dev/null); route_in "$AW"; rm -f "$(HC)/send-unstarted"
  (( $(hc_sends | wc -l) == ns + 1 )) && routed "$AW" 05-implement.yaml && grep -q '第 4 輪' "$AW/.agent-handoff/add-export/reviewer-unconfirmed.txt" 2>/dev/null; check "a send that did not start a turn is kept in an unconfirmed file and not sent again" || { tail -2 "$AW/.agent-handoff/add-export/routing.log"; }
  # first prompt not observed: unconfirmed, one notice, not resent
  happ_project "$tmp/happ-nostart"; fresh_state a3; start_in "$tmp/happ-nostart" add-export >/dev/null 2>&1; NW="$tmp/happ-nostart-add-export"
  commit_in "$NW" impl; hw "$NW" --role implement --status done --head HEAD; touch "$(HC)/no-start"; nn="$(ncount)"
  route_in "$NW"; route_in "$NW"
  [[ "$(happ_do tab.new | wc -l | tr -d ' ')" == 1 && "$(ncount)" == $((nn + 1)) && "$(kv_get "$NW/.agent-handoff/add-export/loop.yaml" reviewer.session)" == t2 ]] \
    && grep -q 'change-review add-export' "$NW/.agent-handoff/add-export/reviewer-unconfirmed.txt" 2>/dev/null && routed "$NW" 01-implement.yaml && jt '.kind=="attention"'; check "a first prompt with no started turn is kept unconfirmed with one notice and not resent" || { cat "$NW/.agent-handoff/add-export/routing.log"; }
  # codex-herdr-app-r01/F-04: handoff-start whose implementer prompt is not observed sends one notice and never resends
  happ_project "$tmp/happ-nostart-impl"; fresh_state a3b; touch "$(HC)/no-start"
  out="$(HANDOFF_NOTIFY="$FAKES/notify.sh" start_in "$tmp/happ-nostart-impl" add-export 2>&1)"; rc=$?
  HANDOFF_NOTIFY="$FAKES/notify.sh" start_in "$tmp/happ-nostart-impl" add-export >/dev/null 2>&1
  [[ -f "$tmp/happ-nostart-impl-add-export/.agent-handoff/add-export/implementer-unconfirmed.txt" && "$(ncount)" == 1 && "$(happ_do space.new | wc -l | tr -d ' ')" == 1 && ! -s "$(HC)/sends" ]] \
    && jt '.kind=="attention" and (.detail|test("implementer")) and (.detail|test("t1")) and (.next|test("implementer-unconfirmed.txt"))'; check "an implementer first prompt handoff-start cannot confirm gets one attention notice and is not resent (codex-herdr-app-r01/F-04)" || { printf '       %s\n' "$out"; jl | tail -1; }
  # codex-herdr-app-r02 (r01/F-04): after the start dialog is answered, a retry whose prompt is still not observed notifies once
  happ_project "$tmp/happ-nostart-retry"; fresh_state a3c; touch "$(HC)/blocked" "$(HC)/no-start"; rl3="$tmp/happ-nostart-retry-add-export/.agent-handoff/add-export"
  HANDOFF_NOTIFY="$FAKES/notify.sh" start_in "$tmp/happ-nostart-retry" add-export >/dev/null 2>&1; rc1=$?; n1="$(ncount)"; p1="$(kv_get "$rl3/loop.yaml" implementer.pending_prompt)"
  rm -f "$(HC)/blocked"; out="$(HANDOFF_NOTIFY="$FAKES/notify.sh" start_in "$tmp/happ-nostart-retry" add-export 2>&1)"; rc2=$?
  [[ "$rc1" != 0 && "$p1" == true && "$n1" == 0 && "$rc2" == 0 && "$(ncount)" == 1 && -f "$rl3/implementer-unconfirmed.txt" && "$(kv_get "$rl3/loop.yaml" implementer.session)" == t1 \
    && "$(happ_do space.new | wc -l | tr -d ' ')" == 1 && -z "$(happ_do tab.new)" && ! -s "$(HC)/sends" ]] && jt '.kind=="attention" and (.next|test("implementer-unconfirmed.txt"))'; check "a handoff-start retry after the dialog whose prompt is still not observed keeps the terminal and notifies once (codex-herdr-app-r02, r01/F-04)" || { printf '       %s\n' "rc1=$rc1 p1=$p1 n1=$n1 rc2=$rc2 n=$(ncount)" "$out"; }
  # first prompt waits on a dialog: the tab is kept, one notice names it, a retry opens nothing new
  happ_project "$tmp/happ-dialog"; fresh_state a4; start_in "$tmp/happ-dialog" add-export >/dev/null 2>&1; BW="$tmp/happ-dialog-add-export"; bwl="$BW/.agent-handoff/add-export/loop.yaml"
  commit_in "$BW" impl; hw "$BW" --role implement --status done --head HEAD; touch "$(HC)/blocked"
  route_in "$BW"; route_in "$BW"
  [[ "$(ncount)" == 1 && "$(kv_get "$bwl" reviewer.session)" == t2 && "$(kv_get "$bwl" reviewer.pending_prompt)" == true ]] && ! routed "$BW" 01-implement.yaml \
    && jt '.kind=="attention" and (.detail|test("add-export")) and (.detail|test("codex - review - add-export")) and (.next|test("handoff-route --foreground"))'; check "a reviewer whose first prompt waits on a dialog keeps its tab and gets one notice naming its space and tab" || { jl | tail -1; }
  rm -f "$(HC)/blocked"; touch "$(HC)/get-unavailable"; (cd "$BW" && PATH="$FAKES:$PATH" HANDOFF_NOTIFY="$FAKES/notify.sh" HANDOFF_CREATE_WAIT=2 "$ROUTE" --foreground </dev/null)
  rm -f "$(HC)/get-unavailable"
  [[ "$(happ_do tab.new | wc -l | tr -d ' ')" == 1 && "$(kv_get "$bwl" reviewer.session)" == t2 && "$(kv_get "$bwl" reviewer.pending_prompt)" == true ]] && ! routed "$BW" 01-implement.yaml; check "a waiting reviewer whose terminal hc cannot report on keeps its tab and no second one opens (codex-herdr-app-r01/F-05)" || { cat "$BW/.agent-handoff/add-export/routing.log"; }
  (cd "$BW" && PATH="$FAKES:$PATH" HANDOFF_NOTIFY="$FAKES/notify.sh" HANDOFF_CREATE_WAIT=2 "$ROUTE" --foreground </dev/null)
  [[ "$(happ_do tab.new | wc -l | tr -d ' ')" == 1 && -z "$(kv_get "$bwl" reviewer.pending_prompt)" && ! -s "$(HC)/sends" ]] && routed "$BW" 01-implement.yaml; check "after the dialog a retry takes the handed prompt as delivered without opening or sending again" || { cat "$BW/.agent-handoff/add-export/routing.log"; }
  # a reviewer with a worktree of its own opens its own space
  happ_project "$tmp/happ-new"; awk '/^review:/{print; print "  worktree: new"; next} /^  worktree: shared/ && r==0 {r=1; next} {print}' "$tmp/happ-new/.agent-handoff/roles.yaml" > "$tmp/r.tmp"
  cp "$tmp/r.tmp" "$tmp/happ-new/.agent-handoff/roles.yaml"; fresh_state a5; start_in "$tmp/happ-new" add-export >/dev/null 2>&1; EW="$tmp/happ-new-add-export"
  commit_in "$EW" impl; hw "$EW" --role implement --status done --head HEAD; route_in "$EW"; c="$(happ_do space.new | tail -1)"
  [[ "$(happ_opt "$c" name)" == "add-export review" && "$(happ_opt "$c" folder)" == "$EW-review" && "$(happ_opt "$c" tab)" == "codex - review - add-export" \
    && -z "$(happ_do tab.new)" && "$(kv_get "$EW/.agent-handoff/add-export/loop.yaml" herdr_app.spaces)" == "sp1 sp2" ]]; check "a reviewer with worktree new opens a space of its own" || { printf '       %s\n' "$c"; cat "$EW/.agent-handoff/add-export/loop.yaml"; }
  # mixed hosts: implementer on Xirp, reviewer on the Herdr app
  MA="$tmp/happ-mixed"; new_loop "$MA"; use_project "$MA"; fresh_state a6; rpt "$MA"; mal="$MA/.agent-handoff/add-export/loop.yaml"; lset "$mal" review_template.host herdr-app
  hw "$MA" --role implement --status done --head HEAD; route_in "$MA"
  hw "$MA" --role review --status done --verdict changes-required --head HEAD --report r.md; route_in "$MA"
  commit_in "$MA" two; hw "$MA" --role implement --status done --head HEAD; route_in "$MA"
  [[ "$(created)" == 0 && "$(kv_get "$mal" reviewer.session)" == t1 ]] && msgs | grep -q $'^impl-1\t.*changes-required' && hc_sends | grep -q $'^t1\t.*第 2 輪' \
    && [[ "$(happ_opt "$(happ_do space.new)" name)" == add-export ]]; check "with the implementer on Xirp and the reviewer on the Herdr app, each message goes through its receiver's CLI" || { msgs; hc_sends; }
  # 4.1 cleanup
  happ_loop "$tmp/happ-clean" a7; hw "$AL" --role review --status done --verdict pass --head HEAD --report r.md; hw "$AL" --role finish --status done --head HEAD
  out="$(hclean "$tmp/happ-clean" add-export 2>&1)"; rc=$?
  [[ "$rc" == 0 && ! -s "$(HA)/closed" ]] && grep -q 'herdr-app space sp1' <<<"$out" && [[ "$(grep -c 'herdr-app ' <<<"$out")" == 1 ]]; check "the cleanup preview lists the Herdr app space the loop opened, once, and closes nothing" || { printf '       %s\n' "$out"; }
  touch "$(HA)/app-closed"; out="$(hclean "$tmp/happ-clean" add-export --yes 2>&1)"; rc=$?
  [[ "$rc" != 0 && -d "$AL" && -f "$ALL" && ! -s "$(HA)/closed" ]] && grep -q 'Herdr app' <<<"$out"; check "cleanup with the Herdr app closed fails, asks to open it and removes no worktree" || { printf '       %s\n' "$out"; }
  rm -f "$(HA)/app-closed"; out="$(hclean "$tmp/happ-clean" add-export --yes 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(cat "$(HA)/closed" 2>/dev/null)" == "space.close sp1 exists=yes" && ! -e "$AL" ]] && git -C "$tmp/happ-clean" show-ref -q --verify refs/heads/feature/add-export \
    && [[ "$(sort "$(HC)/removed" 2>/dev/null | paste -sd, -)" == "t1,t2" ]] && happ_do space.close | grep -q '"--confirmed","true"'; check "cleanup closes the loop's space before removing the worktree, removes its terminals and keeps the branch" || { printf '       %s\n' "$out"; cat "$(HA)/closed" "$(HC)/removed" 2>/dev/null; }
  # only what the loop opened: a role in a space the loop did not open closes only its tab; a reused terminal is left alone
  happ_loop "$tmp/happ-other" a8
  printf 'spU\tmine\t%s\n' "$tmp" >> "$(HA)/spaces"; awk -F'\t' -v OFS='\t' '$1 == "tb2" {$2 = "spU"} {print}' "$(HA)/tabs" > "$tmp/t.tmp" && cat "$tmp/t.tmp" > "$(HA)/tabs"
  lset "$ALL" reviewer.happ_space spU
  out="$(hclean "$tmp/happ-other" add-export --abandon --yes 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(sort "$(HA)/closed" | paste -sd, -)" == "space.close sp1 exists=yes,tab.close tb2 exists=yes" ]] && grep -q $'^spU\t' "$(HA)/spaces"; check "a role in a space the loop did not open has only its tab closed" || { printf '       %s\n' "$out"; cat "$(HA)/closed"; }
  # codex-herdr-app-r02/F-01: a reviewer reopened after its waiting terminal finished leaves nothing behind
  # stale_loop <dir> <state>: the reviewer stopped at a dialog in t2/tb2, t2 finished, and the retry opened t3/tb3
  stale_loop() {  # [new]: the review role has a worktree of its own, so the reopened reviewer opens a second space
    happ_project "$1"; fresh_state "$2"
    if [[ "${3:-}" == new ]]; then
      awk '/^review:/{print; print "  worktree: new"; next} /^  worktree: shared/ && r==0 {r=1; next} {print}' "$1/.agent-handoff/roles.yaml" > "$1/r.tmp" && mv "$1/r.tmp" "$1/.agent-handoff/roles.yaml"
    fi
    start_in "$1" add-export >/dev/null 2>&1; AL="$1-add-export"; ALL="$AL/.agent-handoff/add-export/loop.yaml"
    commit_in "$AL" impl; hw "$AL" --role implement --status done --head HEAD; touch "$(HC)/blocked"; route_in "$AL"
    rm -f "$(HC)/blocked"; touch "$(HC)/finished-t2"; (cd "$AL" && PATH="$FAKES:$PATH" HANDOFF_NOTIFY="$FAKES/notify.sh" HANDOFF_CREATE_WAIT=2 "$ROUTE" --foreground </dev/null)
  }
  stale_loop "$tmp/happ-stale" a12; sl="$(kv_get "$ALL" reviewer.session)"
  out="$(hclean "$tmp/happ-stale" add-export --abandon --yes 2>&1)"; rc=$?
  [[ "$sl" == t3 && "$rc" == 0 && "$(cat "$(HA)/closed")" == "space.close sp1 exists=yes" && "$(sort "$(HC)/removed" | paste -sd, -)" == "t1,t2,t3" && ! -e "$AL" ]]; check "cleanup after a reviewer was reopened closes the loop's space with the old tab and removes the old terminal (codex-herdr-app-r02/F-01)" || { printf '       %s\n' "session=$sl" "$out"; cat "$(HA)/closed" "$(HC)/removed" 2>/dev/null; }
  stale_loop "$tmp/happ-stale2" a13; awk -F'\t' '$1 != "tb2"' "$(HA)/tabs" > "$tmp/t.tmp" && cat "$tmp/t.tmp" > "$(HA)/tabs"
  out="$(hclean "$tmp/happ-stale2" add-export --abandon --yes 2>&1)"; rc=$?
  [[ "$rc" == 0 && ! -f "$(HC)/term-t2" && ! -e "$AL" ]] && grep -qx t2 "$(HC)/removed"; check "an old reviewer terminal the app no longer shows is still removed from herdr-core (codex-herdr-app-r02/F-01)" || { printf '       %s\n' "$out"; }
  stale_loop "$tmp/happ-stale3" a14; (cd "$tmp" && PATH="$FAKES:$PATH" herdr-app do tab.new --space sp1 --name mine --argv '["zsh"]' >/dev/null)
  pv="$(hclean "$tmp/happ-stale3" add-export --abandon 2>&1)"; out="$(hclean "$tmp/happ-stale3" add-export --abandon --yes 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(sort "$(HA)/closed" | paste -sd, -)" == "tab.close tb1 exists=yes,tab.close tb2 exists=yes,tab.close tb3 exists=yes" && "$(jq -r .state "$(HC)/term-t4")" == live ]] \
    && grep -q 'herdr-app tab tb2' <<<"$pv" && grep -qx t2 "$(HC)/removed"; check "with a user tab in the loop's space, the reopened reviewer's old tab is listed and closed too, and the user's tab stays (codex-herdr-app-r02/F-01)" || { printf '       %s\n' "$pv" "$out"; cat "$(HA)/closed"; }
  # codex-herdr-app-r03/F-01: the preview lists what an old reviewer in another space closes, and matches what closes
  stale_loop "$tmp/happ-stale4" a15 new; sl="$(kv_get "$ALL" reviewer.session)"; (cd "$tmp" && PATH="$FAKES:$PATH" herdr-app do tab.new --space sp2 --name mine --argv '["zsh"]' >/dev/null)
  pv="$(hclean "$tmp/happ-stale4" add-export --abandon 2>&1)"; out="$(hclean "$tmp/happ-stale4" add-export --abandon --yes 2>&1)"; rc=$?
  want="space.close sp1,space.close sp3,tab.close tb2"
  [[ "$sl" == t3 && "$rc" == 0 && "$(sed 's/ exists=.*//' "$(HA)/closed" | sort | paste -sd, -)" == "$want" \
    && "$(grep '^    herdr-app ' <<<"$pv" | sed 's/^    herdr-app \([a-z]*\) /\1.close /' | sort | paste -sd, -)" == "$want" \
    && "$(jq -r .state "$(HC)/term-t4")" == live ]] && grep -q $'^sp2\t' "$(HA)/spaces" && grep -qx t2 "$(HC)/removed"; check "an old reviewer tab in another space with a user tab is previewed and closed alone (codex-herdr-app-r03/F-01)" || { printf '       %s\n' "$pv" "$out"; cat "$(HA)/closed"; }
  stale_loop "$tmp/happ-stale5" a16 new
  pv="$(hclean "$tmp/happ-stale5" add-export --abandon 2>&1)"; out="$(hclean "$tmp/happ-stale5" add-export --abandon --yes 2>&1)"; rc=$?
  want="space.close sp1,space.close sp2,space.close sp3"
  [[ "$rc" == 0 && "$(sed 's/ exists=.*//' "$(HA)/closed" | sort | paste -sd, -)" == "$want" \
    && "$(grep '^    herdr-app ' <<<"$pv" | sed 's/^    herdr-app \([a-z]*\) /\1.close /' | sort | paste -sd, -)" == "$want" && ! -s "$(HA)/spaces" ]]; check "an old reviewer space holding only loop resources is previewed and closed, leaving no space behind (codex-herdr-app-r03/F-01)" || { printf '       %s\n' "$pv" "$out"; cat "$(HA)/closed"; }
  # codex-herdr-app-r01/F-01: a tab the user added to the loop's space keeps the space and its terminal
  happ_loop "$tmp/happ-user" a10; (cd "$tmp" && PATH="$FAKES:$PATH" herdr-app do tab.new --space sp1 --name mine --argv '["zsh"]' >/dev/null)
  pv="$(hclean "$tmp/happ-user" add-export --abandon 2>&1)"; out="$(hclean "$tmp/happ-user" add-export --abandon --yes 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(sort "$(HA)/closed" | paste -sd, -)" == "tab.close tb1 exists=yes,tab.close tb2 exists=yes" && "$(jq -r .state "$(HC)/term-t3")" == live ]] \
    && grep -q $'^sp1\t' "$(HA)/spaces" && grep -q 'herdr-app tab tb1' <<<"$pv" && ! grep -q 'herdr-app space' <<<"$pv" && [[ ! -e "$AL" ]]; check "a space holding a tab the user added keeps that tab: only the loop's tabs close (codex-herdr-app-r01/F-01)" || { printf '       %s\n' "$pv" "$out"; cat "$(HA)/closed"; }
  happ_loop "$tmp/happ-user2" a11; awk -F'\t' -v OFS='\t' '$1 == "tb2" {$5 = "t99"} {print}' "$(HA)/tabs" > "$tmp/t.tmp" && cat "$tmp/t.tmp" > "$(HA)/tabs"
  out="$(hclean "$tmp/happ-user2" add-export --abandon --yes 2>&1)"; rc=$?
  [[ "$rc" != 0 && -d "$AL" ]] && ! grep -q 'tb2' "$(HA)/closed" 2>/dev/null && grep -q 't99' <<<"$out"; check "a loop tab that also holds a terminal the loop did not open is not closed and the worktree is kept (codex-herdr-app-r01/F-01)" || { printf '       %s\n' "$out"; cat "$(HA)/closed" 2>/dev/null; }
  happ_project "$tmp/happ-reuse"; fresh_state a9; mkdir -p "$(HC)"; jq -n '{address:"t9", state:"live", argv:["codex"], turn:3, labels:{where:"mine / review"}}' > "$(HC)/term-t9"
  out="$(start_in "$tmp/happ-reuse" add-export --reviewer-session t9 2>&1)"; rc=$?
  [[ "$rc" == 0 && "$(kv_get "$tmp/happ-reuse-add-export/.agent-handoff/add-export/loop.yaml" reviewer.session)" == t9 ]]; check "an existing Herdr app terminal running the review harness can be reused as the reviewer" || { printf '       %s\n' "$out"; }
  hclean "$tmp/happ-reuse" add-export --abandon --yes >/dev/null 2>&1
  [[ -f "$(HC)/term-t9" ]] && ! grep -q 't9' "$(HA)/closed" 2>/dev/null; check "cleanup never closes or removes a reused terminal"
  out="$(start_in "$tmp/happ-reuse" add-export --reviewer-session t404 2>&1)"; rc=$?
  [[ "$rc" != 0 ]] && grep -q "t404" <<<"$out"; check "a reviewer terminal that does not exist is refused" || { printf '       %s\n' "$out"; }

finish_section happ
