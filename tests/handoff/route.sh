#!/usr/bin/env bash
# Handoff test section "route". Run: bash tests/test_agent_handoff.sh route
# shellcheck source=tests/handoff/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# ---------------------------------------------------------------- routing hook
  printf 'routing hook\n'
  source "$KV"

  A="$tmp/route-a"; new_loop "$A"; use_project "$A"; fresh_state r1
  route_in "$A"
  [[ "$(created)" == 0 && -z "$(msgs)" && -z "$(notes)" ]]; check "no record: nothing is sent"

  B0="$tmp/route-noloop"; new_repo "$B0"; hw "$B0" --role implement --status done --head HEAD
  route_in "$B0"
  [[ "$(created)" == 0 && -z "$(msgs)" ]]; check "record without loop.yaml: nothing is sent"

  commit_in "$A" one; X="$(git -C "$A" rev-parse HEAD)"; hw "$A" --role implement --status done --head HEAD
  route_in "$A"
  loop="$A/.agent-handoff/add-export/loop.yaml"
  [[ "$(created)" == 1 ]] && jq -e --arg w "$A" '.worktreePath==$w and .customName=="codex - review - add-export" and .agent.agentName=="codex" and .agent.options.model=="gpt-6.1-sol" and .agent.options.reasoning_effort=="high"' "$FAKE_XIRP_DIR/create-1.json" >/dev/null \
    && [[ "$(kv_get "$loop" reviewer.session)" == "sess-1" && "$(kv_get "$loop" reviewer.worktree)" == "$A" ]]; check "first implement handoff opens the reviewer in the shared worktree and records it"
  jq -r .goal "$FAKE_XIRP_DIR/create-1.json" 2>/dev/null | grep -q "commit $X round 1"; check "reviewer prompt names the handed-over commit and round"
  g="$(jq -r .goal "$FAKE_XIRP_DIR/create-1.json" 2>/dev/null)"
  grep -qF 'agent-handoff/scripts/handoff-author --tool Codex --model gpt-6.1-sol' <<<"$g" && ! grep -q '{author}' <<<"$g" && ! grep -q '不要寫 null' <<<"$g"; check "reviewer prompt has it attach the Author block from handoff-author with its tool and template model"
  grep -q 'action=reviewer:opened:sess-1 .*model=' "$A/.agent-handoff/add-export/routing.log" 2>/dev/null; check "routing log records the action and the session's model"
  grep -q 'action=reviewer:opened:sess-1 session=chirp-1 ' "$A/.agent-handoff/add-export/routing.log" 2>/dev/null; check "outside herdr the routing log names the Xirp session"
  route_in "$A"
  [[ "$(created)" == 1 ]]; check "the same record is routed only once"
  HE="$tmp/route-herdr-env"; new_loop "$HE"; use_project "$HE"; fresh_state r12; hw "$HE" --role implement --status done --head HEAD
  (export HERDR_ENV=1; T_SID=chirp-inherited route_in "$HE")
  [[ "$(created)" == 1 ]] && grep -q 'action=reviewer:opened' "$HE/.agent-handoff/add-export/routing.log" && ! grep -q 'chirp-inherited' "$HE/.agent-handoff/add-export/routing.log"; check "inside a herdr pane the routing log does not name an inherited Xirp session" || printf '       %s\n' "($(cat "$HE/.agent-handoff/add-export/routing.log" 2>/dev/null))"

  printf 'SECRET-FINDING detail\n' > "$A/report-r1.md"; mkdir -p "$A/.git/info"; printf '/report-*.md\n' >> "$A/.git/info/exclude"
  hw "$A" --role review --status done --verdict changes-required --head HEAD --report report-r1.md
  route_in "$A"
  msgs | grep -q $'^impl-1\t' && msgs | grep -q "$A/report-r1.md" && msgs | grep -q "$X" && ! msgs | grep -q SECRET-FINDING; check "changes-required asks the implementer with the absolute report path and no report content"

  commit_in "$A" two; Y="$(git -C "$A" rev-parse HEAD)"; hw "$A" --role implement --status done --head HEAD
  route_in "$A"
  [[ "$(created)" == 1 ]] && msgs | grep -q $'^sess-1\t.*'"$Y"; check "later implement handoffs message the same reviewer"
  ! grep -q 'host' "$loop" && msgs | grep -q $'^sess-1\t'; check "a loop.yaml without host fields is routed through Xirp"

  before="$(msgs | wc -l)"
  hw "$A" --role review --status blocked --verdict changes-required --head HEAD --report report-r1.md --note "reply timed out"
  route_in "$A"
  [[ "$(msgs | wc -l)" == "$before" ]] && notes | grep -q 'reply timed out'; check "a blocked review only notifies the user"
  notes | grep -q '^event=handoff action_required=unset ' && ! notes | grep -q 'action_required=true'; check "handoff notices use the handoff event without an environment override"

  A2="$tmp/route-limit"; new_loop "$A2" shared ask 2; use_project "$A2"; fresh_state r2
  printf 'r\n' > "$A2/r.md"; mkdir -p "$A2/.git/info"; printf '/r.md\n' >> "$A2/.git/info/exclude"
  hw "$A2" --role implement --status done --head HEAD; hw "$A2" --role review --status done --verdict changes-required --head HEAD --report r.md
  hw "$A2" --role implement --status done --head HEAD; hw "$A2" --role review --status done --verdict changes-required --head HEAD --report r.md
  route_in "$A2"
  [[ -z "$(msgs)" ]] && notes | grep -q '2 輪上限'; check "round limit stops automatic repair and notifies the user"

  A3="$tmp/route-pass"; new_loop "$A3" shared ask; use_project "$A3"; fresh_state r3
  printf 'r\n' > "$A3/r.md"; mkdir -p "$A3/.git/info"; printf '/r.md\n' >> "$A3/.git/info/exclude"
  hw "$A3" --role implement --status done --head HEAD; hw "$A3" --role review --status done --verdict pass --head HEAD --report r.md
  route_in "$A3"
  [[ "$(created)" == 0 ]] && notes | grep -q 'handoff-finish add-export'; check "pass with trigger ask only notifies the user"

  A4="$tmp/route-auto"; new_loop "$A4" shared auto; use_project "$A4"; fresh_state r4
  printf 'r\n' > "$A4/r.md"; mkdir -p "$A4/.git/info"; printf '/r.md\n' >> "$A4/.git/info/exclude"
  hw "$A4" --role implement --status done --head HEAD; hw "$A4" --role review --status done --verdict pass --head HEAD --report r.md
  route_in "$A4"
  [[ "$(created)" == 1 ]] && jq -e '.customName=="codex - finish - add-export" and .agent.options.model=="gpt-5.6-terra"' "$FAKE_XIRP_DIR/create-1.json" >/dev/null \
    && [[ "$(kv_get "$A4/.agent-handoff/add-export/loop.yaml" finish.session)" == "sess-1" ]]; check "pass with trigger auto opens the finish session"
  hw "$A4" --role finish --status done --head HEAD
  before="$(created)"; route_in "$A4"
  [[ "$(created)" == "$before" ]] && notes | grep -q '收尾結束'; check "a finish record only notifies the user"
  BF="$tmp/route-finish-blocked"; new_loop "$BF"; use_project "$BF"; fresh_state r11; hw "$BF" --role finish --status blocked --head HEAD --note "push rejected"; route_in "$BF"
  notes | grep -q 'handoff-finish add-export' && notes | grep -q 'push rejected'; check "a blocked finish notice gives the reason and the retry command"

  A5="$tmp/route-stale-auto"; new_loop "$A5" shared auto; use_project "$A5"; fresh_state r5
  printf 'r\n' > "$A5/r.md"; mkdir -p "$A5/.git/info"; printf '/r.md\n' >> "$A5/.git/info/exclude"
  hw "$A5" --role implement --status done --head HEAD; hw "$A5" --role review --status done --verdict pass --head HEAD --report r.md
  printf 'x\n' > "$A5/dirty.txt"; git -C "$A5" add dirty.txt
  route_in "$A5"
  [[ "$(created)" == 0 ]] && notes | grep -q 'add-export'; check "auto finish refuses an unclean pass"

  A6="$tmp/route-unclean"; new_loop "$A6"; use_project "$A6"; fresh_state r6
  hw "$A6" --role implement --status done --head HEAD; printf 'wip\n' > "$A6/wip.txt"
  route_in "$A6"
  [[ "$(created)" == 0 ]] && notes | grep -q '未提交'; check "uncommitted changes stop the handoff"

  A7="$tmp/route-head"; new_loop "$A7"; use_project "$A7"; fresh_state r7
  hw "$A7" --role implement --status done --head HEAD; commit_in "$A7" moved
  route_in "$A7"
  [[ "$(created)" == 0 ]] && notes | grep -q 'HEAD'; check "a moved HEAD stops the handoff"

  A8="$tmp/route-noxirp"; new_loop "$A8"; fresh_state r8; hw "$A8" --role implement --status done --head HEAD
  (cd "$A8" && PATH="/usr/bin:/bin" HANDOFF_NOTIFY="$FAKES/notify.sh" "$ROUTE" --foreground </dev/null); rc=$?
  [[ "$rc" == 0 && "$(created)" == 0 && -z "$(notes)" && ! -e "$A8/.agent-handoff/add-export/.routed" ]]; check "without xirp the hook does nothing and exits 0"

  # Separate review worktree: two rounds A -> B -> A -> B.
  WA="$tmp/route-sep"; new_loop "$WA" new ask; use_project "$WA"; fresh_state r9
  WB="${WA}-review"
  commit_in "$WA" first; X="$(git -C "$WA" rev-parse HEAD)"; hw "$WA" --role implement --status done --head HEAD
  route_in "$WA"
  lb="$WB/.agent-handoff/add-export/loop.yaml"
  [[ -d "$WB" && "$(git -C "$WB" rev-parse HEAD)" == "$X" && -f "$lb" ]] \
    && [[ "$(kv_get "$lb" reviewer.worktree)" == "$WB" && "$(kv_get "$loop" reviewer.worktree 2>/dev/null)" != "x" ]] \
    && [[ "$(kv_get "$WA/.agent-handoff/add-export/loop.yaml" reviewer.worktree)" == "$WB" ]] \
    && jq -e --arg w "$WB" '.worktreePath==$w' "$FAKE_XIRP_DIR/create-1.json" >/dev/null \
    && [[ "$(kv_get "$lb" reviewer.session)" == "sess-1" && "$(kv_get "$WA/.agent-handoff/add-export/loop.yaml" reviewer.session)" == "sess-1" ]]; check "new review worktree is created at the head and both loop copies list it"
  mkdir -p "$WB/reviews"; printf 'finding\n' > "$WB/reviews/r1.md"; mkdir -p "$(git -C "$WB" rev-parse --path-format=absolute --git-common-dir)/info"; printf '/reviews/\n' >> "$(git -C "$WB" rev-parse --path-format=absolute --git-common-dir)/info/exclude"
  hw "$WB" --role review --status done --verdict changes-required --head HEAD --report reviews/r1.md
  route_in "$WB"
  [[ -f "$WB/.agent-handoff/add-export/02-review.yaml" ]] && msgs | grep -q $'^impl-1\t.*'"$WB/reviews/r1.md"; check "review in B is numbered 02 and the implementer gets B's absolute report path"
  commit_in "$WA" second; Y="$(git -C "$WA" rev-parse HEAD)"; hw "$WA" --role implement --status done --head HEAD
  route_in "$WA"
  [[ -f "$WA/.agent-handoff/add-export/03-implement.yaml" && "$(git -C "$WB" rev-parse HEAD)" == "$Y" ]] && msgs | grep -q $'^sess-1\t.*'"$Y"; check "round 2 moves B to the new head before messaging the reviewer"
  hw "$WB" --role review --status done --verdict pass --head HEAD --report reviews/r1.md
  route_in "$WB"
  [[ -f "$WB/.agent-handoff/add-export/04-review.yaml" ]] && notes | grep -q 'handoff-finish add-export'; check "pass in B is numbered 04 and notifies the user"
  commit_in "$WA" third; hw "$WA" --role implement --status done --head HEAD
  printf 'leftover\n' > "$WB/leftover.txt"; before="$(msgs | wc -l)"
  route_in "$WA"
  [[ "$(git -C "$WB" rev-parse HEAD)" == "$Y" && "$(msgs | wc -l)" == "$before" ]] && notes | grep -q '審查 worktree'; check "an unclean review worktree is not moved and the reviewer is not messaged"

  AH="$tmp/route-bg"; new_loop "$AH"; use_project "$AH"; fresh_state r10; hw "$AH" --role implement --status done --head HEAD
  start=$SECONDS
  (cd "$AH" && printf '{"hook_event_name":"Stop"}' | PATH="$FAKES:$PATH" HANDOFF_NOTIFY="$FAKES/notify.sh" HANDOFF_CREATE_WAIT=2 "$ROUTE"); rc=$?
  quick=$(( SECONDS - start ))
  for _ in 1 2 3 4 5 6 7 8 9 10; do [[ -s "$AH/.agent-handoff/add-export/.routed" ]] && break; sleep 0.5; done
  [[ "$rc" == 0 && "$quick" -le 1 && "$(created)" == 1 ]]; check "hook mode returns at once and routes in the background"

  [[ ! -e "$tmp/state-r1/gh-called" && ! -e "$tmp/state-r9/gh-called" ]] && ! compgen -G "$tmp/state-*/gh-called" >/dev/null; check "routing never calls gh"

finish_section route
